
Add-Type -A System.IO.Compression.FileSystem

$Builds = Invoke-RestMethod -Uri 'https://dev.azure.com/compnerd/windows-swift/_apis/build/builds?definitions=5&resultFilter=succeeded,partiallySucceeded&$top=1&api-version-string=5.0' -Method GET -UseDefaultCredentials
$BuildID = $Builds.value.id

$Components = @( "windows-toolchain-amd64.msi", "windows-runtime-amd64.msi", "windows-sdk.msi" )
$Artifacts = Invoke-RestMethod -Uri "https://dev.azure.com/compnerd/windows-swift/_apis/build/builds/$BuildID/artifacts?apiversion-string=2.0" -Method GET -UseDefaultCredentials
$Artifacts.value | ForEach-Object {
  if ($Components -Contains $_.name) {
    Invoke-WebRequest $_.resource.downloadUrl -OutFile "C:\TEMP\$($_.name)"
    [IO.Compression.ZipFile]::ExtractToDirectory("C:\TEMP\$($_.name)", "C:\TEMP")
    Start-Process msiexec -Wait -ArgumentList '/i', "C:\TEMP\$($_.name)", '/q'
  }
}
