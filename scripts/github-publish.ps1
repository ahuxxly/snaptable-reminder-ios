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
if (-not $gh) {
    throw "GitHub CLI is missing. Install it, then run 'gh auth login'. On Windows: winget install --id GitHub.cli -e --source winget"
}

$authOutput = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
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
    gh repo create $RepoName $visibilityFlag --source . --remote origin --push
}

Write-Section "Repository"
$repoFullName = gh repo view --json nameWithOwner --jq ".nameWithOwner"
Write-Host "repo=$repoFullName"

Write-Section "Recent workflow runs"
gh run list --limit 10

Write-Section "Next checks"
Write-Host "Open the repository Actions tab and confirm these workflows:"
Write-Host "- iOS CI"
Write-Host "- Publish App Store Site"
Write-Host ""
Write-Host "If Pages is not configured yet, open repository Settings > Pages and set Source to GitHub Actions."
