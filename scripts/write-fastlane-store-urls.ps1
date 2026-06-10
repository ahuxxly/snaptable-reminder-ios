param(
    [Parameter(Mandatory = $true)]
    [string]$Owner,

    [string]$RepoName = "snaptable-reminder-ios",

    [string]$BaseUrl = ""
)

$ErrorActionPreference = "Stop"

if (-not $BaseUrl) {
    $BaseUrl = "https://$Owner.github.io/$RepoName"
}

$BaseUrl = $BaseUrl.TrimEnd("/")
if ($BaseUrl -notmatch "^https://") {
    throw "BaseUrl must be an https URL."
}

$metadataDirectory = "fastlane\metadata\en-US"
New-Item -ItemType Directory -Force -Path $metadataDirectory | Out-Null

$privacyUrl = "$BaseUrl/privacy.html"
$supportUrl = "$BaseUrl/support.html"

Set-Content -Path (Join-Path $metadataDirectory "privacy_url.txt") -Value $privacyUrl -NoNewline
Set-Content -Path (Join-Path $metadataDirectory "support_url.txt") -Value $supportUrl -NoNewline

Write-Host "privacy_url=$privacyUrl"
Write-Host "support_url=$supportUrl"
