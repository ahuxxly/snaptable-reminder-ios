param(
    [string]$RepoFullName = "",
    [switch]$RunPreflight
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

function Add-Gate($gates, $name, $status, $detail, $nextAction) {
    $gates.Add([pscustomobject]@{
        Name = $name
        Status = $status
        Detail = $detail
        NextAction = $nextAction
    }) | Out-Null
}

function Write-Gates($gates) {
    foreach ($gate in $gates) {
        Write-Host "[$($gate.Status)] $($gate.Name)"
        Write-Host "  $($gate.Detail)"
        if (-not [string]::IsNullOrWhiteSpace($gate.NextAction)) {
            Write-Host "  Next: $($gate.NextAction)"
        }
    }
}

function Get-SecretNames($ghPath, $repoFullName) {
    $secretJson = & $ghPath secret list --repo $repoFullName --json name
    if ($LASTEXITCODE -ne 0) {
        throw "Could not list GitHub secrets for $repoFullName."
    }

    $secretRecords = ConvertFrom-JsonItems $secretJson
    $secretNames = New-Object "System.Collections.Generic.HashSet[string]" ([System.StringComparer]::Ordinal)
    foreach ($secretRecord in $secretRecords) {
        if ($secretRecord.name) {
            [void]$secretNames.Add([string]$secretRecord.name)
        }
    }
    return ,$secretNames
}

function ConvertFrom-JsonItems($json) {
    if ([string]::IsNullOrWhiteSpace($json)) {
        return @()
    }

    $converted = $json | ConvertFrom-Json
    if ($null -eq $converted) {
        return @()
    }

    $items = New-Object "System.Collections.Generic.List[object]"
    foreach ($item in $converted) {
        $items.Add($item) | Out-Null
    }
    return @($items.ToArray())
}

function Get-MissingNames($names, $requiredNames) {
    $missing = @()
    foreach ($requiredName in $requiredNames) {
        if (-not $names.Contains($requiredName)) {
            $missing += $requiredName
        }
    }
    return $missing
}

function Test-Url($url, $requiredText) {
    try {
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 20
        if ([int]$response.StatusCode -lt 200 -or [int]$response.StatusCode -ge 300) {
            return "HTTP $($response.StatusCode)"
        }
        if (-not [string]::IsNullOrWhiteSpace($requiredText) -and -not $response.Content.Contains($requiredText)) {
            return "missing expected page text"
        }
        return "ok"
    } catch {
        return $_.Exception.Message
    }
}

$gates = New-Object "System.Collections.Generic.List[object]"

Write-Section "Local repository"
$gitStatus = git status --short
if ($LASTEXITCODE -ne 0) {
    throw "Could not inspect git status."
}
if ($gitStatus) {
    Add-Gate $gates "Working tree" "WARN" "Local changes are present." "Commit or intentionally keep them before release-triggering commands."
} else {
    Add-Gate $gates "Working tree" "OK" "Clean."
}

$branch = (git branch --show-current).Trim()
$head = (git log -1 --oneline).Trim()
Write-Host "branch=$branch"
Write-Host "head=$head"

if ($RunPreflight) {
    Write-Section "Windows preflight"
    powershell -ExecutionPolicy Bypass -File scripts\windows-preflight.ps1
    if ($LASTEXITCODE -ne 0) {
        Add-Gate $gates "Windows preflight" "BLOCKED" "Preflight failed." "Fix the failing preflight output before release."
    } else {
        Add-Gate $gates "Windows preflight" "OK" "Preflight completed."
    }
} else {
    Add-Gate $gates "Windows preflight" "WARN" "Not run in this doctor pass." "Run scripts/release-doctor.ps1 -RunPreflight for the local static release gate."
}

$ghPath = Resolve-GitHubCli

Write-Section "GitHub"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
$authOutput = & $ghPath auth status 2>&1
$authExitCode = $LASTEXITCODE
$ErrorActionPreference = $previousErrorActionPreference
if ($authExitCode -ne 0) {
    Write-Host $authOutput
    throw "GitHub CLI is not authenticated. Run 'gh auth login' first."
}

if ([string]::IsNullOrWhiteSpace($RepoFullName)) {
    $RepoFullName = (& $ghPath repo view --json nameWithOwner --jq ".nameWithOwner").Trim()
}
if (-not $RepoFullName -or -not $RepoFullName.Contains("/")) {
    throw "RepoFullName must look like owner/repo."
}
Write-Host "repo=$RepoFullName"

$repoInfo = & $ghPath repo view $RepoFullName --json isPrivate,url
if ($LASTEXITCODE -ne 0) {
    throw "Could not inspect GitHub repository $RepoFullName."
}
$repo = $repoInfo | ConvertFrom-Json
if ($repo.isPrivate -eq $false) {
    Add-Gate $gates "GitHub repository" "OK" "Public repository: $($repo.url)"
} else {
    Add-Gate $gates "GitHub repository" "WARN" "Repository is private." "Use public visibility before relying on GitHub Pages support links."
}

$workflowJson = & $ghPath workflow list --repo $RepoFullName --json name,state
if ($LASTEXITCODE -ne 0) {
    throw "Could not list GitHub workflows."
}
$workflowRecords = ConvertFrom-JsonItems $workflowJson
$workflowNames = New-Object "System.Collections.Generic.HashSet[string]" ([System.StringComparer]::Ordinal)
foreach ($workflow in $workflowRecords) {
    if ($workflow.state -eq "active") {
        [void]$workflowNames.Add([string]$workflow.name)
    }
}
$requiredWorkflows = @(
    "iOS CI",
    "Publish App Store Site",
    "Release Readiness",
    "App Store Screenshots",
    "App Store Connect Upload",
    "TestFlight Upload",
    "App Review Submit"
)
$missingWorkflows = Get-MissingNames $workflowNames $requiredWorkflows
if ($missingWorkflows.Count -eq 0) {
    Add-Gate $gates "GitHub workflows" "OK" "All release workflows are active."
} else {
    Add-Gate $gates "GitHub workflows" "BLOCKED" "Missing or inactive workflows: $($missingWorkflows -join ', ')." "Push workflow fixes before release."
}

foreach ($workflowName in @("iOS CI", "Publish App Store Site", "Release Readiness")) {
    $runJson = & $ghPath run list --repo $RepoFullName --workflow $workflowName --limit 1 --json workflowName,status,conclusion,headSha,url
    if ($LASTEXITCODE -ne 0) {
        throw "Could not list GitHub workflow runs for $workflowName."
    }
    $latestRun = @(ConvertFrom-JsonItems $runJson) | Select-Object -First 1
    if ($null -eq $latestRun) {
        Add-Gate $gates $workflowName "BLOCKED" "No recent run found." "Run or push the workflow before release."
    } elseif ($latestRun.status -eq "completed" -and $latestRun.conclusion -eq "success") {
        Add-Gate $gates $workflowName "OK" "Latest run succeeded: $($latestRun.url)"
    } else {
        Add-Gate $gates $workflowName "BLOCKED" "Latest run status=$($latestRun.status), conclusion=$($latestRun.conclusion)." "Open $($latestRun.url) and fix before release."
    }
}

Write-Section "Public support URLs"
$privacyUrl = "https://ahuxxly.github.io/snaptable-reminder-ios/privacy.html"
$supportUrl = "https://ahuxxly.github.io/snaptable-reminder-ios/support.html"
$privacyStatus = Test-Url $privacyUrl "Privacy Policy"
$supportStatus = Test-Url $supportUrl "Support"
if ($privacyStatus -eq "ok" -and $supportStatus -eq "ok") {
    Add-Gate $gates "Privacy and support URLs" "OK" "Privacy and support pages are reachable."
} else {
    Add-Gate $gates "Privacy and support URLs" "BLOCKED" "privacy=$privacyStatus; support=$supportStatus" "Fix GitHub Pages before App Store metadata upload."
}

Write-Section "GitHub secrets"
$secretNames = Get-SecretNames $ghPath $RepoFullName
$uploadSecrets = @(
    "APP_STORE_CONNECT_USERNAME",
    "APPLE_DEVELOPER_TEAM_ID",
    "APP_STORE_CONNECT_API_KEY_ID",
    "APP_STORE_CONNECT_API_ISSUER_ID",
    "APP_STORE_CONNECT_API_PRIVATE_KEY"
)
$signingSecrets = @(
    "APPLE_DISTRIBUTION_CERTIFICATE_BASE64",
    "APPLE_DISTRIBUTION_CERTIFICATE_PASSWORD",
    "APPLE_APP_STORE_PROFILE_BASE64",
    "APPLE_CODESIGN_KEYCHAIN_PASSWORD"
)
$reviewSecrets = @(
    "APP_REVIEW_FIRST_NAME",
    "APP_REVIEW_LAST_NAME",
    "APP_REVIEW_EMAIL",
    "APP_REVIEW_PHONE"
)

$missingUploadSecrets = Get-MissingNames $secretNames $uploadSecrets
if ($missingUploadSecrets.Count -eq 0) {
    Add-Gate $gates "App Store Connect upload secrets" "OK" "Upload secrets are configured."
} else {
    Add-Gate $gates "App Store Connect upload secrets" "BLOCKED" "Missing: $($missingUploadSecrets -join ', ')." "Run scripts/github-set-apple-secrets.ps1 -UploadOnly after the Apple API key exists."
}

$missingSigningSecrets = Get-MissingNames $secretNames $signingSecrets
if ($missingSigningSecrets.Count -eq 0) {
    Add-Gate $gates "Apple signing secrets" "OK" "Signing secrets are configured."
} else {
    Add-Gate $gates "Apple signing secrets" "BLOCKED" "Missing: $($missingSigningSecrets -join ', ')." "Run scripts/github-set-apple-secrets.ps1 -SigningOnly after the certificate and profile exist."
}

$missingReviewSecrets = Get-MissingNames $secretNames $reviewSecrets
if ($missingReviewSecrets.Count -eq 0) {
    Add-Gate $gates "App Review contact secrets" "OK" "Review contact secrets are configured."
} else {
    Add-Gate $gates "App Review contact secrets" "BLOCKED" "Missing: $($missingReviewSecrets -join ', ')." "Run scripts/github-set-apple-secrets.ps1 -ReviewOnly after choosing private review contact details."
}

Write-Section "External Apple gates"
Add-Gate $gates "Apple Developer Program" "BLOCKED" "Cannot verify from this workspace." "Confirm membership, Paid Apps Agreement, tax, and banking in App Store Connect."
Add-Gate $gates "App Store Connect app record" "BLOCKED" "Cannot verify from this workspace without Apple credentials." "Create the iOS app record for com.snaptable.reminder using docs/app-store/app-store-fields.json."
Add-Gate $gates "EU DSA trader status" "BLOCKED" "Cannot verify from this workspace." "Complete docs/app-store/eu-dsa-trader.md, or intentionally exclude EU storefronts."
Add-Gate $gates "Build uploaded and submitted" "BLOCKED" "No App Store Connect evidence is available in this workspace." "After secrets exist, run scripts/github-run-app-store-release.ps1 -Wait, then scripts/github-submit-app-review.ps1 -ConfirmSubmitForReview YES -Wait."

Write-Section "Summary"
Write-Gates $gates

$blockedCount = @($gates | Where-Object { $_.Status -eq "BLOCKED" }).Count
$warnCount = @($gates | Where-Object { $_.Status -eq "WARN" }).Count
Write-Host ""
Write-Host "blocked=$blockedCount warn=$warnCount ok=$(@($gates | Where-Object { $_.Status -eq "OK" }).Count)"

if ($blockedCount -gt 0) {
    Write-Host ""
    Write-Host "Release is not ready. The next hard blocker is the Apple account/App Store Connect material set."
    exit 2
}

if ($warnCount -gt 0) {
    exit 1
}
