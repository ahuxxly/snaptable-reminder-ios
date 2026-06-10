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

Write-Section "GitHub CLI"
$gh = Get-Command gh -ErrorAction SilentlyContinue
$ghPath = $null
if ($gh) {
    $ghPath = $gh.Source
} else {
    $fallbackGhPath = "C:\Program Files\GitHub CLI\gh.exe"
    if (Test-Path $fallbackGhPath) {
        $ghPath = $fallbackGhPath
    }
}
if (-not $ghPath) {
    throw "GitHub CLI is missing. Install it, then run 'gh auth login'. On Windows: winget install --id GitHub.cli -e --source winget"
}
Write-Host "gh=$ghPath"

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
$authOutput = & $ghPath auth status 2>&1
$authExitCode = $LASTEXITCODE
$ErrorActionPreference = $previousErrorActionPreference
if ($authExitCode -ne 0) {
    Write-Host $authOutput
    throw "GitHub CLI is not authenticated. Run 'gh auth login' first."
}
Write-Host "gh authenticated"

Write-Section "Working tree"
$gitStatus = git status --short
if ($gitStatus) {
    Write-Host $gitStatus
    throw "Working tree is not clean. Commit or stash changes before publishing."
}
Write-Host "clean"

$branch = git branch --show-current
if (-not $branch) {
    throw "Could not detect the current git branch."
}

Write-Section "Remote"
$originUrl = git remote get-url origin 2>$null
if ($LASTEXITCODE -eq 0 -and $originUrl) {
    Write-Host "origin=$originUrl"
    git push -u origin $branch
} else {
    $visibilityFlag = "--$Visibility"
    & $ghPath repo create $RepoName $visibilityFlag --source . --remote origin --push
}

Write-Section "Repository"
$repoFullName = & $ghPath repo view --json nameWithOwner --jq ".nameWithOwner"
$repoFullName = ($repoFullName | Select-Object -First 1).Trim()
if (-not $repoFullName -or -not $repoFullName.Contains("/")) {
    throw "Could not determine GitHub repository name with owner."
}
Write-Host "repo=$repoFullName"

Write-Section "Support links"
$repoParts = $repoFullName -split "/", 2
powershell -ExecutionPolicy Bypass -File scripts\write-site-support-links.ps1 -Owner $repoParts[0] -RepoName $repoParts[1]
Write-Section "Fastlane store URLs"
powershell -ExecutionPolicy Bypass -File scripts\write-fastlane-store-urls.ps1 -Owner $repoParts[0] -RepoName $repoParts[1]
$generatedReleaseStatus = git status --short -- site fastlane\metadata\en-US\privacy_url.txt fastlane\metadata\en-US\support_url.txt
if ($generatedReleaseStatus) {
    Write-Host $generatedReleaseStatus
    git add site\support.html site\privacy.html
    git add fastlane\metadata\en-US\privacy_url.txt fastlane\metadata\en-US\support_url.txt
    git commit -m "docs: add public support request links"
    git push -u origin $branch
} else {
    Write-Host "site support links and Fastlane store URLs already current"
}

Write-Section "Recent workflow runs"
& $ghPath run list --limit 10

Write-Section "Next checks"
Write-Host "Open the repository Actions tab and confirm these workflows:"
Write-Host "- iOS CI"
Write-Host "- Publish App Store Site"
Write-Host ""
Write-Host "If Pages is not configured yet, open repository Settings > Pages and set Source to GitHub Actions."
