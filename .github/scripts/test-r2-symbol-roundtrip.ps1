$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

$Bucket = $env:R2_TEST_BUCKET
$Prefix = $env:R2_TEST_PREFIX
$BaseUrl = [uri]$env:R2_TEST_BASE_URL
if ($Bucket -notmatch '\A[a-z0-9][a-z0-9-]{1,61}[a-z0-9]\z') {
    throw 'Invalid R2 bucket name'
}
if ($Prefix -notmatch '\Asymbol-upload-tests/[0-9]+-[0-9]+/symbols/\z') { throw 'Invalid test prefix; writes must stay outside production symbols/' }
if (!$BaseUrl.IsAbsoluteUri -or $BaseUrl.Scheme -ne 'https' -or $BaseUrl.UserInfo -or $BaseUrl.Query -or $BaseUrl.Fragment) {
    throw 'An HTTPS base URL for the bucket is required'
}
if (!$env:R2_ENDPOINT_URL) { throw 'R2_ENDPOINT_URL is required' }
$Endpoint = @('--endpoint-url', $env:R2_ENDPOINT_URL)
$Destination = "s3://$Bucket/$Prefix"
$Report = (New-Item -ItemType Directory -Force symbol-test-report).FullName
$Root = (New-Item -ItemType Directory (Join-Path $env:RUNNER_TEMP "symbol-roundtrip-$(New-Guid)")).FullName

function Invoke-Aws([string[]]$Arguments) {
    $Result = & aws @Arguments @Endpoint 2>&1
    if ($LASTEXITCODE) { throw "aws $($Arguments[0..1] -join ' ') failed: $Result" }
    return $Result
}

function Get-Manifest([string]$Store) {
    $Manifest = [Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
    foreach ($File in Get-ChildItem $Store -Recurse -File -Filter *.pdb) {
        $Key = [IO.Path]::GetRelativePath($Store, $File.FullName).Replace('\', '/')
        $Manifest.Add($Key, [pscustomobject]@{
            Key = $Key
            Bytes = $File.Length
            SHA256 = (Get-FileHash $File.FullName -Algorithm SHA256).Hash
            File = $File.FullName
        })
    }
    if (!$Manifest.Count) { throw "No staged PDBs in $Store" }
    return ,$Manifest
}

$Symstore = "${env:ProgramFiles(x86)}/Windows Kits/10/Debuggers/x64/symstore.exe"
if (!(Test-Path $Symstore)) {
    $Installer = Join-Path $Root 'winsdksetup.exe'
    Invoke-WebRequest 'https://go.microsoft.com/fwlink/?linkid=2120843' -OutFile $Installer
    $Process = Start-Process $Installer -ArgumentList '/features OptionId.WindowsDesktopDebuggers /q /norestart' -Wait -PassThru
    if ($Process.ExitCode -notin @(0, 3010)) { throw 'Debugging tools installation failed' }
}
if (!(Test-Path $Symstore)) { throw 'symstore.exe not found' }

$Stores = @{}
foreach ($Build in @('A', 'B')) {
    $InputPath = (Resolve-Path "pdbs-$Build").Path
    if (!(Get-ChildItem $InputPath -Recurse -File -Filter *.pdb)) { throw "No input PDBs for $Build" }
    $Stores[$Build] = (New-Item -ItemType Directory (Join-Path $Root $Build)).FullName
    & $Symstore add /r /o /f (Join-Path $InputPath '*.pdb') /s $Stores[$Build] /t Swift-Toolchain /v $Build /d "$Report/symstore-$Build.log"
    if ($LASTEXITCODE) { throw "SymStore failed for $Build" }
}
$A = Get-Manifest $Stores.A
$B = Get-Manifest $Stores.B
$A.Values | Sort-Object Key | Export-Csv "$Report/build-A.csv" -NoTypeInformation
$B.Values | Sort-Object Key | Export-Csv "$Report/build-B.csv" -NoTypeInformation

$Comparison = foreach ($Row in $B.Values) {
    $State = if (!$A.ContainsKey($Row.Key)) { 'new' } elseif ($A[$Row.Key].SHA256 -eq $Row.SHA256) { 'identical' } else { 'different' }
    [pscustomobject]@{ Key = $Row.Key; State = $State; SHA256 = $Row.SHA256 }
}
$Comparison | Sort-Object Key | Export-Csv "$Report/overlap.csv" -NoTypeInformation
if (@($Comparison | Where-Object State -eq 'different').Count) { throw 'The builds contain different bytes at the same symbol key; inspect overlap.csv' }
$NaturalOverlap = @($Comparison | Where-Object State -eq 'identical').Count
$NewCount = @($Comparison | Where-Object State -eq 'new').Count
if (!$NewCount) { throw 'Build B contains no new symbol keys; this would not test adding new symbols' }

$InjectedKey = ''
if (!$NaturalOverlap) {
    $Row = $A.Values | Sort-Object Key | Select-Object -First 1
    $InjectedKey = $Row.Key
    $Target = Join-Path $Stores.B $Row.Key
    New-Item -ItemType Directory -Force (Split-Path $Target) | Out-Null
    Copy-Item $Row.File $Target
    $B = Get-Manifest $Stores.B
}
$OldOnlyCount = @($A.Keys | Where-Object { !$B.ContainsKey($_) }).Count
if (!$OldOnlyCount) { throw 'No A-only symbol keys remain; this would not test retention of older symbols' }
$B.Values | Sort-Object Key | Export-Csv "$Report/published-B.csv" -NoTypeInformation
$Expected = [Collections.Generic.Dictionary[string,object]]::new($A, [StringComparer]::Ordinal)
foreach ($Row in $B.Values) { $Expected[$Row.Key] = $Row }
$Expected.Values | Sort-Object Key | Export-Csv "$Report/expected.csv" -NoTypeInformation

$Existing = Invoke-Aws @('s3api', 'list-objects-v2', '--bucket', $Bucket, '--prefix', $Prefix, '--output', 'json') | ConvertFrom-Json
if ($Existing.Contents.Count) { throw "Test prefix is not empty: $Destination" }

$Checks = [Collections.Generic.List[object]]::new()
$Timings = [Collections.Generic.List[object]]::new()
function Publish-Pdbs([string]$Build, [string]$Operation, [string]$Phase) {
    $Arguments = @('s3', $Operation, $Stores[$Build], $Destination, '--exclude', '*', '--include', '*.pdb', '--no-progress', '--acl', 'private')
    if ($Operation -eq 'cp') { $Arguments += '--recursive' }
    $Timer = [Diagnostics.Stopwatch]::StartNew()
    Invoke-Aws $Arguments | Tee-Object "$Report/upload-$Phase.log"
    $Timer.Stop()
    $Timings.Add([pscustomobject]@{ Phase = $Phase; Operation = $Operation; Seconds = $Timer.Elapsed.TotalSeconds })
    $Timings | Export-Csv "$Report/timings.csv" -NoTypeInformation
}

function Test-Objects($Manifest, [string]$Phase) {
    $Listing = Invoke-Aws @('s3api', 'list-objects-v2', '--bucket', $Bucket, '--prefix', $Prefix, '--output', 'json') | ConvertFrom-Json
    $Keys = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($Object in $Listing.Contents) { [void]$Keys.Add($Object.Key) }
    if ($Keys.Count -ne $Manifest.Count) { throw "$Phase has $($Keys.Count) remote objects; expected $($Manifest.Count)" }
    foreach ($Row in $Manifest.Values | Sort-Object Key) {
        $Key = $Prefix + $Row.Key
        if (!$Keys.Contains($Key)) { throw "$Phase is missing $Key" }
        $RemoteFile = Join-Path $Root 'downloaded.pdb'
        Invoke-Aws @('s3api', 'get-object', '--bucket', $Bucket, '--key', $Key, $RemoteFile) | Out-Null
        $StorageHash = (Get-FileHash $RemoteFile -Algorithm SHA256).Hash
        if ($StorageHash -ne $Row.SHA256) { throw "$Phase storage hash mismatch: $Key" }

        $EncodedKey = ($Key.Split('/') | ForEach-Object { [uri]::EscapeDataString($_) }) -join '/'
        $Url = $BaseUrl.AbsoluteUri.TrimEnd('/') + '/' + $EncodedKey
        $Response = Invoke-WebRequest -Uri $Url -OutFile $RemoteFile -PassThru
        if ($Response.StatusCode -ne 200) { throw "$Phase HTTP status $($Response.StatusCode): $Url" }
        $HttpHash = (Get-FileHash $RemoteFile -Algorithm SHA256).Hash
        if ($HttpHash -ne $Row.SHA256) { throw "$Phase HTTP hash mismatch: $Url" }
        $Checks.Add([pscustomobject]@{ Phase = $Phase; Key = $Key; SHA256 = $Row.SHA256; StorageSHA256 = $StorageHash; HttpSHA256 = $HttpHash; Url = $Url })
        $Checks | Export-Csv "$Report/checks.csv" -NoTypeInformation
    }
    Write-Output "$Phase verified $($Manifest.Count) objects through storage and HTTP"
}

$Summary = @(
    '## R2 PDB publication test'
    ''
    "Destination: $Destination"
    "HTTP base: $($BaseUrl.AbsoluteUri)"
    "Build A run: $env:BASELINE_RUN_ID; build B run: $env:CANDIDATE_RUN_ID"
    "Natural identical overlap: $NaturalOverlap; new B keys: $NewCount; A-only keys: $OldOnlyCount"
    "Baseline key added to B to ensure overlap: $(if ($InjectedKey) { $InjectedKey } else { 'none' })"
    "Only PDBs under $Prefix are uploaded. The production symbols/ path and transaction files are untouched."
)
$Summary | Set-Content "$Report/summary.md"
Publish-Pdbs A sync A
Test-Objects $A A
Publish-Pdbs B cp B
Test-Objects $Expected B
Publish-Pdbs B cp B-repeat
Test-Objects $Expected B-repeat
$Summary += "PASS: all $($Expected.Count) PDBs were preserved and served with the expected bytes, including after repeating B."
$Summary | Set-Content "$Report/summary.md"
if ($env:GITHUB_STEP_SUMMARY) { $Summary | Add-Content $env:GITHUB_STEP_SUMMARY }
$Summary
