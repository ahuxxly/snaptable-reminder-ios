param(
    [string]$RepoFullName = "",
    [string]$Ref = "",
    [ValidateSet("YES", "NO")]
    [string]$ConfirmSubmitForReview = "NO",
    [switch]$StatusOnly,
    [switch]$DryRun,
    [switch]$Wait
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

function Get-SecretNames($ghPath, $repoFullName) {
    $secretJson = & $ghPath secret list --repo $repoFullName --json name
    if ($LASTEXITCODE -ne 0) {
        throw "Could not list GitHub secrets for $repoFullName."
    }

    $secretRecords = @($secretJson | ConvertFrom-Json)
    $secretNames = New-Object "System.Collections.Generic.HashSet[string]" ([System.StringComparer]::Ordinal)
    foreach ($secretRecord in $secretRecords) {
        if ($secretRecord.name) {
            [void]$secretNames.Add([string]$secretRecord.name)
        }
    }
    return ,$secretNames
}

function Get-MissingSecrets($secretNames, $requiredSecrets) {
    $missing = @()
    foreach ($requiredSecret in $requiredSecrets) {
        if (-not $secretNames.Contains($requiredSecret)) {
            $missing += $requiredSecret
        }
    }
    return $missing
}

function Get-LatestWorkflowRunId($ghPath, $repoFullName, $workflowFile, $notBefore) {
    for ($attempt = 1; $attempt -le 12; $attempt++) {
        $runJson = & $ghPath run list --repo $repoFullName --workflow $workflowFile --event workflow_dispatch --limit 10 --json databaseId,createdAt
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($runJson)) {
            $runs = @($runJson | ConvertFrom-Json)
            foreach ($run in $runs) {
                if ($run.databaseId -and $run.createdAt) {
                    $createdAt = [DateTimeOffset]::Parse([string]$run.createdAt)
                    if ($createdAt -ge $notBefore) {
                        return [string]$run.databaseId
                    }
                }
            }
        }
        Start-Sleep -Seconds 5
    }

    return $null
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
    Write-Host $authOutput
    throw "GitHub CLI is not authenticated. Run 'gh auth login' first."
}
Write-Host "gh authenticated"

Write-Section "Repository"
if ([string]::IsNullOrWhiteSpace($RepoFullName)) {
    $RepoFullName = (& $ghPath repo view --json nameWithOwner --jq ".nameWithOwner").Trim()
}
if (-not $RepoFullName -or -not $RepoFullName.Contains("/")) {
    throw "RepoFullName must look like owner/repo."
}
Write-Host "repo=$RepoFullName"

if ([string]::IsNullOrWhiteSpace($Ref)) {
    $Ref = (git branch --show-current).Trim()
}
if ([string]::IsNullOrWhiteSpace($Ref)) {
    $Ref = "master"
}
Write-Host "ref=$Ref"

$requiredSecrets = @(
    "APP_STORE_CONNECT_USERNAME",
    "APPLE_DEVELOPER_TEAM_ID",
    "APP_STORE_CONNECT_API_KEY_ID",
    "APP_STORE_CONNECT_API_ISSUER_ID",
    "APP_STORE_CONNECT_API_PRIVATE_KEY",
    "APP_REVIEW_FIRST_NAME",
    "APP_REVIEW_LAST_NAME",
    "APP_REVIEW_EMAIL",
    "APP_REVIEW_PHONE"
)

$secretNames = Get-SecretNames $ghPath $RepoFullName
Write-Section "Required review submission secrets"
foreach ($requiredSecret in $requiredSecrets) {
    if ($secretNames.Contains($requiredSecret)) {
        Write-Host "$requiredSecret=present"
    } else {
        Write-Host "$requiredSecret=missing"
    }
}

Write-Section "Recent workflow runs"
$recentRuns = & $ghPath run list --repo $RepoFullName --limit 8
if ($LASTEXITCODE -ne 0) {
    throw "Could not list recent workflow runs for $RepoFullName."
}
$recentRuns | ForEach-Object { Write-Host $_ }

if ($StatusOnly) {
    Write-Host ""
    Write-Host "Status only; no workflows were triggered."
    exit 0
}

if ($ConfirmSubmitForReview -ne "YES") {
    throw "Pass -ConfirmSubmitForReview YES to submit the latest processed build for App Review."
}

$missingSecrets = Get-MissingSecrets $secretNames $requiredSecrets
if ($missingSecrets.Count -gt 0) {
    throw "Missing App Review submission secrets: $($missingSecrets -join ', '). Configure them before submitting."
}

$arguments = @(
    "workflow",
    "run",
    "app-review-submit.yml",
    "--repo",
    $RepoFullName,
    "--ref",
    $Ref,
    "-f",
    "confirm_submit_for_review=YES"
)

$dispatchNotBefore = [DateTimeOffset]::UtcNow.AddSeconds(-10)

Write-Section "Trigger App Review Submit"
if ($DryRun) {
    Write-Host "dry-run: gh $($arguments -join ' ')"
    Write-Host ""
    Write-Host "Dry run complete; no workflows were triggered."
    exit 0
}

$output = & $ghPath @arguments
if ($LASTEXITCODE -ne 0) {
    throw "Could not trigger App Review Submit workflow."
}
$outputText = ($output | Out-String).Trim()
if ($outputText) {
    Write-Host $outputText
}

$runId = $null
$match = [regex]::Match($outputText, "/actions/runs/(\d+)")
if ($match.Success) {
    $runId = $match.Groups[1].Value
}

if ($Wait -and $runId) {
    Write-Section "Wait for App Review Submit"
    & $ghPath run watch $runId --repo $RepoFullName --compact --exit-status --interval 10
    if ($LASTEXITCODE -ne 0) {
        throw "App Review Submit workflow failed."
    }
} elseif ($Wait) {
    Write-Section "Find App Review Submit run"
    $runId = Get-LatestWorkflowRunId $ghPath $RepoFullName "app-review-submit.yml" $dispatchNotBefore
    if (-not $runId) {
        throw "Could not find the App Review Submit workflow run to watch."
    }
    Write-Host "run=$runId"

    Write-Section "Wait for App Review Submit"
    & $ghPath run watch $runId --repo $RepoFullName --compact --exit-status --interval 10
    if ($LASTEXITCODE -ne 0) {
        throw "App Review Submit workflow failed."
    }
}

Write-Host ""
Write-Host "App Review Submit workflow triggered for $RepoFullName."
