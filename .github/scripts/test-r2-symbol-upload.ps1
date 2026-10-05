$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$Report = New-Item -ItemType Directory -Force symbol-test-report
$Store = Join-Path $env:RUNNER_TEMP "symbol-store-$(New-Guid)"
$Admin = New-Item -ItemType Directory -Force "$Store/000Admin"
$Endpoint = @('--endpoint-url', $env:R2_ENDPOINT_URL)
$Destination = "s3://$env:R2_BUCKET/symbols/"

$Symstore = "${env:ProgramFiles(x86)}/Windows Kits/10/Debuggers/x64/symstore.exe"
if (!(Test-Path $Symstore)) {
    $Installer = Join-Path $env:RUNNER_TEMP 'winsdksetup.exe'
    Invoke-WebRequest 'https://go.microsoft.com/fwlink/?linkid=2120843' -OutFile $Installer
    $Process = Start-Process $Installer -ArgumentList '/features OptionId.WindowsDesktopDebuggers /q /norestart' -Wait -PassThru
    if ($Process.ExitCode -notin @(0, 3010)) { throw 'Debugging tools installation failed' }
}
if (!(Test-Path $Symstore)) { throw 'symstore.exe not found' }
if (!(Get-ChildItem pdbs -Recurse -Filter *.pdb -File)) { throw 'No PDBs found' }

# Seed the same admin state as the current publisher, without its server.txt write.
foreach ($Name in @('history.txt', 'server.txt', 'lastid.txt')) {
    $Metadata = aws s3api get-object --bucket $env:R2_BUCKET --key "symbols/000Admin/$Name" @Endpoint "$Admin/$Name"
    if ($LASTEXITCODE) { throw "Could not read $Name" }
    if ($Name -eq 'server.txt') { $InitialETag = ($Metadata | ConvertFrom-Json).ETag }
}
& $Symstore add /r /o /f "$((Resolve-Path pdbs).Path)/*.pdb" /s $Store /t Swift-Toolchain /v 0.0.0 /c 810f68bbfc13794d267bf488f1e6fa84c267b002
if ($LASTEXITCODE) { throw 'SymStore failed' }
$Files = @(Get-ChildItem $Store -Recurse -File)
if (!($Files | Where-Object Extension -eq '.pdb')) { throw 'SymStore produced no PDBs' }

$Timings = foreach ($Operation in @('sync', 'cp')) {
    $Options = @('--dryrun', '--no-progress', '--acl', 'private')
    # The candidate uploads PDBs only; the report explicitly shows omitted metadata.
    if ($Operation -eq 'cp') { $Options += @('--recursive', '--exclude', '*', '--include', '*.pdb') }
    $Timer = [Diagnostics.Stopwatch]::StartNew()
    & aws s3 $Operation $Store $Destination @Endpoint @Options > "$Report/$Operation.txt"
    $Code = $LASTEXITCODE
    $Timer.Stop()
    if ($Code) { throw "$Operation dry run failed: $Code" }
    [pscustomobject]@{ Operation = $Operation; Seconds = $Timer.Elapsed.TotalSeconds }
}
$Timings | Export-Csv "$Report/timings.csv" -NoTypeInformation
$Timings | Format-Table

$SyncUploads = @(Get-Content "$Report/sync.txt" | Where-Object { $_ -match '^\(dryrun\) upload:' } | ForEach-Object {
    ($_ -split ' to ', 2)[1]
})
$CopyUploads = @(Get-Content "$Report/cp.txt" | Where-Object { $_ -match '^\(dryrun\) upload:' } | ForEach-Object {
    ($_ -split ' to ', 2)[1]
})
if ($CopyUploads.Count -eq 0) { throw 'No proposed PDB uploads in cp output' }

$Remote = Join-Path $env:RUNNER_TEMP 'symbol-object'
$Rows = foreach ($File in $Files) {
    $Key = 'symbols/' + [IO.Path]::GetRelativePath($Store, $File.FullName).Replace('\', '/')
    $LocalHash = (Get-FileHash $File.FullName -Algorithm SHA256).Hash
    $RemoteHash = ''
    $Result = aws s3api get-object --bucket $env:R2_BUCKET --key $Key @Endpoint $Remote 2>&1
    if ($LASTEXITCODE) {
        if ("$Result" -notmatch '\(NoSuchKey\)|\(404\)|\(NotFound\)') { throw "Could not read ${Key}: $Result" }
        $State = 'missing'
    } else {
        $RemoteHash = (Get-FileHash $Remote -Algorithm SHA256).Hash
        $State = if ($LocalHash -eq $RemoteHash) { 'identical' } else { 'different' }
    }
    $Uri = "s3://$env:R2_BUCKET/$Key"
    [pscustomobject]@{
        Key = $Key
        Bytes = $File.Length
        Remote = $State
        SyncWouldUpload = $Uri -cin $SyncUploads
        CopyWouldUpload = $Uri -cin $CopyUploads
        LocalSHA256 = $LocalHash
        RemoteSHA256 = $RemoteHash
    }
}
$Rows | Export-Csv "$Report/objects.csv" -NoTypeInformation
$Rows | Format-Table Key, Bytes, Remote, SyncWouldUpload, CopyWouldUpload -AutoSize

$FinalMetadata = aws s3api head-object --bucket $env:R2_BUCKET --key symbols/000Admin/server.txt @Endpoint
if ($LASTEXITCODE) { throw 'Could not recheck server.txt' }
$Changed = ($FinalMetadata | ConvertFrom-Json).ETag -ne $InitialETag
$Summary = @(
    '## R2 symbol upload experiment'
    ''
    ($Timings | ForEach-Object { '{0} dry run: {1:N2} seconds' -f $_.Operation, $_.Seconds })
    ''
    "Compared $($Rows.Count) local files against their exact production keys. See objects.csv for hashes and planned uploads."
    "PDBs with different existing contents: $(@($Rows | Where-Object { $_.Key -like '*.pdb' -and $_.Remote -eq 'different' }).Count)."
    "Files sync would upload but PDB-only cp omits: $(@($Rows | Where-Object { $_.SyncWouldUpload -and !$_.CopyWouldUpload }).Count)."
    ''
    'Production was read-only. The normal conditional server.txt write was skipped, so its dry-run result represents a pending metadata update.'
    'These timings measure planning and comparison, not actual transfers. PDB-only cp is not equivalent to publishing the full symbol store.'
    "Production server.txt changed during the comparison: $Changed. If true, rerun before drawing conclusions about metadata equivalence."
)
$Summary | Set-Content "$Report/summary.md"
$Summary | Add-Content $env:GITHUB_STEP_SUMMARY
if ($Changed) { Write-Warning 'Production changed during the comparison; the report is not a consistent snapshot.' }
