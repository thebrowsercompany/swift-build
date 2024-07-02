param(
    [Parameter(Mandatory)]
    [string] $PathToSourcekitLsp
)

$diagnosticOutput = $( & Get-Content sourcekit-lsp-initialization-message | & $PathToSourcekitLsp ) 2>&1
if (-not ($diagnosticOutput -Match "Succeeded") -or -not ($diagnosticOutput -Match "InitializeResult")) {
  Write-Host "sourcekit-lsp failed to initialize"
  Write-Host $diagnosticOutput
  exit 1
}