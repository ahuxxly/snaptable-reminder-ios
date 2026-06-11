param(
    [string]$RepoFullName = "",
    [switch]$RunPreflight,
    [switch]$LocalOnly,
    [switch]$LoadFunctionsOnly,
    [string]$EntryPackDirectory = "",
    [string]$SubmissionPacketDirectory = "",
    [string]$MaterialsDirectory = "",
    [string]$NextActionsOutputPath = ""
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

function Add-WorkflowRunGate($gates, $workflowName, $latestRun, $currentHeadSha, $requireCurrentHead) {
    if ($null -eq $latestRun) {
        Add-Gate $gates $workflowName "BLOCKED" "No recent run found." "Run the workflow manually from GitHub Actions before release."
        return
    }

    if ($latestRun.status -eq "completed" -and $latestRun.conclusion -eq "success") {
        $runHeadSha = [string]$latestRun.headSha
        if ($requireCurrentHead -and -not [string]::IsNullOrWhiteSpace($currentHeadSha) -and -not [string]::IsNullOrWhiteSpace($runHeadSha) -and $runHeadSha -ne $currentHeadSha) {
            Add-Gate $gates $workflowName "WARN" "Latest run succeeded for $runHeadSha, but current HEAD is $currentHeadSha." "Run the manual workflow_dispatch workflow for $workflowName before upload or App Review."
            return
        }

        Add-Gate $gates $workflowName "OK" "Latest run succeeded: $($latestRun.url)"
        return
    }

    Add-Gate $gates $workflowName "BLOCKED" "Latest run status=$($latestRun.status), conclusion=$($latestRun.conclusion)." "Open $($latestRun.url) and fix before release."
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

function Add-GitHubAuthGate($gates, $ghPath) {
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $authOutput = & $ghPath auth status 2>&1
    $authExitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousErrorActionPreference
    if ($authExitCode -eq 0) {
        Add-Gate $gates "GitHub CLI authentication" "OK" "GitHub CLI is authenticated."
        return
    }

    $apiWorks = $false
    try {
        $null = Invoke-GhJson $ghPath @("api", "user") "Could not verify GitHub API authentication."
        $apiWorks = $true
    } catch {
        $apiWorks = $false
    }

    if ($apiWorks) {
        Write-Host $authOutput
        Add-Gate $gates "GitHub CLI authentication" "WARN" "gh auth status reported an invalid session, but GitHub API requests still work." "Run gh auth refresh -h github.com after this release pass to clean up the local keyring token."
        return
    }

    Write-Host $authOutput
    Add-Gate $gates "GitHub CLI authentication" "BLOCKED" "gh auth status reports an invalid or missing GitHub session." "Run gh auth refresh -h github.com or gh auth login before setting secrets, updating issues, or triggering release workflows."
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

function Test-SubmissionPacket($gates, $submissionPacketDirectory, $explicitPath) {
    $submissionPacketPath = Resolve-ArtifactPath $submissionPacketDirectory "SnapTableReminder-AppStoreSubmissionPacket"
    Write-Host "submissionPacket=$submissionPacketPath"

    if (-not (Test-Path $submissionPacketPath)) {
        if ($explicitPath) {
            Add-Gate $gates "App Store submission packet" "BLOCKED" "Submission packet folder is missing: $submissionPacketPath" "Run scripts/build-app-store-submission-packet.ps1 -OutputDirectory `"$submissionPacketPath`"."
        } else {
            Add-Gate $gates "App Store submission packet" "WARN" "Default submission packet folder is missing: $submissionPacketPath" "Run scripts/build-app-store-submission-packet.ps1 after archiving Release Readiness screenshots."
        }
        return
    }

    $privatePatterns = @(
        "*.p8",
        "*.p12",
        "*.mobileprovision",
        "*.ipa",
        "release-secrets.private.json",
        "review-contact.private.json",
        "account-private-status.md",
        "dsa-private-evidence.md"
    )
    foreach ($privatePattern in $privatePatterns) {
        $privateMatch = Get-ChildItem -LiteralPath $submissionPacketPath -Recurse -Force -File -Filter $privatePattern -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($null -ne $privateMatch) {
            Add-Gate $gates "App Store submission packet" "BLOCKED" "Private Apple file found in public submission packet: $($privateMatch.FullName)" "Remove private Apple files and rebuild the packet with scripts/build-app-store-submission-packet.ps1."
            return
        }
    }

    $requiredSubmissionPaths = @(
        "SUBMISSION-PACKET-README.md",
        "app-store-submission-packet.json",
        "01-app-store-connect-entry-pack\app-store-connect-entry-pack.json",
        "02-fastlane-screenshots\en-US\01-Capture.png",
        "02-fastlane-screenshots\en-US\02-Records.png",
        "02-fastlane-screenshots\en-US\03-Dashboard.png",
        "02-fastlane-screenshots\en-US\04-Settings.png",
        "04-release-readiness-evidence\release-readiness-artifacts-summary.md",
        "04-release-readiness-evidence\release-readiness-artifacts.json"
    )
    $missingSubmissionPaths = @()
    foreach ($requiredSubmissionPath in $requiredSubmissionPaths) {
        if (-not (Test-Path (Join-Path $submissionPacketPath $requiredSubmissionPath))) {
            $missingSubmissionPaths += $requiredSubmissionPath
        }
    }
    if ($missingSubmissionPaths.Count -gt 0) {
        Add-Gate $gates "App Store submission packet" "BLOCKED" "Missing files: $($missingSubmissionPaths -join ', ')." "Rebuild the packet with scripts/build-app-store-submission-packet.ps1."
        return
    }

    $rawScreenshotCount = @(Get-ChildItem -LiteralPath (Join-Path $submissionPacketPath "03-raw-screenshots") -Recurse -File -Filter *.png -ErrorAction SilentlyContinue).Count
    if ($rawScreenshotCount -ne 4) {
        Add-Gate $gates "App Store submission packet" "BLOCKED" "Expected 4 raw screenshots, found $rawScreenshotCount." "Rebuild the packet from a verified Release Readiness artifact archive."
        return
    }

    try {
        $submissionPacket = Get-Content (Join-Path $submissionPacketPath "app-store-submission-packet.json") -Raw | ConvertFrom-Json
        if ($submissionPacket.bundleId -ne "com.snaptable.reminder") {
            Add-Gate $gates "App Store submission packet" "BLOCKED" "Submission packet bundle id is $($submissionPacket.bundleId)." "Rebuild the packet from the current App Store Connect entry pack."
            return
        }
        if ([int]$submissionPacket.fastlaneScreenshotCount -ne 4 -or [int]$submissionPacket.rawScreenshotCount -ne 4) {
            Add-Gate $gates "App Store submission packet" "BLOCKED" "Submission packet screenshot counts are Fastlane=$($submissionPacket.fastlaneScreenshotCount), raw=$($submissionPacket.rawScreenshotCount)." "Rebuild the packet from a verified Release Readiness artifact archive."
            return
        }
        if ([string]::IsNullOrWhiteSpace([string]$submissionPacket.privacyPolicyUrl) -or [string]::IsNullOrWhiteSpace([string]$submissionPacket.supportUrl)) {
            Add-Gate $gates "App Store submission packet" "BLOCKED" "Submission packet is missing hosted privacy/support URLs." "Regenerate the entry pack and rebuild the submission packet."
            return
        }
    } catch {
        Add-Gate $gates "App Store submission packet" "BLOCKED" "app-store-submission-packet.json is invalid." "Rebuild the packet with scripts/build-app-store-submission-packet.ps1."
        return
    }

    $readme = Get-Content (Join-Path $submissionPacketPath "SUBMISSION-PACKET-README.md") -Raw
    if ($readme -match '[\x00-\x08\x0B\x0C\x0E-\x1F]') {
        Add-Gate $gates "App Store submission packet" "BLOCKED" "Submission packet README contains control characters." "Rebuild the packet with scripts/build-app-store-submission-packet.ps1."
        return
    }

    Add-Gate $gates "App Store submission packet" "OK" "Public submission packet is present with 4 Fastlane screenshots and 4 raw screenshots at $submissionPacketPath."
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

function Write-AppleReleaseNextActions($gates, $entryPackDirectory, $submissionPacketDirectory, $materialsDirectory, $nextActionsOutputPath) {
    $nextActionsScriptPath = "scripts\apple-release-next-actions.ps1"
    if (-not (Test-Path $nextActionsScriptPath)) {
        Add-Gate $gates "Apple release next actions" "WARN" "Next-actions helper is missing." "Restore scripts/apple-release-next-actions.ps1 so release blockers produce a 0-basics checklist."
        return
    }

    $entryPackPath = Resolve-ArtifactPath $entryPackDirectory "SnapTableReminder-AppStoreConnect-EntryPack"
    $submissionPacketPath = Resolve-ArtifactPath $submissionPacketDirectory "SnapTableReminder-AppStoreSubmissionPacket"
    $materialsPath = Resolve-ArtifactPath $materialsDirectory "SnapTableReminder-Apple-Materials"
    $outputPath = Resolve-ArtifactPath $nextActionsOutputPath "SnapTableReminder-Apple-Next-Actions.md"

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $nextActionOutput = powershell -NoProfile -ExecutionPolicy Bypass -File $nextActionsScriptPath -EntryPackDirectory $entryPackPath -SubmissionPacketDirectory $submissionPacketPath -MaterialsDirectory $materialsPath -OutputPath $outputPath 2>&1 | Out-String
        $nextActionExitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    if ($nextActionExitCode -ne 0) {
        Add-Gate $gates "Apple release next actions" "WARN" "Could not write next-actions packet." "Run scripts/apple-release-next-actions.ps1 directly and fix the reported error."
        if ($nextActionOutput) {
            Write-Host $nextActionOutput.Trim()
        }
        return
    }

    Add-Gate $gates "Apple release next actions" "OK" "Wrote the next Apple release action packet to $outputPath." "Open $outputPath and follow the first unchecked action."
}

if ($LoadFunctionsOnly) {
    return
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
$currentHeadSha = (git rev-parse HEAD).Trim()
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
Test-SubmissionPacket $gates $SubmissionPacketDirectory (-not [string]::IsNullOrWhiteSpace($SubmissionPacketDirectory))
$validMaterialsPath = Test-Materials $gates $MaterialsDirectory (-not [string]::IsNullOrWhiteSpace($MaterialsDirectory))
if (-not [string]::IsNullOrWhiteSpace($validMaterialsPath)) {
    Test-AppStoreConnectSetupEvidence $gates $validMaterialsPath
    Test-ReleaseEvidence $gates $validMaterialsPath
}
Write-AppleReleaseNextActions $gates $EntryPackDirectory $SubmissionPacketDirectory $MaterialsDirectory $NextActionsOutputPath

if ($LocalOnly) {
    Complete-Doctor $gates
}

$ghPath = Resolve-GitHubCli

Write-Section "GitHub"
Add-GitHubAuthGate $gates $ghPath

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
            $requireCurrentHead = @("iOS CI", "Release Readiness") -contains $workflowName
            Add-WorkflowRunGate $gates $workflowName $latestRun $currentHeadSha $requireCurrentHead
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
    Add-Gate $gates "Build uploaded and submitted" "BLOCKED" "No App Store Connect evidence is available in this workspace." "After secrets exist and you intentionally choose to spend Actions minutes, run scripts/github-run-app-store-release.ps1 -ConfirmUseActionsMinutes YES -Wait, then scripts/github-submit-app-review.ps1 -ConfirmSubmitForReview YES -ConfirmUseActionsMinutes YES -Wait."
}

Complete-Doctor $gates
