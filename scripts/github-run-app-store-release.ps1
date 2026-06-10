param(
    [string]$RepoFullName = "",
    [string]$Ref = "",

    [switch]$StatusOnly,
    [switch]$DryRun,
    [switch]$Wait,

    [switch]$SkipMetadata,
    [switch]$SkipScreenshots,
    [switch]$SkipReviewCheck,
    [switch]$SkipTestFlight
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

function Get-RepoFullName($ghPath, $repoFullName) {
    if (-not [string]::IsNullOrWhiteSpace($repoFullName)) {
        return $repoFullName.Trim()
    }

    $detectedRepo = (& $ghPath repo view --json nameWithOwner --jq ".nameWithOwner").Trim()
    if (-not $detectedRepo -or -not $detectedRepo.Contains("/")) {
        throw "Could not determine GitHub repository. Pass -RepoFullName owner/repo."
    }
    return $detectedRepo
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

function Write-SecretStatus($title, $secretNames, $requiredSecrets) {
    Write-Section $title
    foreach ($requiredSecret in $requiredSecrets) {
        if ($secretNames.Contains($requiredSecret)) {
            Write-Host "$requiredSecret=present"
        } else {
            Write-Host "$requiredSecret=missing"
        }
    }
}

function Invoke-Workflow($ghPath, $repoFullName, $workflowFile, $ref, $fields, $dryRun) {
    $arguments = @("workflow", "run", $workflowFile, "--repo", $repoFullName)
    if (-not [string]::IsNullOrWhiteSpace($ref)) {
        $arguments += @("--ref", $ref)
    }
    foreach ($field in $fields.GetEnumerator()) {
        $arguments += @("-f", "$($field.Key)=$($field.Value)")
    }

    if ($dryRun) {
        Write-Host "dry-run: gh $($arguments -join ' ')"
        return $null
    }

    $output = & $ghPath @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Could not trigger workflow $workflowFile."
    }
    $outputText = ($output | Out-String).Trim()
    if ($outputText) {
        Write-Host $outputText
    }

    $match = [regex]::Match($outputText, "/actions/runs/(\d+)")
    if ($match.Success) {
        return $match.Groups[1].Value
    }

    return $null
}

function Watch-Run($ghPath, $repoFullName, $runId) {
    if (-not $runId) {
        Write-Host "No run id was returned; use 'gh run list --repo $repoFullName --limit 5' to inspect the new run."
        return
    }

    & $ghPath run watch $runId --repo $repoFullName --compact --exit-status --interval 10
    if ($LASTEXITCODE -ne 0) {
        throw "Workflow run $runId failed."
    }
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
$RepoFullName = Get-RepoFullName $ghPath $RepoFullName
if (-not $RepoFullName.Contains("/")) {
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

$secretNames = Get-SecretNames $ghPath $RepoFullName
Write-SecretStatus "App Store Connect upload secrets" $secretNames $uploadSecrets
Write-SecretStatus "Apple signing secrets" $secretNames $signingSecrets

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

$willRunAppStoreConnectUpload = -not ($SkipMetadata -and $SkipScreenshots -and $SkipReviewCheck)
$willRunTestFlight = -not $SkipTestFlight

if (-not $willRunAppStoreConnectUpload -and -not $willRunTestFlight) {
    Write-Host ""
    Write-Host "All upload steps are skipped; no workflows were triggered."
    exit 0
}

$missingUploadSecrets = Get-MissingSecrets $secretNames $uploadSecrets
if ($willRunAppStoreConnectUpload -and $missingUploadSecrets.Count -gt 0) {
    throw "Missing App Store Connect upload secrets: $($missingUploadSecrets -join ', '). Run scripts/github-set-apple-secrets.ps1 -UploadOnly first."
}

if ($willRunTestFlight) {
    $missingTestFlightSecrets = Get-MissingSecrets $secretNames ($uploadSecrets + $signingSecrets)
    if ($missingTestFlightSecrets.Count -gt 0) {
        throw "Missing TestFlight upload secrets: $($missingTestFlightSecrets -join ', '). Run scripts/github-set-apple-secrets.ps1 first."
    }
}

$triggeredRunIds = @()

if ($willRunAppStoreConnectUpload) {
    Write-Section "Trigger App Store Connect Upload"
    $fields = @{
        upload_metadata = (-not $SkipMetadata).ToString().ToLowerInvariant()
        upload_screenshots = (-not $SkipScreenshots).ToString().ToLowerInvariant()
        run_review_check = (-not $SkipReviewCheck).ToString().ToLowerInvariant()
    }
    $runId = Invoke-Workflow $ghPath $RepoFullName "app-store-connect-upload.yml" $Ref $fields $DryRun
    if ($runId) {
        $triggeredRunIds += $runId
    }
}

if ($willRunTestFlight) {
    Write-Section "Trigger TestFlight Upload"
    $runId = Invoke-Workflow $ghPath $RepoFullName "testflight-upload.yml" $Ref @{} $DryRun
    if ($runId) {
        $triggeredRunIds += $runId
    }
}

if ($Wait -and -not $DryRun) {
    Write-Section "Wait for workflow runs"
    foreach ($runId in $triggeredRunIds) {
        Watch-Run $ghPath $RepoFullName $runId
    }
}

Write-Host ""
if ($DryRun) {
    Write-Host "Dry run complete; no workflows were triggered."
} else {
    Write-Host "Release workflows triggered for $RepoFullName."
}
