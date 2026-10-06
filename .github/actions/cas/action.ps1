$ErrorActionPreference = 'Stop'

function Invoke-TimedCommand([string]$Executable, [string[]]$Arguments) {
    $Timer = [Diagnostics.Stopwatch]::StartNew()
    & $Executable @Arguments | Out-Host
    $Code = $LASTEXITCODE
    $Timer.Stop()
    if ($Code -ne 0) { throw "$Executable failed with exit code $Code" }
    return $Timer.Elapsed.TotalSeconds
}

$Operation = $env:CAS_OPERATION
if ($Operation -notin @('restore', 'save')) { throw "Unknown CAS operation: $Operation" }
if ($env:RUNNER_OS -ne 'Windows') { throw 'CAS storage currently requires Windows' }
foreach ($Name in @('CAS_KEY', 'CAS_BUCKET', 'CAS_REGION', 'CAS_GNU_TAR', 'CAS_S5CMD')) {
    if (-not [Environment]::GetEnvironmentVariable($Name)) { throw "Missing $Name" }
}
$CasPath = Join-Path $env:GITHUB_WORKSPACE 'cas'
$Key = "cas-$($env:CAS_KEY).tar"
$Uri = "s3://$($env:CAS_BUCKET)/$Key"
$Directory = Join-Path $env:RUNNER_TEMP "cas-$([guid]::NewGuid())"
New-Item -ItemType Directory -Path $Directory | Out-Null
$Archive = Join-Path $Directory 'cas.tar'
$Report = [ordered]@{ operation = $Operation; uri = $Uri; status = 'running' }
$CopyArgs = @('--numworkers', '1', 'cp', '--concurrency', '32', '--part-size', '8')

try {
    if ($Operation -eq 'restore') {
        if (Test-Path $CasPath) { throw "CAS restore requires a fresh directory: $CasPath" }
        $HeadError = Join-Path $Directory 'head-error.txt'
        $Head = & aws s3api head-object --bucket $env:CAS_BUCKET --key $Key --region $env:CAS_REGION --output json --no-cli-pager 2> $HeadError
        if ($LASTEXITCODE -ne 0) {
            $Message = Get-Content $HeadError -Raw
            if ($Message -notmatch '\b404\b|NoSuchKey|Not Found') {
                throw "CAS lookup failed: $Message"
            }
            # The Actions PowerShell wrapper propagates LASTEXITCODE even for a handled miss.
            $global:LASTEXITCODE = 0
            New-Item -ItemType Directory -Path $CasPath | Out-Null
            $Report.status = 'miss'
            Write-Host "CAS miss: $Uri"
        } else {
            $Object = ($Head -join "`n") | ConvertFrom-Json
            $Report.download_seconds = Invoke-TimedCommand $env:CAS_S5CMD ($CopyArgs + @($Uri, $Archive))
            $Report.archive_bytes = (Get-Item $Archive).Length
            if ($Report.archive_bytes -ne $Object.ContentLength) { throw 'CAS download size mismatch' }
            New-Item -ItemType Directory -Path $CasPath | Out-Null
            $Report.extract_seconds = Invoke-TimedCommand "$env:WINDIR/System32/tar.exe" @('-xf', $Archive, '-C', $CasPath)
            $Report.status = 'hit'
        }
        "LLVM_CACHE_CAS_PATH=$($CasPath.Replace('\', '/'))" | Out-File $env:GITHUB_ENV -Encoding utf8 -Append
    } else {
        if ($env:LLVM_CACHE_CAS_PATH -ne $CasPath.Replace('\', '/')) { throw 'CAS was not initialized by the restore step' }
        $Files = @(Get-ChildItem $CasPath -File -Recurse)
        if ($Files.Count -eq 0) {
            $Report.status = 'empty'
            Write-Host 'CAS is empty; no archive will be uploaded'
        } else {
            $Report.file_count = $Files.Count
            $Report.logical_bytes = ($Files | Measure-Object Length -Sum).Sum
            $Report.archive_seconds = Invoke-TimedCommand $env:CAS_GNU_TAR @(
                '--force-local', '--format=gnu', '--sort=name', '--sparse', '-cf', $Archive, '-C', $CasPath, '.'
            )
            $Report.archive_bytes = (Get-Item $Archive).Length
            $Report.upload_seconds = Invoke-TimedCommand $env:CAS_S5CMD ($CopyArgs + @($Archive, $Uri))
            $Report.status = 'saved'
        }
    }
} catch {
    $Report.status = 'failed'
    $Report.error = $_.Exception.Message
    throw
} finally {
    $Json = $Report | ConvertTo-Json
    Write-Host $Json
    $Lines = @("### CAS $Operation", '', "Status: **$($Report.status)**", '', "Object: $Uri", '', '| Measurement | Value |', '|---|---:|')
    foreach ($Name in @('file_count', 'logical_bytes', 'archive_bytes', 'download_seconds', 'extract_seconds', 'archive_seconds', 'upload_seconds')) {
        if ($Report.Contains($Name)) {
            $Value = if ($Name.EndsWith('_seconds')) { '{0:F3} s' -f $Report[$Name] } else { '{0:N0}' -f $Report[$Name] }
            $Lines += "| $Name | $Value |"
        }
    }
    $Lines -join "`n" | Out-File $env:GITHUB_STEP_SUMMARY -Encoding utf8 -Append
    Remove-Item $Directory -Recurse -Force
}
