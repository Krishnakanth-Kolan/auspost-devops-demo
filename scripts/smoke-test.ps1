param(
    [string]$Url = "http://localhost:8080/healthz",
    [string]$ExpectedVersion = ""
)

$ErrorActionPreference = "Stop"
$response = Invoke-RestMethod -Uri $Url -Method Get
$response | ConvertTo-Json -Compress

if ($response.status -ne "success") {
    throw "Health response did not report success."
}
if ($ExpectedVersion -and $response.version -ne $ExpectedVersion) {
    throw "Expected version '$ExpectedVersion' but received '$($response.version)'."
}
Write-Host "Smoke test passed."
