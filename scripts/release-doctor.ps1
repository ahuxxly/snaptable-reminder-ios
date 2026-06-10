param(
    [string]$RepoFullName = "",
    [switch]$RunPreflight,
    [switch]$LocalOnly,
    [string]$EntryPackDirectory = "",
    [string]$MaterialsDirectory = ""
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

function Complete-Doctor($gates) {
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

function Invoke-GhJson($ghPath, $arguments, $failureMessage) {
    $output = & $ghPath @arguments
    if ($LASTEXITCODE -ne 0) {
        throw $failureMessage
    }
    return $output
}

function Get-DocumentsDirectory {
    $documents = [Environment]::GetFolderPath("MyDocuments")
    if ([string]::IsNullOrWhiteSpace($documents)) {
        $documents = [Environment]::GetFolderPath("UserProfile")
    }
    if ([string]::IsNullOrWhiteSpace($documents)) {
        $documents = [System.IO.Path]::GetTempPath()
    }
    return $documents
}

function Resolve-ArtifactPath($path, $defaultLeafName) {
    if ([string]::IsNullOrWhiteSpace($path)) {
        return [System.IO.Path]::GetFullPath((Join-Path (Get-DocumentsDirectory) $defaultLeafName))
    }
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path $path))
}

function Test-EntryPack($gates, $entryPackDirectory, $explicitPath) {
    $entryPackPath = Resolve-ArtifactPath $entryPackDirectory "SnapTableReminder-AppStoreConnect-EntryPack"
    Write-Host "entryPack=$entryPackPath"

    if (-not (Test-Path $entryPackPath)) {
        if ($explicitPath) {
            Add-Gate $gates "App Store Connect entry packet" "BLOCKED" "Entry packet folder is missing: $entryPackPath" "Run scripts/export-app-store-connect-entry-pack.ps1 -OutputDirectory `"$entryPackPath`"."
        } else {
            Add-Gate $gates "App Store Connect entry packet" "WARN" "Default entry packet folder is missing: $entryPackPath" "Run scripts/export-app-store-connect-entry-pack.ps1."
        }
        return
    }

    $requiredEntryPackFiles = @(
        "README.md",
        "00-app-record.txt",
        "01-pricing-availability.txt",
        "02-version-metadata.txt",
        "03-privacy-compliance.txt",
        "04-review.txt",
        "app-store-connect-entry-pack.json"
    )
    $missingFiles = @()
    foreach ($entryPackFile in $requiredEntryPackFiles) {
        if (-not (Test-Path (Join-Path $entryPackPath $entryPackFile))) {
            $missingFiles += $entryPackFile
        }
    }
    if ($missingFiles.Count -gt 0) {
        Add-Gate $gates "App Store Connect entry packet" "BLOCKED" "Missing files: $($missingFiles -join ', ')." "Regenerate the packet with scripts/export-app-store-connect-entry-pack.ps1."
        return
    }

    try {
        $entryPacket = Get-Content (Join-Path $entryPackPath "app-store-connect-entry-pack.json") -Raw | ConvertFrom-Json
        if ($entryPacket.app.bundleId -ne "com.snaptable.reminder") {
            Add-Gate $gates "App Store Connect entry packet" "BLOCKED" "Entry packet bundle id is $($entryPacket.app.bundleId)." "Regenerate the packet from the current repository sources."
            return
        }
        if ([string]::IsNullOrWhiteSpace($entryPacket.urls.privacyPolicyUrl) -or [string]::IsNullOrWhiteSpace($entryPacket.urls.supportUrl)) {
            Add-Gate $gates "App Store Connect entry packet" "BLOCKED" "Entry packet is missing hosted privacy/support URLs." "Regenerate the packet with owner and repo parameters."
            return
        }
    } catch {
        Add-Gate $gates "App Store Connect entry packet" "BLOCKED" "Entry packet JSON is invalid." "Regenerate the packet with scripts/export-app-store-connect-entry-pack.ps1."
        return
    }

    Add-Gate $gates "App Store Connect entry packet" "OK" "Paste-ready packet is present at $entryPackPath."
}

function Test-Materials($gates, $materialsDirectory, $explicitPath) {
    $materialsPath = Resolve-ArtifactPath $materialsDirectory "SnapTableReminder-Apple-Materials"
    Write-Host "materials=$materialsPath"

    if (-not (Test-Path $materialsPath)) {
        if ($explicitPath) {
            Add-Gate $gates "Apple private material folder" "BLOCKED" "Materials folder is missing: $materialsPath" "Run scripts/prepare-apple-materials-folder.ps1 -OutputDirectory `"$materialsPath`"."
        } else {
            Add-Gate $gates "Apple private material folder" "WARN" "Default materials folder is missing: $materialsPath" "Run scripts/prepare-apple-materials-folder.ps1."
        }
        return $null
    }

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $validationOutput = powershell -NoProfile -ExecutionPolicy Bypass -File scripts\prepare-apple-materials-folder.ps1 -OutputDirectory $materialsPath -ValidateOnly 2>&1 | Out-String
        $validationExitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    if ($validationExitCode -ne 0) {
        Add-Gate $gates "Apple private material folder" "BLOCKED" "Materials folder validation failed." "Use scripts/stage-apple-release-materials.ps1 after downloading Apple files, or open $materialsPath and add the missing files listed by scripts/prepare-apple-materials-folder.ps1 -ValidateOnly."
        if ($validationOutput) {
            Write-Host $validationOutput.Trim()
        }
        return $null
    }

    Add-Gate $gates "Apple private material folder" "OK" "Private Apple material folder validates at $materialsPath."
    return $materialsPath
}

function Test-ReleaseEvidence($gates, $materialsPath) {
    $evidencePath = Join-Path $materialsPath "05-release-evidence\release-evidence.private.json"
    if (-not (Test-Path $evidencePath)) {
        Add-Gate $gates "App Store release evidence" "BLOCKED" "No App Store Connect release evidence is recorded in the private materials folder." "After upload/submission, run scripts/record-app-store-release-evidence.ps1 -MaterialsDirectory `"$materialsPath`"."
        return
    }

    try {
        $evidence = Get-Content $evidencePath -Raw | ConvertFrom-Json
    } catch {
        Add-Gate $gates "App Store release evidence" "BLOCKED" "release-evidence.private.json is not valid JSON." "Regenerate it with scripts/record-app-store-release-evidence.ps1."
        return
    }

    $missingFields = @()
    foreach ($field in @("appStoreConnectAppId", "appVersion", "buildNumber", "appStatus")) {
        if ([string]::IsNullOrWhiteSpace([string]$evidence.$field)) {
            $missingFields += $field
        }
    }
    if ($missingFields.Count -gt 0) {
        Add-Gate $gates "App Store release evidence" "BLOCKED" "Evidence is missing: $($missingFields -join ', ')." "Regenerate it with scripts/record-app-store-release-evidence.ps1."
        return
    }

    $requiredCompletedFlags = @(
        "metadataUploaded",
        "screenshotsUploaded",
        "reviewCheckPassed",
        "testFlightUploaded",
        "buildProcessed",
        "appReviewSubmitted"
    )
    $missingFlags = @()
    foreach ($flag in $requiredCompletedFlags) {
        if ($evidence.status.$flag -ne $true) {
            $missingFlags += $flag
        }
    }
    if ($missingFlags.Count -gt 0) {
        Add-Gate $gates "App Store release evidence" "BLOCKED" "Evidence is not complete: $($missingFlags -join ', ')." "Record the missing upload/submission evidence after the corresponding App Store Connect step succeeds."
        return
    }

    $acceptableSubmittedStatuses = @(
        "Waiting for Review",
        "In Review",
        "Pending Developer Release",
        "Ready for Distribution"
    )
    if ($acceptableSubmittedStatuses -notcontains [string]$evidence.appStatus) {
        Add-Gate $gates "App Store release evidence" "BLOCKED" "App Store status is '$($evidence.appStatus)', not a submitted/releasable status." "Record evidence again after App Store Connect shows Waiting for Review or later."
        return
    }

    Add-Gate $gates "App Store release evidence" "OK" "Version $($evidence.appVersion) build $($evidence.buildNumber) is recorded with status '$($evidence.appStatus)'."
}

function Test-AppStoreConnectSetupEvidence($gates, $materialsPath) {
    $setupPath = Join-Path $materialsPath "05-release-evidence\app-store-connect-setup.private.json"
    if (-not (Test-Path $setupPath)) {
        Add-Gate $gates "App Store Connect setup evidence" "BLOCKED" "No App Store Connect setup evidence is recorded in the private materials folder." "After creating the app record and completing pricing, availability, privacy, age rating, export compliance, and EU DSA fields, run scripts/record-app-store-connect-setup-evidence.ps1 -MaterialsDirectory `"$materialsPath`"."
        return
    }

    try {
        $setup = Get-Content $setupPath -Raw | ConvertFrom-Json
        $storeFields = Get-Content "docs\app-store\app-store-fields.json" -Raw | ConvertFrom-Json
    } catch {
        Add-Gate $gates "App Store Connect setup evidence" "BLOCKED" "Setup evidence or source App Store fields JSON is invalid." "Regenerate setup evidence with scripts/record-app-store-connect-setup-evidence.ps1."
        return
    }

    $missingFields = @()
    foreach ($field in @("appStoreConnectAppId", "app", "pricing", "availability", "urls", "compliance")) {
        if ($null -eq $setup.$field) {
            $missingFields += $field
        }
    }
    if ($missingFields.Count -gt 0) {
        Add-Gate $gates "App Store Connect setup evidence" "BLOCKED" "Setup evidence is missing: $($missingFields -join ', ')." "Regenerate setup evidence with scripts/record-app-store-connect-setup-evidence.ps1."
        return
    }

    $mismatches = @()
    if ($setup.app.name -ne $storeFields.app.name) { $mismatches += "app.name" }
    if ($setup.app.bundleId -ne $storeFields.app.bundleId) { $mismatches += "app.bundleId" }
    if ($setup.app.sku -ne $storeFields.app.sku) { $mismatches += "app.sku" }
    if ($setup.app.primaryLanguage -ne $storeFields.app.primaryLanguage) { $mismatches += "app.primaryLanguage" }
    if ($setup.app.primaryCategory -ne $storeFields.app.category) { $mismatches += "app.primaryCategory" }
    if ($setup.pricing.currency -ne $storeFields.pricing.startingPrice.currency -or [decimal]$setup.pricing.amount -ne [decimal]$storeFields.pricing.startingPrice.amount) { $mismatches += "pricing" }
    if ($setup.availability.mode -ne $storeFields.availability.strategy) { $mismatches += "availability.mode" }
    foreach ($excludedRegion in @($storeFields.availability.excludeCountriesOrRegions)) {
        if (-not (@($setup.availability.excludeCountriesOrRegions) -contains $excludedRegion)) {
            $mismatches += "availability.excludeCountriesOrRegions:$excludedRegion"
        }
    }
    if (-not (@($setup.availability.excludeCountriesOrRegions) -contains "China mainland")) {
        $mismatches += "availability.excludeCountriesOrRegions:China mainland"
    }
    foreach ($flag in @("privacyAnswersCompleted", "ageRatingCompleted", "exportComplianceCompleted", "euDsaTraderStatusCompleted")) {
        if ($setup.compliance.$flag -ne $true) {
            $mismatches += "compliance.$flag"
        }
    }

    if ($mismatches.Count -gt 0) {
        Add-Gate $gates "App Store Connect setup evidence" "BLOCKED" "Setup evidence does not match release requirements: $($mismatches -join ', ')." "Update App Store Connect, then rerun scripts/record-app-store-connect-setup-evidence.ps1."
        return
    }

    Add-Gate $gates "App Store Connect setup evidence" "OK" "App record, pricing, availability, privacy, and compliance setup evidence matches release requirements."
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

Write-Section "Local release artifacts"
Test-EntryPack $gates $EntryPackDirectory (-not [string]::IsNullOrWhiteSpace($EntryPackDirectory))
$validMaterialsPath = Test-Materials $gates $MaterialsDirectory (-not [string]::IsNullOrWhiteSpace($MaterialsDirectory))
if (-not [string]::IsNullOrWhiteSpace($validMaterialsPath)) {
    Test-AppStoreConnectSetupEvidence $gates $validMaterialsPath
    Test-ReleaseEvidence $gates $validMaterialsPath
}

if ($LocalOnly) {
    Complete-Doctor $gates
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
    Add-Gate $gates "GitHub CLI authentication" "BLOCKED" "gh auth status reports an invalid or missing GitHub session." "Run gh auth refresh -h github.com or gh auth login before setting secrets, updating issues, or triggering release workflows."
} else {
    Add-Gate $gates "GitHub CLI authentication" "OK" "GitHub CLI is authenticated."
}

if ([string]::IsNullOrWhiteSpace($RepoFullName)) {
    try {
        $RepoFullName = (& $ghPath repo view --json nameWithOwner --jq ".nameWithOwner").Trim()
    } catch {
        $RepoFullName = ""
    }
}
if (-not $RepoFullName -or -not $RepoFullName.Contains("/")) {
    Add-Gate $gates "GitHub repository" "BLOCKED" "Could not resolve repository name." "Pass -RepoFullName owner/repo after GitHub CLI auth is healthy."
    $RepoFullName = ""
} else {
    Write-Host "repo=$RepoFullName"
}

if (-not [string]::IsNullOrWhiteSpace($RepoFullName)) {
    try {
        $repoInfo = Invoke-GhJson $ghPath @("repo", "view", $RepoFullName, "--json", "isPrivate,url") "Could not inspect GitHub repository $RepoFullName."
        $repo = $repoInfo | ConvertFrom-Json
        if ($repo.isPrivate -eq $false) {
            Add-Gate $gates "GitHub repository" "OK" "Public repository: $($repo.url)"
        } else {
            Add-Gate $gates "GitHub repository" "WARN" "Repository is private." "Use public visibility before relying on GitHub Pages support links."
        }
    } catch {
        Add-Gate $gates "GitHub repository" "BLOCKED" $_.Exception.Message "Fix GitHub CLI auth or network access, then rerun the release doctor."
    }
}

if (-not [string]::IsNullOrWhiteSpace($RepoFullName)) {
    try {
        $workflowJson = Invoke-GhJson $ghPath @("workflow", "list", "--repo", $RepoFullName, "--json", "name,state") "Could not list GitHub workflows."
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
    } catch {
        Add-Gate $gates "GitHub workflows" "BLOCKED" $_.Exception.Message "Fix GitHub CLI auth or network access, then rerun the release doctor."
    }
}

if (-not [string]::IsNullOrWhiteSpace($RepoFullName)) {
    foreach ($workflowName in @("iOS CI", "Publish App Store Site", "Release Readiness")) {
        try {
            $runJson = Invoke-GhJson $ghPath @("run", "list", "--repo", $RepoFullName, "--workflow", $workflowName, "--limit", "1", "--json", "workflowName,status,conclusion,headSha,url") "Could not list GitHub workflow runs for $workflowName."
            $latestRun = @(ConvertFrom-JsonItems $runJson) | Select-Object -First 1
            if ($null -eq $latestRun) {
                Add-Gate $gates $workflowName "BLOCKED" "No recent run found." "Run or push the workflow before release."
            } elseif ($latestRun.status -eq "completed" -and $latestRun.conclusion -eq "success") {
                Add-Gate $gates $workflowName "OK" "Latest run succeeded: $($latestRun.url)"
            } else {
                Add-Gate $gates $workflowName "BLOCKED" "Latest run status=$($latestRun.status), conclusion=$($latestRun.conclusion)." "Open $($latestRun.url) and fix before release."
            }
        } catch {
            Add-Gate $gates $workflowName "BLOCKED" $_.Exception.Message "Fix GitHub CLI auth or network access, then rerun the release doctor."
        }
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

if ([string]::IsNullOrWhiteSpace($RepoFullName)) {
    Add-Gate $gates "GitHub secrets" "BLOCKED" "Repository is unresolved." "Pass -RepoFullName owner/repo after GitHub CLI auth is healthy."
} else {
    try {
        $secretNames = Get-SecretNames $ghPath $RepoFullName

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
    } catch {
        Add-Gate $gates "GitHub secrets" "BLOCKED" $_.Exception.Message "Fix GitHub CLI auth or network access before configuring release secrets."
    }
}

Write-Section "External Apple gates"
Add-Gate $gates "Apple Developer Program" "BLOCKED" "Cannot verify from this workspace." "Confirm membership, Paid Apps Agreement, tax, and banking in App Store Connect."
Add-Gate $gates "App Store Connect app record" "BLOCKED" "Cannot verify from this workspace without Apple credentials." "Create the iOS app record for com.snaptable.reminder using docs/app-store/app-store-fields.json."
Add-Gate $gates "EU DSA trader status" "BLOCKED" "Cannot verify from this workspace." "Complete docs/app-store/eu-dsa-trader.md, or intentionally exclude EU storefronts."
if (-not [string]::IsNullOrWhiteSpace($validMaterialsPath)) {
    Add-Gate $gates "Build uploaded and submitted" "WARN" "Use the local App Store release evidence gate above as the workspace evidence source." "Keep release-evidence.private.json updated after each App Store Connect status change."
} else {
    Add-Gate $gates "Build uploaded and submitted" "BLOCKED" "No App Store Connect evidence is available in this workspace." "After secrets exist, run scripts/github-run-app-store-release.ps1 -Wait, then scripts/github-submit-app-review.ps1 -ConfirmSubmitForReview YES -Wait."
}

Complete-Doctor $gates
