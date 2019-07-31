<#
.SYNOPSIS

Download Windows, MacOS, Linux (Ubuntu), and Android build artifacts for Swift

.DESCRIPTION

Queries the dev.azure.com/compnerd/windows-swift ci server to pull the
most recent successful build of Swift for the specified platform

Currently supported platforms:

| Platform/Arch | arm64 | arm | x64 |
|---------------+-------+-----+-----|
| windows       |   o   |     |  o  |
| linux         |       |     |  o  |
| macos         |       |     |  o  |
| android       |   o   |  o  |  o  |

.EXAMPLE
PS> Download-SwiftArtifacts.ps1 -Platform windows -Arch x64

.EXAMPLE
PS> Download-SwiftArtifacts.ps1 -Platform android -Arch arm -Artifacts icu,xml2,curl
#>

param (
    # One of: ['windows', 'android', 'linux', 'macos']
    [Parameter(Mandatory=$true)]
    [string] $Platform,

    # One of ['arm', 'arm64', 'x64']
    [Parameter(Mandatory=$true)]
    [string] $Arch,

    # One or more of ['toolchain', 'icu', 'xml2', 'curl', 'sqlite', 'zlib']
    # in a comma separated list
    [string[]] $Artifacts = @('toolchain', 'icu', 'xml2', 'curl', 'sqlite', 'zlib')
)

$ErrorActionPreference = "Stop"
$SupportedPlatforms = @{
    windows = @("arm64", "x64")
    linux = @("x64")
    macos = @("x64")
    android = @("arm", "arm64", "x64")
}

$SourceDirs = @{
    windows = "S:\b\w"
    linux = "S:\b\l"
    macos = "S:\b\d"
    android = "S:\b\a"
}

function Download-Build([Int] $BuildID, [String] $ArtifactName) {
  $LatestBuild = Invoke-RestMethod -Uri "https://dev.azure.com/compnerd/windows-swift/_apis/build/builds?definitions=$BuildID&resultFilter=succeeded,partiallySucceeded&`$top=1&api-version-string=5.0"
  $LatestBuildID = $LatestBuild.value.id
  $LatestArtifacts = Invoke-RestMethod -Uri "https://dev.azure.com/compnerd/windows-swift/_apis/build/builds/$LatestBuildID/artifacts?api-version-string=5.0"
  $LatestArtifacts.value | ForEach-Object {
    if ($_.name -Eq $ArtifactName) {
      $TmpPath= "${env:temp}\$($_.name).zip"

      # Using Invoke-WebRequest attempts to parse the document which
      # is slooooow. We'll instead call through to dotnet and roll our
      # own progress
      $DownloadJob = Start-Job { param ($Url, $OutPath)
        $wc = New-Object net.webclient
        $wc.Downloadfile($Url, $OutPath)
      } -ArgumentList $_.resource.downloadUrl, $TmpPath

      while ($DownloadJob.State -ne "Completed") {
        $Downloaded = if (Test-Path $TmpPath) { $(Get-ChildItem $TmpPath).Length } else { 0 }
        $Unit = "bytes"
        if ($Downloaded -gt 1000) {
            $Downloaded = [int]($Downloaded/1000)
            $Unit = "kB"
        }
        if ($Downloaded -gt 1000) {
            $Downloaded = [int]($Downloaded/1000)
            $Unit = "MB"
        }
        if ($Downloaded -gt 1000) {
            $Downloaded = [int]($Downloaded/1000)
            $Unit = "GB"
        }

        Write-Progress -Activity "Downloading to ${TmpPath}" -Status "Downloaded ${Downloaded} ${Unit}";
        Sleep 1
      }

      $LibDir = "$($SourceDirs[$Platform])\Library"
      Expand-Archive -Force -Path $env:temp\$($_.name).zip -DestinationPath $LibDir
      Get-ChildItem -Path "${LibDir}\$($_.name)\*" | ForEach-Object {
        $path = "${LibDir}\$($_.Name)"
        if (Test-Path $path) {
          Remove-Item -Re -Fo $path
        }
      }
      Move-Item -Force -Path "${LibDir}\$($_.name)\*" -Destination $LibDir
      Remove-Item ${LibDir}\$($_.name)
    }
  }
}

if (! $SupportedPlatforms.Contains($Platform)) {
    Write-Host "Error:" -NoNewline -ForegroundColor DarkRed
    Write-Output " '${Platform}' is not a supported platform."
    Write-Output ""
    Write-Output "The valid platforms are:"
    Write-Output ""
    Write-Output "    $($SupportedPlatforms.keys)"
    Write-Output ""
    exit(1)
}

$SupportedArches = $SupportedPlatforms[$Platform]
if (!$SupportedArches.Contains($Arch)) {
    Write-Host "Error:" -NoNewline -ForegroundColor DarkRed
    Write-Output " '${Arch}' is not a supported architecture for '${Platform}'."
    Write-Output ""
    Write-Output "The valid architectures for ${Platform} are:"
    Write-Output ""
    Write-Output "    ${SupportedArches}"
    Write-Output ""
    exit(1)
}

$SupportedArtifacts = @{
    toolchain = 1
    icu = 9
    xml2 = 10
    curl = 11
    sqlite = 12
    zlib = 16
}
$InvalidArtifacts = @()
$Artifacts | ForEach-Object {
  if (! $SupportedArtifacts.Contains($_)) {
    $InvalidArtifacts += $_
  }
}

if ($InvalidArtifacts.Length -gt 0) {
  Write-Host "Error:" -NoNewline -ForegroundColor DarkRed
  if ($InvalidArtifacts.Length -eq 1) {
    Write-Output " '$($InvalidArtifacts[0])' is not a supported artifact"
  } else {
    Write-Output " [${InvalidArtifacts}] are not supported artifacts"
  }
  Write-Output ""
  Write-Output "The supported artifacts are: "
  Write-Output ""
  Write-Output "    $($SupportedArtifacts.keys)"
  Write-Output ""
  exit(1)
}

if ($Artifacts.Contains("toolchain")) {
    Download-Build -BuildID $SupportedArtifacts["toolchain"] -ArtifactName "toolchain"
}

$Artifacts | ForEach-Object {
    Download-Build -BuildID  $SupportedArtifacts[$_] -ArtifactName "$_-${Platform}-${Arch}"
}
