
function Download-Build([Int] $BuildID, [String] $ArtifactName) {
  $LatestBuild = Invoke-RestMethod -Uri "https://dev.azure.com/compnerd/windows-swift/_apis/build/builds?definitions=$BuildID&resultFilter=succeeded,partiallySucceeded&`$top=1&api-version-string=5.0"
  $LatestBuildID = $LatestBuild.value.id
  $LatestArtifacts = Invoke-RestMethod -Uri "https://dev.azure.com/compnerd/windows-swift/_apis/build/builds/$LatestBuildID/artifacts?api-version-string=5.0"
  $LatestArtifacts.value | ForEach-Object {
    if ($_.name -Eq $ArtifactName) {
      Invoke-WebRequest -UseBasicParsing -Uri $_.resource.downloadUrl -Outfile $env:temp\$($_.name).zip
      Expand-Archive -Force -Path $env:temp\$($_.name).zip -DestinationPath S:\b\a\Library
      Move-Item -Force -Path S:\b\a\Library\$($_.name)\* -Destination S:\b\a\Library
      Remove-Item S:\b\a\Library\$($_.name)
    }
  }
}

Download-Build -BuildID  1 -ArtifactName "toolchain"
Download-Build -BuildID  9 -ArtifactName "icu-android-arm"
Download-Build -BuildID 10 -ArtifactName "xml2-android-arm"
Download-Build -BuildID 11 -ArtifactName "curl-android-arm"
Download-Build -BuildID 12 -ArtifactName "sqlite-android-arm"

