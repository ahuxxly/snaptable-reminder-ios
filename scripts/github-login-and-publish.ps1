param(
    [string]$RepoName = "snaptable-reminder-ios",

    [ValidateSet("public", "private")]
    [string]$Visibility = "public"
)

$ErrorActionPreference = "Stop"

function Write-Section($title) {
    Write-Host ""
    Write-Host "== $title =="
}

function Resolve-GitHubCli {
    $gh = Get-Command gh -ErrorAction SilentlyContinue
    if ($gh) {
        return $gh.Source
    }

    $fallbackGhPath = "C:\Program Files\GitHub CLI\gh.exe"
    if (Test-Path $fallbackGhPath) {
        return $fallbackGhPath
    }

    throw "GitHub CLI is missing. Install it with: winget install --id GitHub.cli -e --source winget"
}

$ghPath = Resolve-GitHubCli
Write-Section "GitHub CLI"
Write-Host "gh=$ghPath"

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
$authOutput = & $ghPath auth status 2>&1
$authExitCode = $LASTEXITCODE
$ErrorActionPreference = $previousErrorActionPreference

if ($authExitCode -ne 0) {
    Write-Section "GitHub login"
    Write-Host "Starting GitHub browser login. Complete the browser/device-code prompt, then return here."
    & $ghPath auth login --hostname github.com --git-protocol https --web
    if ($LASTEXITCODE -ne 0) {
        throw "GitHub login did not complete."
    }
} else {
    Write-Host "gh already authenticated"
}

Write-Section "Publish repository"
powershell -ExecutionPolicy Bypass -File scripts\github-publish.ps1 -RepoName $RepoName -Visibility $Visibility
