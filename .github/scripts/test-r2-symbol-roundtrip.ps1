$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

$Bucket = $env:R2_TEST_BUCKET
$Prefix = $env:R2_TEST_PREFIX
$BaseUrl = [uri]$env:R2_TEST_BASE_URL
if ($Bucket -notmatch '\A[a-z0-9][a-z0-9-]{1,61}[a-z0-9]\z') { throw 'Invalid R2 bucket name' }
if ($Prefix -notmatch '\Asymbol-upload-tests/[0-9]+-[0-9]+/symbols/\z') { throw 'Invalid test prefix; writes must stay outside production symbols/' }
if (!$BaseUrl.IsAbsoluteUri -or $BaseUrl.Scheme -ne 'https' -or $BaseUrl.UserInfo -or $BaseUrl.Query -or $BaseUrl.Fragment) {
    throw 'An HTTPS base URL for the bucket is required'
}
if (!$env:R2_ENDPOINT_URL) { throw 'R2_ENDPOINT_URL is required' }
$Endpoint = @('--endpoint-url', $env:R2_ENDPOINT_URL)
$DestinationRoot = "s3://$Bucket/$Prefix"
$Report = (New-Item -ItemType Directory -Force symbol-test-report).FullName
$Root = (New-Item -ItemType Directory (Join-Path $env:RUNNER_TEMP "symbol-roundtrip-$(New-Guid)")).FullName
$Lanes = @('reference', 'split')

function Invoke-Aws([string[]]$Arguments) {
    $Result = & aws @Arguments @Endpoint 2>&1
    if ($LASTEXITCODE) { throw "aws $($Arguments[0..1] -join ' ') failed: $Result" }
    return $Result
}

# Run the action's actual final upload block, with only its destinations redirected.
$Action = Get-Content .github/actions/publish-symbols-r2/action.yml -Raw
$Match = [regex]::Match($Action, '(?ms)^            # 5\. Upload remaining store files\r?\n(.*?)^            exit 0\r?$')
if (!$Match.Success) { throw 'Could not locate the production upload block' }
$UploadText = $Match.Groups[1].Value.Replace('"s3://${env:R2_BUCKET}/symbols/000Admin/"', '"${Destination}000Admin/"').Replace('"s3://${env:R2_BUCKET}/symbols/"', '"$Destination"')
if ($UploadText.Contains('s3://') -or !$UploadText.Contains('aws s3 sync')) { throw 'Upload block was not safely redirected' }
$SplitUpload = [scriptblock]::Create($UploadText)
$UploadText | Set-Content "$Report/split-upload.ps1"
Copy-Item .github/actions/publish-symbols-r2/action.yml "$Report/action.yml"
Copy-Item .github/workflows/test-publish-symbols.yml "$Report/workflow.yml"
Get-ChildItem artifacts-A, artifacts-B -Filter symbol-test-build.json -Recurse | ForEach-Object {
    Copy-Item $_.FullName "$Report/$($_.Directory.Name)-build.json"
}

function Get-Manifest([string]$Store) {
    $Manifest = [Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
    foreach ($File in Get-ChildItem $Store -Recurse -File) {
        $Key = [IO.Path]::GetRelativePath($Store, $File.FullName).Replace('\', '/')
        $Manifest.Add($Key, [pscustomobject]@{
            Key = $Key
            Bytes = $File.Length
            SHA256 = (Get-FileHash $File.FullName -Algorithm SHA256).Hash
            File = $File.FullName
        })
    }
    return ,$Manifest
}

$Checks = [Collections.Generic.List[object]]::new()
$Timings = [Collections.Generic.List[object]]::new()
function Publish-Store([string]$Store, [string]$Phase, [bool]$Conditional = $false, [string]$Group = '') {
    foreach ($Lane in $Lanes) {
        $Destination = "$DestinationRoot$Group$Lane/"
        $TempRoot = $Store
        $AdminDir = Join-Path $Store '000Admin'
        if ($Conditional) {
            $Key = "$Prefix$Group$Lane/000Admin/server.txt"
            $Head = Invoke-Aws @('s3api', 'head-object', '--bucket', $Bucket, '--key', $Key, '--output', 'json') | ConvertFrom-Json
            Invoke-Aws @('s3api', 'put-object', '--bucket', $Bucket, '--key', $Key, '--body', (Join-Path $AdminDir 'server.txt'), '--if-match', $Head.ETag) | Out-Null
        }
        $Timer = [Diagnostics.Stopwatch]::StartNew()
        if ($Lane -eq 'reference') {
            Invoke-Aws @('s3', 'sync', $Store, $Destination, '--no-progress', '--acl', 'private') | Tee-Object "$Report/upload-$Phase-$Lane.log"
        } else {
            & $SplitUpload 2>&1 | Tee-Object "$Report/upload-$Phase-$Lane.log"
            if ($LASTEXITCODE) { throw "Split upload failed for $Phase" }
        }
        $Timer.Stop()
        $Timings.Add([pscustomobject]@{ Phase = $Phase; Lane = $Lane; Seconds = $Timer.Elapsed.TotalSeconds })
        $Timings | Export-Csv "$Report/timings.csv" -NoTypeInformation
    }
}

function Test-Objects($Manifest, [string]$Phase, [string]$Group = '') {
    foreach ($Lane in $Lanes) {
        $LanePrefix = "$Prefix$Group$Lane/"
        $Listing = Invoke-Aws @('s3api', 'list-objects-v2', '--bucket', $Bucket, '--prefix', $LanePrefix, '--output', 'json') | ConvertFrom-Json
        $Keys = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        foreach ($Object in $Listing.Contents) { [void]$Keys.Add($Object.Key) }
        if ($Keys.Count -ne $Manifest.Count) { throw "$Phase/$Lane has $($Keys.Count) objects; expected $($Manifest.Count)" }
        foreach ($Row in $Manifest.Values | Sort-Object Key) {
            $Key = $LanePrefix + $Row.Key
            if (!$Keys.Contains($Key)) { throw "$Phase/$Lane is missing $Key" }
            $Downloaded = Join-Path $Root 'downloaded'
            Invoke-Aws @('s3api', 'get-object', '--bucket', $Bucket, '--key', $Key, $Downloaded) | Out-Null
            $StorageHash = (Get-FileHash $Downloaded -Algorithm SHA256).Hash
            if ($StorageHash -ne $Row.SHA256) { throw "$Phase/$Lane storage hash mismatch: $Key" }
            $HttpHash = ''
            if ($Row.Key.EndsWith('.pdb', [StringComparison]::OrdinalIgnoreCase)) {
                $EncodedKey = ($Key.Split('/') | ForEach-Object { [uri]::EscapeDataString($_) }) -join '/'
                $Response = Invoke-WebRequest -Uri ($BaseUrl.AbsoluteUri.TrimEnd('/') + '/' + $EncodedKey) -OutFile $Downloaded -PassThru
                if ($Response.StatusCode -ne 200) { throw "$Phase/$Lane HTTP status $($Response.StatusCode): $Key" }
                $HttpHash = (Get-FileHash $Downloaded -Algorithm SHA256).Hash
                if ($HttpHash -ne $Row.SHA256) { throw "$Phase/$Lane HTTP hash mismatch: $Key" }
            }
            $Checks.Add([pscustomobject]@{ Phase = $Phase; Lane = $Lane; Key = $Key; SHA256 = $Row.SHA256; StorageSHA256 = $StorageHash; HttpSHA256 = $HttpHash })
            $Checks | Export-Csv "$Report/checks.csv" -NoTypeInformation
        }
        Write-Output "$Phase/$Lane verified all $($Manifest.Count) objects, including metadata"
    }
}

$Existing = Invoke-Aws @('s3api', 'list-objects-v2', '--bucket', $Bucket, '--prefix', $Prefix, '--output', 'json') | ConvertFrom-Json
if ($Existing.Contents.Count) { throw "Test prefix is not empty: $DestinationRoot" }
$Summary = @(
    '## R2 split upload test'
    ''
    "Destination: $DestinationRoot"
    "Build A run: $env:BASELINE_RUN_ID; build B run: $env:CANDIDATE_RUN_ID"
    'Reference: original whole-store sync. Candidate: upload block extracted from the production action.'
    'Both receive identical staged bytes and timestamps. All writes stay under the test prefix.'
)
$Summary | Set-Content "$Report/summary.md"

$Symstore = "${env:ProgramFiles(x86)}/Windows Kits/10/Debuggers/x64/symstore.exe"
if (!(Test-Path $Symstore)) {
    $Installer = Join-Path $Root 'winsdksetup.exe'
    Invoke-WebRequest 'https://go.microsoft.com/fwlink/?linkid=2120843' -OutFile $Installer
    $Process = Start-Process $Installer -ArgumentList '/features OptionId.WindowsDesktopDebuggers /q /norestart' -Wait -PassThru
    if ($Process.ExitCode -notin @(0, 3010)) { throw 'Debugging tools installation failed' }
}
if (!(Test-Path $Symstore)) { throw 'symstore.exe not found' }

$Expected = [Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
foreach ($Build in @('A', 'B')) {
    $InputPath = (Resolve-Path "pdbs-$Build").Path
    if (!(Get-ChildItem $InputPath -Recurse -File -Filter *.pdb)) { throw "No input PDBs for $Build" }
    $Store = (New-Item -ItemType Directory (Join-Path $Root $Build)).FullName
    $Admin = (New-Item -ItemType Directory (Join-Path $Store '000Admin')).FullName
    if ($Build -eq 'B') {
        Invoke-Aws @('s3', 'cp', "${DestinationRoot}reference/000Admin", $Admin, '--recursive', '--exclude', '*', '--include', 'history.txt', '--include', 'server.txt', '--include', 'lastid.txt', '--no-progress', '--only-show-errors') | Out-Null
    }
    & $Symstore add /r /o /f (Join-Path $InputPath '*.pdb') /s $Store /t Swift-Toolchain /v $Build /d "$Report/symstore-$Build.log"
    if ($LASTEXITCODE) { throw "SymStore failed for $Build" }
    $Manifest = Get-Manifest $Store
    $Pdbs = @($Manifest.Values | Where-Object Key -Like '*.pdb')
    if (!$Pdbs.Count) { throw "SymStore staged no PDBs for $Build" }
    $Manifest.Values | Sort-Object Key | Export-Csv "$Report/build-$Build.csv" -NoTypeInformation
    if ($Build -eq 'B') {
        $Comparison = foreach ($Row in $Pdbs) {
            $State = if (!$Expected.ContainsKey($Row.Key)) { 'new' } elseif ($Expected[$Row.Key].SHA256 -eq $Row.SHA256) { 'identical' } else { 'different' }
            [pscustomobject]@{ Key = $Row.Key; State = $State }
        }
        $Comparison | Export-Csv "$Report/overlap.csv" -NoTypeInformation
        $Overlap = @($Comparison | Where-Object State -eq 'identical').Count
        $New = @($Comparison | Where-Object State -eq 'new').Count
        $Old = @($Expected.Keys | Where-Object { $_ -like '*.pdb' -and !$Manifest.ContainsKey($_) }).Count
        if (@($Comparison | Where-Object State -eq 'different').Count -or !$Overlap -or !$New -or !$Old) {
            throw 'Expected identical overlapping PDBs, new B keys, and retained A-only keys; inspect overlap.csv'
        }
        $Summary += "PDB overlap: $Overlap identical; $New new B keys; $Old A-only keys."
    }
    foreach ($Row in $Manifest.Values) { $Expected[$Row.Key] = $Row }
    $Expected.Values | Sort-Object Key | Export-Csv "$Report/expected-$Build.csv" -NoTypeInformation
    Publish-Store $Store $Build ($Build -eq 'B')
    Test-Objects $Expected $Build
}
Publish-Store $Store 'B-repeat' $true
Test-Objects $Expected 'B-repeat'

# A newer remote counter with the same size must survive the metadata sync.
$Stale = (New-Item -ItemType Directory (Join-Path $Root 'stale/000Admin')).Parent.FullName
$Newer = (New-Item -ItemType Directory (Join-Path $Root 'newer/000Admin')).Parent.FullName
[IO.File]::WriteAllText((Join-Path $Stale '000Admin/lastid.txt'), '0000000041')
[IO.File]::WriteAllText((Join-Path $Newer '000Admin/lastid.txt'), '0000000042')
(Get-Item (Join-Path $Stale '000Admin/lastid.txt')).LastWriteTimeUtc = [datetime]::UtcNow.AddDays(-1)
foreach ($Lane in $Lanes) {
    Invoke-Aws @('s3', 'cp', (Join-Path $Newer '000Admin/lastid.txt'), "${DestinationRoot}metadata-skip/$Lane/000Admin/lastid.txt", '--no-progress', '--acl', 'private') | Out-Null
}
Publish-Store $Stale 'metadata-newer' $false 'metadata-skip/'
Test-Objects (Get-Manifest $Newer) 'metadata-newer' 'metadata-skip/'

$Summary += @(
    "PASS: original sync and split upload produced the expected bytes for every object after A, B, and repeating B."
    'PASS: all PDBs were also served correctly over HTTP.'
    'PASS: both approaches retained a newer remote lastid.txt with the same byte length.'
    'Timings are for small test prefixes. This does not test concurrent SymStore transactions.'
)
$Summary | Set-Content "$Report/summary.md"
if ($env:GITHUB_STEP_SUMMARY) { $Summary | Add-Content $env:GITHUB_STEP_SUMMARY }
$Summary
