
$ToolchainBuild = Invoke-RestMethod -Uri 'https://dev.azure.com/compnerd/windows-swift/_apis/build/builds?definitions=22&resultFilter=succeeded,partiallySucceeded&$top=1&api-version-string=5.0' -Method GET -UseDefaultCredentials
$ToolchainBuildID = $ToolchainBuild.value.id
$ToolchainArtifacts = Invoke-RestMethod -Uri "https://dev.azure.com/compnerd/windows-swift/_apis/build/builds/$ToolchainBuildID/artifacts?apiversion-string=2.0" -Method GET -UseDefaultCredentials
$ProgressPreference = 'SilentlyContinue'
Invoke-WebRequest $ToolchainArtifacts.value[0].resource.downloadUrl -OutFile "${env:temp}\$($ToolchainArtifacts.value[0].name)" -UseBasicParsing
Start-Process "${env:temp}\$($ToolchainArtifacts.value[0].name)" -ArgumentList "/qn" -Wait
# Remove-Item "${env:temp}\$($ToolchainArtifacts.value[0].name)" -Force
