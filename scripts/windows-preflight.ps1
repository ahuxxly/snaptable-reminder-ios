$ErrorActionPreference = "Stop"

function Write-Section($title) {
    Write-Host ""
    Write-Host "== $title =="
}

function Read-PngMetadata($path) {
    $bytes = [System.IO.File]::ReadAllBytes($path)
    if ($bytes.Length -lt 33) {
        throw "PNG file is too small: $path"
    }
    $pngSignature = @(137, 80, 78, 71, 13, 10, 26, 10)
    for ($index = 0; $index -lt $pngSignature.Count; $index++) {
        if ($bytes[$index] -ne $pngSignature[$index]) {
            throw "File is not a PNG: $path"
        }
    }
    $width = [System.BitConverter]::ToUInt32(([byte[]]@($bytes[19], $bytes[18], $bytes[17], $bytes[16])), 0)
    $height = [System.BitConverter]::ToUInt32(([byte[]]@($bytes[23], $bytes[22], $bytes[21], $bytes[20])), 0)
    $colorType = $bytes[25]

    [pscustomobject]@{
        Width = [int]$width
        Height = [int]$height
        ColorType = [int]$colorType
    }
}

Write-Section "Git status"
$gitStatus = git status --short
if ($gitStatus) {
    Write-Host $gitStatus
    throw "Working tree is not clean."
}
Write-Host "clean"

Write-Section "Marker scan"
$markerTerms = @("TO" + "DO", "TB" + "D", "PLACE" + "HOLDER", "example" + "\.com", "YOU" + "R_", "your" + "-domain")
$markerPattern = $markerTerms -join "|"
$markerOutput = rg $markerPattern . 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host $markerOutput
    throw "Unfinished marker text found."
}
if ($LASTEXITCODE -gt 1) {
    throw "Marker scan failed."
}
Write-Host "no unfinished markers"

Write-Section "Encoding damage scan"
$encodingOutput = @()
$mojibakeChars = @([char]0xFFFD, [char]0x00C3, [char]0x00C2)
foreach ($char in $mojibakeChars) {
    $scan = rg --fixed-strings ([string]$char) SnapTableReminder docs site README.md project.yml scripts .github fastlane Gemfile 2>$null
    if ($LASTEXITCODE -eq 0) {
        $encodingOutput += $scan
    } elseif ($LASTEXITCODE -gt 1) {
        throw "Encoding scan failed."
    }
}
if ($encodingOutput.Count -gt 0) {
    Write-Host ($encodingOutput -join [Environment]::NewLine)
    throw "Potential mojibake text found."
}
Write-Host "no common mojibake markers"

Write-Section "Shell script line endings"
$shellScripts = Get-ChildItem scripts -Filter *.sh
foreach ($script in $shellScripts) {
    $bytes = [System.IO.File]::ReadAllBytes($script.FullName)
    for ($index = 0; $index -lt ($bytes.Length - 1); $index++) {
        if ($bytes[$index] -eq 13 -and $bytes[$index + 1] -eq 10) {
            throw "Shell script should use LF line endings: $($script.Name)"
        }
    }
}
Write-Host "shell scripts use LF line endings"

Write-Section "Resource parsing"
Get-Content "SnapTableReminder\Resources\Assets.xcassets\Contents.json" | ConvertFrom-Json | Out-Null
$appIconContents = Get-Content "SnapTableReminder\Resources\Assets.xcassets\AppIcon.appiconset\Contents.json" | ConvertFrom-Json
Get-Content "SnapTableReminder\Resources\Localizable.xcstrings" | ConvertFrom-Json | Out-Null
$infoPlist = [xml](Get-Content "SnapTableReminder\Resources\Info.plist" -Raw)
$privacyManifest = [xml](Get-Content "SnapTableReminder\Resources\PrivacyInfo.xcprivacy" -Raw)
Write-Host "resources parse"

Write-Section "Release configuration consistency"
$projectText = Get-Content "project.yml" -Raw
$appfileText = Get-Content "fastlane\Appfile" -Raw
$fastfileText = Get-Content "fastlane\Fastfile" -Raw
$gitignoreText = Get-Content ".gitignore" -Raw
$launchRunbookText = Get-Content "docs\app-store\launch-runbook.md" -Raw
$storeFieldsPath = "docs\app-store\app-store-fields.json"
if (-not (Test-Path $storeFieldsPath)) {
    throw "Missing App Store fields file: $storeFieldsPath"
}
$storeFields = Get-Content $storeFieldsPath -Raw | ConvertFrom-Json
$bundleMatch = [regex]::Match($projectText, "PRODUCT_BUNDLE_IDENTIFIER:\s*([A-Za-z0-9\.\-]+)")
if (-not $bundleMatch.Success) {
    throw "PRODUCT_BUNDLE_IDENTIFIER was not found in project.yml."
}
$bundleId = $bundleMatch.Groups[1].Value
if ($storeFields.app.bundleId -ne $bundleId) {
    throw "App Store fields bundle id '$($storeFields.app.bundleId)' does not match project bundle id $bundleId."
}
if (-not $appfileText.Contains("app_identifier(`"$bundleId`")")) {
    throw "fastlane/Appfile does not match project bundle id $bundleId."
}
if (-not $launchRunbookText.Contains($bundleId)) {
    throw "Launch runbook does not mention project bundle id $bundleId."
}
if (-not $fastfileText.Contains("scheme: `"SnapTableReminder`"") -and -not $fastfileText.Contains("-scheme SnapTableReminder")) {
    throw "fastlane/Fastfile does not reference the SnapTableReminder scheme."
}
if (-not $projectText.Contains("TARGETED_DEVICE_FAMILY: `"1`"")) {
    throw "project.yml should target iPhone only for version 1."
}
if (-not $projectText.Contains("MARKETING_VERSION: `"1.0`"")) {
    throw "project.yml should use MARKETING_VERSION 1.0 for the first App Store release."
}
if (-not $projectText.Contains("CURRENT_PROJECT_VERSION: `"1`"")) {
    throw "project.yml should use build number 1 for the first App Store release."
}
if (-not $projectText.Contains("SnapTableReminderUITests")) {
    throw "project.yml should include the screenshot UI test target."
}
if (-not $projectText.Contains("SnapTableReminderScreenshots")) {
    throw "project.yml should include the screenshot scheme."
}
if (-not $projectText.Contains("GENERATE_INFOPLIST_FILE: YES")) {
    throw "project.yml should generate Info.plist files for test bundle targets."
}
if (-not $projectText.Contains("TEST_TARGET_NAME: SnapTableReminder")) {
    throw "Screenshot UI test target should point at SnapTableReminder."
}
if (-not $gitignoreText.Contains("*.p12") -or -not $gitignoreText.Contains("*.mobileprovision")) {
    throw ".gitignore should exclude Apple signing certificates and provisioning profiles."
}
Write-Host "bundle id and release config align"

Write-Section "App Store fields"
if ($storeFields.schemaVersion -ne 1) {
    throw "App Store fields schemaVersion must be 1."
}
if ($storeFields.app.name -ne "SnapTable Reminder") {
    throw "App Store app name should be SnapTable Reminder."
}
if ($storeFields.app.displayName -ne "SnapTable") {
    throw "App display name should be SnapTable."
}
if ($storeFields.app.primaryLanguage -ne "en-US") {
    throw "Primary language should be en-US for version 1."
}
if ($storeFields.app.category -ne "Productivity") {
    throw "Primary category should be Productivity."
}
if ($storeFields.pricing.model -ne "paidUpfront") {
    throw "Version 1 pricing model should be paidUpfront."
}
if ($storeFields.pricing.startingPrice.currency -ne "USD" -or [decimal]$storeFields.pricing.startingPrice.amount -ne [decimal]1.99) {
    throw "Version 1 starting price should be USD 1.99."
}
if ($storeFields.availability.distributionMethod -ne "Public") {
    throw "Distribution method should be Public."
}
if ($storeFields.availability.strategy -ne "selectedCountriesOrRegions") {
    throw "Availability strategy should be selectedCountriesOrRegions."
}
$excludedRegions = @($storeFields.availability.excludeCountriesOrRegions)
if (-not ($excludedRegions -contains "China mainland")) {
    throw "China mainland must be excluded for version 1 availability."
}
$euDsa = $storeFields.compliance.euDigitalServicesAct
if ($null -eq $euDsa) {
    throw "App Store fields should include EU Digital Services Act release planning."
}
if ($euDsa.euStorefrontsIncludedInV1 -ne $true) {
    throw "Version 1 should declare that EU storefronts are included unless intentionally excluded."
}
if ($euDsa.traderStatusDecisionRequired -ne $true) {
    throw "EU DSA trader status decision should be required before App Review submission."
}
if ([string]::IsNullOrWhiteSpace($euDsa.sourcePath) -or -not (Test-Path $euDsa.sourcePath)) {
    throw "EU DSA source document is missing: $($euDsa.sourcePath)"
}
$storePathFields = @(
    $storeFields.storeListing.descriptionPath,
    $storeFields.urls.privacyPolicyPath,
    $storeFields.urls.supportPath,
    $storeFields.review.notesPath,
    $storeFields.review.demoFlowPath,
    $euDsa.sourcePath
)
foreach ($pathField in $storePathFields) {
    if (-not (Test-Path $pathField)) {
        throw "App Store fields reference a missing path: $pathField"
    }
}
if ($storeFields.privacy.tracking -ne $false) {
    throw "Version 1 should not enable tracking."
}
if ($storeFields.privacy.thirdPartyAnalytics -ne $false) {
    throw "Version 1 should not use third-party analytics."
}
if ($storeFields.privacy.userAccount -ne $false) {
    throw "Version 1 should not require user accounts."
}
if ($storeFields.privacy.backendTransmission -ne $false) {
    throw "Version 1 should not transmit records to a backend."
}
if ($storeFields.privacy.cloudAiParsing -ne $false) {
    throw "Version 1 should not use cloud AI parsing."
}
if ($storeFields.compliance.usesOnlyStandardApplePlatformEncryption -ne $true) {
    throw "Export compliance should declare only standard Apple platform encryption for version 1."
}
if (-not $projectText.Contains("ITSAppUsesNonExemptEncryption: false")) {
    throw "project.yml should declare ITSAppUsesNonExemptEncryption false for version 1 export compliance."
}
if ($infoPlist.plist.dict.key -notcontains "ITSAppUsesNonExemptEncryption") {
    throw "Info.plist should declare ITSAppUsesNonExemptEncryption."
}
$nonExemptEncryptionValue = $null
for ($index = 0; $index -lt ($infoPlist.plist.dict.ChildNodes.Count - 1); $index++) {
    $node = $infoPlist.plist.dict.ChildNodes[$index]
    if ($node.Name -eq "key" -and $node.InnerText -eq "ITSAppUsesNonExemptEncryption") {
        $nonExemptEncryptionValue = $infoPlist.plist.dict.ChildNodes[$index + 1]
        break
    }
}
if ($null -eq $nonExemptEncryptionValue) {
    throw "Info.plist ITSAppUsesNonExemptEncryption value was not found."
}
if ($nonExemptEncryptionValue.Name -ne "false") {
    throw "Info.plist ITSAppUsesNonExemptEncryption should be false for version 1."
}
if ($storeFields.compliance.containsLegalMedicalTaxFinancialInvestmentAdvice -ne $false) {
    throw "Version 1 must not claim legal, medical, tax, financial, or investment advice."
}
if ($storeFields.compliance.targetsChildren -ne $false) {
    throw "Version 1 should not target children."
}
if ($storeFields.compliance.requiresReviewerAccount -ne $false -or $storeFields.review.testAccountRequired -ne $false) {
    throw "Version 1 should not require a reviewer account."
}
if ($storeFields.screenshots.requiredDevice -ne "6.9 inch iPhone") {
    throw "App Store screenshot device should be 6.9 inch iPhone."
}
Write-Host "metadata, pricing, privacy, compliance, and availability align"

Write-Section "Fastlane metadata"
$fastlaneMetadataFiles = @(
    "fastlane\metadata\primary_category.txt",
    "fastlane\metadata\en-US\name.txt",
    "fastlane\metadata\en-US\subtitle.txt",
    "fastlane\metadata\en-US\promotional_text.txt",
    "fastlane\metadata\en-US\description.txt",
    "fastlane\metadata\en-US\keywords.txt",
    "fastlane\metadata\en-US\release_notes.txt",
    "fastlane\metadata\review_information\notes.txt"
)
foreach ($metadataFile in $fastlaneMetadataFiles) {
    if (-not (Test-Path $metadataFile)) {
        throw "Missing Fastlane metadata file: $metadataFile"
    }
}
$fastlaneName = (Get-Content "fastlane\metadata\en-US\name.txt" -Raw).Trim()
$fastlaneSubtitle = (Get-Content "fastlane\metadata\en-US\subtitle.txt" -Raw).Trim()
$fastlanePromotionalText = (Get-Content "fastlane\metadata\en-US\promotional_text.txt" -Raw).Trim()
$fastlaneKeywords = (Get-Content "fastlane\metadata\en-US\keywords.txt" -Raw).Trim()
$fastlanePrimaryCategory = (Get-Content "fastlane\metadata\primary_category.txt" -Raw).Trim()
if ($fastlaneName -ne $storeFields.app.name) {
    throw "Fastlane metadata name does not match App Store fields."
}
if ($fastlaneSubtitle -ne $storeFields.storeListing.subtitle) {
    throw "Fastlane metadata subtitle does not match App Store fields."
}
if ($fastlanePromotionalText -ne $storeFields.storeListing.promotionalText) {
    throw "Fastlane metadata promotional text does not match App Store fields."
}
if ($fastlaneKeywords -ne (($storeFields.storeListing.keywords) -join ",")) {
    throw "Fastlane metadata keywords do not match App Store fields."
}
if ($fastlanePrimaryCategory -ne "PRODUCTIVITY") {
    throw "Fastlane primary category should be PRODUCTIVITY."
}
$optionalUrlFiles = @(
    "fastlane\metadata\en-US\privacy_url.txt",
    "fastlane\metadata\en-US\support_url.txt"
)
foreach ($urlFile in $optionalUrlFiles) {
    if (Test-Path $urlFile) {
        $urlValue = (Get-Content $urlFile -Raw).Trim()
        if ($urlValue -notmatch "^https://") {
            throw "Fastlane URL file must contain an https URL: $urlFile"
        }
    }
}
if (-not $fastfileText.Contains("lane :metadata")) {
    throw "fastlane/Fastfile should include the metadata lane."
}
if (-not $fastfileText.Contains("private_lane :validate_upload_environment")) {
    throw "fastlane/Fastfile should include a private upload environment validation lane."
}
if (-not $fastfileText.Contains("archive_build_options")) {
    throw "fastlane/Fastfile should centralize archive options for signing-aware builds."
}
if (-not $fastfileText.Contains("APPLE_PROVISIONING_PROFILE_SPECIFIER")) {
    throw "fastlane/Fastfile should support a CI provisioning profile specifier."
}
if (-not $fastfileText.Contains("CODE_SIGN_STYLE=Manual")) {
    throw "fastlane/Fastfile should support manual signing for CI TestFlight uploads."
}
if (-not $fastfileText.Contains("sh(`"bash scripts/mac-validate-upload-env.sh`")")) {
    throw "Fastlane upload environment validation should call scripts/mac-validate-upload-env.sh."
}
$requiredUploadValidationLanes = @("testflight", "metadata", "screenshots", "review_check")
foreach ($uploadValidationLane in $requiredUploadValidationLanes) {
    if ($fastfileText -notmatch "lane :$uploadValidationLane do\s+validate_upload_environment") {
        throw "Fastlane lane '$uploadValidationLane' should validate the upload environment before using App Store Connect."
    }
}
$requiredSubmitReviewTerms = @(
    "lane :submit_review",
    "validate_review_submission_environment",
    "CONFIRM_SUBMIT_FOR_REVIEW",
    "submit_for_review: true",
    "automatic_release: false",
    "skip_binary_upload: true",
    "skip_metadata: true",
    "skip_screenshots: true",
    "app_review_information",
    "export_compliance_uses_encryption"
)
foreach ($submitReviewTerm in $requiredSubmitReviewTerms) {
    if (-not $fastfileText.Contains($submitReviewTerm)) {
        throw "fastlane/Fastfile should include protected App Review submission term: $submitReviewTerm"
    }
}
Write-Host "Fastlane metadata files align"

Write-Section "App Store metadata limits"
powershell -ExecutionPolicy Bypass -File scripts\validate-app-store-metadata.ps1

Write-Section "Asset references"
$appIconDirectory = "SnapTableReminder\Resources\Assets.xcassets\AppIcon.appiconset"
$hasMarketingIcon = $false
foreach ($image in $appIconContents.images) {
    if ($image.filename) {
        $imagePath = Join-Path $appIconDirectory $image.filename
        if (-not (Test-Path $imagePath)) {
            throw "Missing app icon file referenced by asset catalog: $($image.filename)"
        }
        $pngMetadata = Read-PngMetadata $imagePath
        $sizePoints = [int](([string]$image.size -split "x")[0])
        $scale = [int](([string]$image.scale).Replace("x", ""))
        $expectedPixels = $sizePoints * $scale
        if ($pngMetadata.Width -ne $expectedPixels -or $pngMetadata.Height -ne $expectedPixels) {
            throw "App icon $($image.filename) should be ${expectedPixels}x${expectedPixels}px but is $($pngMetadata.Width)x$($pngMetadata.Height)."
        }
        if ($image.idiom -eq "ios-marketing" -and $expectedPixels -eq 1024) {
            $hasMarketingIcon = $true
        }
    }
}
if (-not $hasMarketingIcon) {
    throw "App icon asset catalog should include a 1024x1024 ios-marketing icon."
}
Write-Host "app icon references and dimensions valid"

Write-Section "Privacy manifest coverage"
$usesUserDefaults = rg "UserDefaults" SnapTableReminder 2>$null
if ($LASTEXITCODE -eq 0) {
    $privacyText = $privacyManifest.OuterXml
    if (-not $privacyText.Contains("NSPrivacyAccessedAPICategoryUserDefaults")) {
        throw "UserDefaults is used but PrivacyInfo.xcprivacy does not declare NSPrivacyAccessedAPICategoryUserDefaults."
    }
    if (-not $privacyText.Contains("CA92.1")) {
        throw "UserDefaults is used but PrivacyInfo.xcprivacy does not include reason CA92.1."
    }
    Write-Host "UserDefaults required reason declared"
} elseif ($LASTEXITCODE -gt 1) {
    throw "UserDefaults scan failed."
} else {
    Write-Host "no UserDefaults usage found"
}

Write-Section "Privacy source scan"
$forbiddenPrivacySourcePatterns = @(
    "\bURLSession\b",
    "\bURLRequest\b",
    "\bURLSessionConfiguration\b",
    "\bimport\s+Network\b",
    "\bNWPathMonitor\b",
    "\bimport\s+WebKit\b",
    "\bWKWebView\b",
    "\bimport\s+Firebase\b",
    "\bFirebaseApp\b",
    "\bFirebaseAnalytics\b",
    "\bAnalytics\.logEvent\b",
    "\bCrashlytics\b",
    "\bSentrySDK\b",
    "\bAmplitude\b",
    "\bMixpanel\b",
    "\bPostHog\b",
    "\bDatadog\b",
    "\bTelemetryClient\b",
    "\bOpenAI\b"
)
$forbiddenPrivacySourcePattern = $forbiddenPrivacySourcePatterns -join "|"
$privacySourceScan = rg $forbiddenPrivacySourcePattern SnapTableReminder SnapTableReminderTests SnapTableReminderUITests project.yml Gemfile fastlane 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host $privacySourceScan
    throw "Source contains networking, analytics, crash reporting, or cloud-AI code that conflicts with the version 1 privacy promise."
}
if ($LASTEXITCODE -gt 1) {
    throw "Privacy source scan failed."
}
Write-Host "no network, analytics, crash reporting, or cloud-AI code found"

Write-Section "Test coverage files"
$requiredTestFiles = @(
    "SnapTableReminderTests\DocumentParserTests.swift",
    "SnapTableReminderTests\CSVExporterTests.swift",
    "SnapTableReminderTests\RecordDateLogicTests.swift",
    "SnapTableReminderTests\AppStateSettingsTests.swift",
    "SnapTableReminderTests\ReminderDatePolicyTests.swift",
    "SnapTableReminderTests\DemoDataTests.swift",
    "SnapTableReminderUITests\AppStoreScreenshotUITests.swift"
)
foreach ($testFile in $requiredTestFiles) {
    if (-not (Test-Path $testFile)) {
        throw "Missing required test file: $testFile"
    }
}
Write-Host "required test files present"

Write-Section "Release docs"
$requiredReleaseDocs = @(
    "docs\app-store\account-setup.md",
    "docs\app-store\app-store-fields.json",
    "docs\app-store\current-release-status.md",
    "docs\app-store\launch-runbook.md",
    "docs\app-store\metadata.md",
    "docs\app-store\privacy-questionnaire.md",
    "docs\app-store\review-contact.md",
    "docs\app-store\eu-dsa-trader.md",
    "docs\app-store\monetization-plan.md"
)
foreach ($releaseDoc in $requiredReleaseDocs) {
    if (-not (Test-Path $releaseDoc)) {
        throw "Missing required release document: $releaseDoc"
    }
}
Write-Host "required release docs present"

Write-Section "EU DSA release safeguards"
$euDsaDocText = Get-Content "docs\app-store\eu-dsa-trader.md" -Raw
$requiredEuDsaDocTerms = @(
    "Digital Services Act",
    "trader status",
    "EU storefronts",
    "Do not commit real contact details",
    "Account Holder or Admin",
    "not legal advice"
)
foreach ($euDsaDocTerm in $requiredEuDsaDocTerms) {
    if (-not $euDsaDocText.Contains($euDsaDocTerm)) {
        throw "EU DSA document should mention: $euDsaDocTerm"
    }
}
foreach ($releaseDocPath in @(
    "docs\app-store\account-setup.md",
    "docs\app-store\app-store-checklist.md",
    "docs\app-store\current-release-status.md",
    "docs\app-store\launch-runbook.md",
    "docs\app-store\monetization-plan.md",
    "docs\app-store\fastlane-release.md"
)) {
    $releaseDocText = Get-Content $releaseDocPath -Raw
    if (-not $releaseDocText.Contains("eu-dsa-trader.md")) {
        throw "$releaseDocPath should link to the EU DSA trader status checklist."
    }
}
Write-Host "EU DSA release safeguards present"

Write-Section "App Review contact safeguards"
if (-not (Test-Path "scripts\mac-validate-review-contact-env.sh")) {
    throw "Missing Mac App Review contact environment validation script."
}
$reviewContactText = Get-Content "scripts\mac-validate-review-contact-env.sh" -Raw
$requiredReviewContactVars = @(
    "APP_REVIEW_FIRST_NAME",
    "APP_REVIEW_LAST_NAME",
    "APP_REVIEW_EMAIL",
    "APP_REVIEW_PHONE"
)
foreach ($reviewContactVar in $requiredReviewContactVars) {
    if (-not $reviewContactText.Contains($reviewContactVar)) {
        throw "Review contact validation script should check $reviewContactVar."
    }
}
if (-not $reviewContactText.Contains("[^@[:space:]]+@")) {
    throw "Review contact validation script should validate email shape."
}
if (-not $reviewContactText.Contains("review-reachable phone number")) {
    throw "Review contact validation script should validate phone shape."
}
$reviewContactDocText = Get-Content "docs\app-store\review-contact.md" -Raw
if (-not $reviewContactDocText.Contains("Do not commit personal contact details")) {
    throw "Review contact document should warn against committing personal details."
}
if (-not $reviewContactDocText.Contains("scripts/mac-validate-review-contact-env.sh")) {
    throw "Review contact document should mention the Mac validation script."
}
if (-not $launchRunbookText.Contains("scripts/mac-validate-review-contact-env.sh")) {
    throw "Launch runbook should mention review contact validation."
}
Write-Host "App Review contact safeguards present"

Write-Section "GitHub publishing helpers"
if (-not (Test-Path "scripts\github-publish.ps1")) {
    throw "Missing GitHub publish script."
}
if (-not (Test-Path "scripts\github-login-and-publish.ps1")) {
    throw "Missing GitHub login and publish helper script."
}
if (-not (Test-Path "scripts\github-set-apple-secrets.ps1")) {
    throw "Missing GitHub Apple secret helper script."
}
if (-not (Test-Path "scripts\github-run-app-store-release.ps1")) {
    throw "Missing GitHub App Store release runner script."
}
if (-not (Test-Path "scripts\github-submit-app-review.ps1")) {
    throw "Missing GitHub App Review submit helper script."
}
if (-not (Test-Path "scripts\release-doctor.ps1")) {
    throw "Missing release doctor script."
}
if (-not (Test-Path "scripts\sync-release-issue.ps1")) {
    throw "Missing release issue sync script."
}
if (-not (Test-Path "scripts\write-site-support-links.ps1")) {
    throw "Missing site support link writer script."
}
$githubLoginPublishText = Get-Content "scripts\github-login-and-publish.ps1" -Raw
if (-not $githubLoginPublishText.Contains("auth login")) {
    throw "GitHub login helper should run gh auth login."
}
if (-not $githubLoginPublishText.Contains("github-publish.ps1")) {
    throw "GitHub login helper should call github-publish.ps1."
}
if (-not $launchRunbookText.Contains("github-login-and-publish.ps1")) {
    throw "Launch runbook should mention the GitHub login and publish helper."
}
$githubPublishText = Get-Content "scripts\github-publish.ps1" -Raw
if (-not $githubPublishText.Contains("write-site-support-links.ps1")) {
    throw "GitHub publish script should write public support links after repo creation."
}
if (-not $githubPublishText.Contains("write-fastlane-store-urls.ps1")) {
    throw "GitHub publish script should write Fastlane store URLs after repo creation."
}
if (-not $githubPublishText.Contains("--enable-issues")) {
    throw "GitHub publish script should enable Issues for the public support link."
}
if (-not $githubPublishText.Contains("label create support")) {
    throw "GitHub publish script should create the support issue label."
}
if (-not $githubPublishText.Contains("docs: add public support request links")) {
    throw "GitHub publish script should commit generated release URL updates."
}
$githubAppleSecretsText = Get-Content "scripts\github-set-apple-secrets.ps1" -Raw
$requiredGitHubUploadSecretNames = @(
    "APP_STORE_CONNECT_USERNAME",
    "APPLE_DEVELOPER_TEAM_ID",
    "APP_STORE_CONNECT_API_KEY_ID",
    "APP_STORE_CONNECT_API_ISSUER_ID",
    "APP_STORE_CONNECT_API_PRIVATE_KEY"
)
$requiredGitHubSigningSecretNames = @(
    "APPLE_DISTRIBUTION_CERTIFICATE_BASE64",
    "APPLE_DISTRIBUTION_CERTIFICATE_PASSWORD",
    "APPLE_APP_STORE_PROFILE_BASE64",
    "APPLE_CODESIGN_KEYCHAIN_PASSWORD"
)
$requiredGitHubReviewSecretNames = @(
    "APP_REVIEW_FIRST_NAME",
    "APP_REVIEW_LAST_NAME",
    "APP_REVIEW_EMAIL",
    "APP_REVIEW_PHONE"
)
$requiredGitHubAppleSecretNames = $requiredGitHubUploadSecretNames + $requiredGitHubSigningSecretNames + $requiredGitHubReviewSecretNames
foreach ($githubAppleSecretName in $requiredGitHubAppleSecretNames) {
    if (-not $githubAppleSecretsText.Contains($githubAppleSecretName)) {
        throw "GitHub Apple secret helper should set $githubAppleSecretName."
    }
}
if (-not $githubAppleSecretsText.Contains("secret set")) {
    throw "GitHub Apple secret helper should use GitHub CLI secrets."
}
if (-not $githubAppleSecretsText.Contains("Assert-FileOutsideRepository")) {
    throw "GitHub Apple secret helper should reject Apple files stored inside the repository."
}
if (-not $githubAppleSecretsText.Contains("RedirectStandardInput")) {
    throw "GitHub Apple secret helper should pass secret values through exact standard input."
}
if (-not $githubAppleSecretsText.Contains("UploadOnly") -or -not $githubAppleSecretsText.Contains("SigningOnly") -or -not $githubAppleSecretsText.Contains("ReviewOnly")) {
    throw "GitHub Apple secret helper should support upload-only, signing-only, and review-only modes."
}
if (-not $githubAppleSecretsText.Contains("DryRun")) {
    throw "GitHub Apple secret helper should support a dry-run validation mode."
}
$githubAppStoreReleaseText = Get-Content "scripts\github-run-app-store-release.ps1" -Raw
foreach ($githubAppleSecretName in ($requiredGitHubUploadSecretNames + $requiredGitHubSigningSecretNames)) {
    if (-not $githubAppStoreReleaseText.Contains($githubAppleSecretName)) {
        throw "GitHub App Store release runner should check $githubAppleSecretName."
    }
}
if (-not $githubAppStoreReleaseText.Contains("app-store-connect-upload.yml")) {
    throw "GitHub App Store release runner should trigger App Store Connect upload."
}
if (-not $githubAppStoreReleaseText.Contains("testflight-upload.yml")) {
    throw "GitHub App Store release runner should trigger TestFlight upload."
}
if (-not $githubAppStoreReleaseText.Contains("StatusOnly") -or -not $githubAppStoreReleaseText.Contains("DryRun")) {
    throw "GitHub App Store release runner should support status-only and dry-run modes."
}
if (-not $githubAppStoreReleaseText.Contains("SkipTestFlight")) {
    throw "GitHub App Store release runner should allow metadata/screenshot upload without TestFlight."
}
if (-not $githubAppStoreReleaseText.Contains("run watch")) {
    throw "GitHub App Store release runner should optionally wait for workflow completion."
}
if (-not $githubAppStoreReleaseText.Contains("Could not list recent workflow runs")) {
    throw "GitHub App Store release runner should fail clearly if recent workflow run listing fails."
}
$githubAppReviewSubmitText = Get-Content "scripts\github-submit-app-review.ps1" -Raw
foreach ($reviewSubmitSecretName in ($requiredGitHubUploadSecretNames + $requiredGitHubReviewSecretNames)) {
    if (-not $githubAppReviewSubmitText.Contains($reviewSubmitSecretName)) {
        throw "GitHub App Review submit helper should check $reviewSubmitSecretName."
    }
}
if (-not $githubAppReviewSubmitText.Contains("ConfirmSubmitForReview")) {
    throw "GitHub App Review submit helper should require explicit confirmation."
}
if (-not $githubAppReviewSubmitText.Contains("app-review-submit.yml")) {
    throw "GitHub App Review submit helper should trigger the App Review workflow."
}
if (-not $githubAppReviewSubmitText.Contains("Could not list recent workflow runs")) {
    throw "GitHub App Review submit helper should fail clearly if recent workflow run listing fails."
}
$releaseDoctorText = Get-Content "scripts\release-doctor.ps1" -Raw
foreach ($releaseDoctorTerm in @(
    "RunPreflight",
    "App Store Connect upload secrets",
    "Apple signing secrets",
    "App Review contact secrets",
    "EU DSA trader status",
    "scripts/github-run-app-store-release.ps1 -Wait",
    "scripts/github-submit-app-review.ps1 -ConfirmSubmitForReview YES -Wait"
)) {
    if (-not $releaseDoctorText.Contains($releaseDoctorTerm)) {
        throw "Release doctor should include: $releaseDoctorTerm"
    }
}
if ($releaseDoctorText.Contains("workflow run ")) {
    throw "Release doctor should not trigger GitHub workflows."
}
if (-not $launchRunbookText.Contains("scripts/release-doctor.ps1")) {
    throw "Launch runbook should mention the release doctor."
}
if (-not (Get-Content "docs\app-store\current-release-status.md" -Raw).Contains("scripts/release-doctor.ps1")) {
    throw "Current release status should mention the release doctor."
}
$releaseIssueSyncText = Get-Content "scripts\sync-release-issue.ps1" -Raw
foreach ($releaseIssueSyncTerm in @(
    "Do not paste secrets",
    "docs/app-store/eu-dsa-trader.md",
    "scripts/release-doctor.ps1 -RunPreflight",
    "scripts/github-set-apple-secrets.ps1 -UploadOnly",
    "scripts/github-set-apple-secrets.ps1 -SigningOnly",
    "scripts/github-set-apple-secrets.ps1 -ReviewOnly",
    "scripts/github-run-app-store-release.ps1 -Wait",
    "scripts/github-submit-app-review.ps1 -ConfirmSubmitForReview YES -Wait"
)) {
    if (-not $releaseIssueSyncText.Contains($releaseIssueSyncTerm)) {
        throw "Release issue sync should include: $releaseIssueSyncTerm"
    }
}
if (-not $launchRunbookText.Contains("scripts/sync-release-issue.ps1")) {
    throw "Launch runbook should mention the release issue sync script."
}
if (-not (Get-Content "docs\app-store\current-release-status.md" -Raw).Contains("scripts/sync-release-issue.ps1")) {
    throw "Current release status should mention the release issue sync script."
}
$appReviewWorkflowPath = ".github\workflows\app-review-submit.yml"
if (-not (Test-Path $appReviewWorkflowPath)) {
    throw "Missing App Review submit workflow."
}
$appReviewWorkflowText = Get-Content $appReviewWorkflowPath -Raw
foreach ($reviewWorkflowSecretName in ($requiredGitHubUploadSecretNames + $requiredGitHubReviewSecretNames)) {
    if (-not $appReviewWorkflowText.Contains($reviewWorkflowSecretName)) {
        throw "App Review submit workflow should reference $reviewWorkflowSecretName."
    }
}
$requiredReviewWorkflowTerms = @(
    "workflow_dispatch",
    "confirm_submit_for_review",
    "CONFIRM_SUBMIT_FOR_REVIEW",
    "bundle exec fastlane ios submit_review",
    "scripts/mac-validate-review-contact-env.sh",
    "timeout-minutes: 30"
)
foreach ($reviewWorkflowTerm in $requiredReviewWorkflowTerms) {
    if (-not $appReviewWorkflowText.Contains($reviewWorkflowTerm)) {
        throw "App Review submit workflow should include $reviewWorkflowTerm."
    }
}
if (-not $launchRunbookText.Contains("github-submit-app-review.ps1")) {
    throw "Launch runbook should mention the GitHub App Review submit helper."
}
if (-not (Test-Path ".github\ISSUE_TEMPLATE\support.yml")) {
    throw "Missing GitHub support issue template for public support requests."
}
$supportIssueTemplateText = Get-Content ".github\ISSUE_TEMPLATE\support.yml" -Raw
if (-not $supportIssueTemplateText.Contains("Do not include private screenshots")) {
    throw "Support issue template should warn users not to include private documents."
}
if (-not $supportIssueTemplateText.Contains("privacy_confirmation")) {
    throw "Support issue template should require privacy confirmation."
}
$siteSupportLinkWriterText = Get-Content "scripts\write-site-support-links.ps1" -Raw
if (-not $siteSupportLinkWriterText.Contains("https://github.com/")) {
    throw "Site support link writer should generate a GitHub Issues URL."
}
if (-not $siteSupportLinkWriterText.Contains("support.html") -or -not $siteSupportLinkWriterText.Contains("privacy.html")) {
    throw "Site support link writer should update support and privacy pages."
}
$tempSupportSiteRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("snaptable-support-preflight-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempSupportSiteRoot | Out-Null
try {
    Copy-Item -Recurse -Path "site" -Destination (Join-Path $tempSupportSiteRoot "site")
    Push-Location $tempSupportSiteRoot
    try {
        powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "write-site-support-links.ps1") -Owner "preflight-owner" -RepoName "snaptable-reminder-ios" | Out-Null
    } finally {
        Pop-Location
    }
    $expectedSupportUrl = "https://github.com/preflight-owner/snaptable-reminder-ios/issues"
    $tempSupportPath = Join-Path $tempSupportSiteRoot "site\support.html"
    $tempPrivacyPath = Join-Path $tempSupportSiteRoot "site\privacy.html"
    if (-not (Select-String -Path $tempSupportPath -SimpleMatch $expectedSupportUrl -Quiet)) {
        throw "Site support link writer did not update support.html in the preflight temp copy."
    }
    if (-not (Select-String -Path $tempPrivacyPath -SimpleMatch $expectedSupportUrl -Quiet)) {
        throw "Site support link writer did not update privacy.html in the preflight temp copy."
    }
} finally {
    $resolvedSupportTemp = [System.IO.Path]::GetFullPath($tempSupportSiteRoot)
    $resolvedTempBase = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
    if ($resolvedSupportTemp.StartsWith($resolvedTempBase, [System.StringComparison]::OrdinalIgnoreCase)) {
        Remove-Item -LiteralPath $resolvedSupportTemp -Recurse -Force
    }
}
$tempFastlaneUrlRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("snaptable-fastlane-url-preflight-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempFastlaneUrlRoot | Out-Null
try {
    Push-Location $tempFastlaneUrlRoot
    try {
        powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "write-fastlane-store-urls.ps1") -Owner "preflight-owner" -RepoName "snaptable-reminder-ios" | Out-Null
    } finally {
        Pop-Location
    }
    $tempPrivacyUrlPath = Join-Path $tempFastlaneUrlRoot "fastlane\metadata\en-US\privacy_url.txt"
    $tempSupportUrlPath = Join-Path $tempFastlaneUrlRoot "fastlane\metadata\en-US\support_url.txt"
    if ((Get-Content $tempPrivacyUrlPath -Raw).Trim() -ne "https://preflight-owner.github.io/snaptable-reminder-ios/privacy.html") {
        throw "Fastlane store URL writer did not write the expected privacy URL."
    }
    if ((Get-Content $tempSupportUrlPath -Raw).Trim() -ne "https://preflight-owner.github.io/snaptable-reminder-ios/support.html") {
        throw "Fastlane store URL writer did not write the expected support URL."
    }
} finally {
    $resolvedFastlaneUrlTemp = [System.IO.Path]::GetFullPath($tempFastlaneUrlRoot)
    $resolvedTempBase = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
    if ($resolvedFastlaneUrlTemp.StartsWith($resolvedTempBase, [System.StringComparison]::OrdinalIgnoreCase)) {
        Remove-Item -LiteralPath $resolvedFastlaneUrlTemp -Recurse -Force
    }
}
Write-Host "GitHub publishing helpers present"

Write-Section "Screenshot automation"
if (-not (Test-Path "scripts\mac-capture-screenshots.sh")) {
    throw "Missing Mac screenshot capture script."
}
if (-not (Test-Path "scripts\mac-release-readiness.sh")) {
    throw "Missing Mac release readiness script."
}
if (-not (Test-Path "scripts\mac-validate-upload-env.sh")) {
    throw "Missing Mac Fastlane upload environment validation script."
}
if (-not (Test-Path "scripts\mac-validate-signing-env.sh")) {
    throw "Missing Mac Apple signing environment validation script."
}
if (-not (Test-Path "scripts\mac-install-signing-assets.sh")) {
    throw "Missing Mac Apple signing asset installation script."
}
$releaseReadinessText = Get-Content "scripts\mac-release-readiness.sh" -Raw
if (-not $releaseReadinessText.Contains("scripts/mac-verify.sh")) {
    throw "Mac release readiness script should run Mac verification."
}
if (-not $releaseReadinessText.Contains("scripts/mac-capture-screenshots.sh")) {
    throw "Mac release readiness script should capture screenshots."
}
if (-not $releaseReadinessText.Contains("scripts/mac-validate-upload-env.sh")) {
    throw "Mac release readiness script should print upload environment validation."
}
if (-not $releaseReadinessText.Contains("scripts/mac-validate-review-contact-env.sh")) {
    throw "Mac release readiness script should print review contact validation."
}
$uploadEnvText = Get-Content "scripts\mac-validate-upload-env.sh" -Raw
$requiredUploadEnvVars = @(
    "APP_STORE_CONNECT_USERNAME",
    "APPLE_DEVELOPER_TEAM_ID",
    "APP_STORE_CONNECT_API_KEY_ID",
    "APP_STORE_CONNECT_API_ISSUER_ID",
    "APP_STORE_CONNECT_API_KEY_PATH"
)
foreach ($uploadEnvVar in $requiredUploadEnvVars) {
    if (-not $uploadEnvText.Contains($uploadEnvVar)) {
        throw "Upload environment validation script should check $uploadEnvVar."
    }
}
if (-not $uploadEnvText.Contains("Do not store the App Store Connect .p8 key inside this repository.")) {
    throw "Upload environment validation script should reject .p8 keys stored in the repository."
}
if (-not $uploadEnvText.Contains("BEGIN PRIVATE KEY")) {
    throw "Upload environment validation script should inspect the .p8 key header."
}
$signingEnvText = Get-Content "scripts\mac-validate-signing-env.sh" -Raw
$requiredSigningEnvVars = @(
    "APPLE_DISTRIBUTION_CERTIFICATE_BASE64",
    "APPLE_DISTRIBUTION_CERTIFICATE_PASSWORD",
    "APPLE_APP_STORE_PROFILE_BASE64",
    "APPLE_CODESIGN_KEYCHAIN_PASSWORD"
)
foreach ($signingEnvVar in $requiredSigningEnvVars) {
    if (-not $signingEnvText.Contains($signingEnvVar)) {
        throw "Signing environment validation script should check $signingEnvVar."
    }
}
if (-not $signingEnvText.Contains("com.snaptable.reminder")) {
    throw "Signing environment validation script should validate the provisioning profile bundle id."
}
if (-not $signingEnvText.Contains("get-task-allow")) {
    throw "Signing environment validation script should reject development provisioning profiles."
}
$installSigningAssetsText = Get-Content "scripts\mac-install-signing-assets.sh" -Raw
if (-not $installSigningAssetsText.Contains("security create-keychain")) {
    throw "Signing asset installation script should create a temporary keychain."
}
if (-not $installSigningAssetsText.Contains("security import")) {
    throw "Signing asset installation script should import the distribution certificate."
}
if (-not $installSigningAssetsText.Contains("set-key-partition-list")) {
    throw "Signing asset installation script should configure key partition access for codesigning."
}
if (-not $installSigningAssetsText.Contains("Provisioning Profiles")) {
    throw "Signing asset installation script should install the provisioning profile."
}
if (-not $installSigningAssetsText.Contains("APPLE_PROVISIONING_PROFILE_SPECIFIER")) {
    throw "Signing asset installation script should expose the profile specifier to Fastlane."
}
$screenshotScriptText = Get-Content "scripts\mac-capture-screenshots.sh" -Raw
if (-not $screenshotScriptText.Contains("SnapTableReminderScreenshots")) {
    throw "Screenshot script should run the SnapTableReminderScreenshots scheme."
}
if (-not $screenshotScriptText.Contains("xcresulttool export attachments")) {
    throw "Screenshot script should export XCTest screenshot attachments."
}
if (-not $screenshotScriptText.Contains("mac-stage-fastlane-screenshots.sh")) {
    throw "Screenshot script should stage screenshots for Fastlane."
}
$screenshotTestText = Get-Content "SnapTableReminderUITests\AppStoreScreenshotUITests.swift" -Raw
if (-not $screenshotTestText.Contains("-resetDemoData")) {
    throw "Screenshot UI tests should reset demo data for stable screenshots."
}
if (-not $screenshotTestText.Contains("SettingsPrivacySummary")) {
    throw "Screenshot UI tests should wait for the stable Settings privacy summary identifier."
}
$settingsViewText = Get-Content "SnapTableReminder\Views\SettingsView.swift" -Raw
if (-not $settingsViewText.Contains('accessibilityIdentifier("SettingsPrivacySummary")')) {
    throw "SettingsView should expose a stable privacy summary accessibility identifier for screenshots."
}
if (-not $screenshotScriptText.Contains("iPhone 16 Pro Max") -and -not $screenshotScriptText.Contains("iPhone 17 Pro Max")) {
    throw "Screenshot script should prefer current App Store iPhone screenshot simulators."
}
if (-not (Test-Path "scripts\mac-stage-fastlane-screenshots.sh")) {
    throw "Missing Mac Fastlane screenshot staging script."
}
$screenshotStagingText = Get-Content "scripts\mac-stage-fastlane-screenshots.sh" -Raw
if (-not $screenshotStagingText.Contains("fastlane/screenshots/en-US")) {
    throw "Screenshot staging script should output fastlane/screenshots/en-US."
}
if ($screenshotStagingText.Contains("mapfile") -or $screenshotStagingText.Contains("readarray")) {
    throw "Screenshot staging script should avoid Bash 4-only mapfile/readarray on macOS."
}
if (-not $fastfileText.Contains("lane :screenshots")) {
    throw "fastlane/Fastfile should include the screenshots lane."
}
if (-not $fastfileText.Contains("screenshots_path: `"fastlane/screenshots`"")) {
    throw "Fastlane screenshots lane should upload fastlane/screenshots."
}
if (-not (Test-Path "fastlane\Precheckfile")) {
    throw "Missing fastlane/Precheckfile."
}
$precheckText = Get-Content "fastlane\Precheckfile" -Raw
if (-not $fastfileText.Contains("lane :review_check")) {
    throw "fastlane/Fastfile should include the review_check lane."
}
if (-not $fastfileText.Contains("precheck(")) {
    throw "review_check lane should call Fastlane precheck."
}
if (-not $fastfileText.Contains("default_rule_level: :error")) {
    throw "Fastlane precheck should default to error-level findings."
}
if (-not $precheckText.Contains("placeholder_text(level: :error)")) {
    throw "Precheckfile should treat placeholder text as an error."
}
if (-not $precheckText.Contains("unreachable_urls(level: :error)")) {
    throw "Precheckfile should treat unreachable URLs as an error."
}
if (-not $launchRunbookText.Contains("scripts/mac-capture-screenshots.sh")) {
    throw "Launch runbook should mention the screenshot capture script."
}
if (-not $launchRunbookText.Contains("-resetDemoData")) {
    throw "Launch runbook should mention reset demo data for screenshots."
}
$screenshotWorkflowText = Get-Content ".github\workflows\app-store-screenshots.yml" -Raw
if (-not $screenshotWorkflowText.Contains("workflow_dispatch")) {
    throw "App Store screenshot workflow should be manually runnable."
}
if (-not $screenshotWorkflowText.Contains("timeout-minutes: 20")) {
    throw "App Store screenshot workflow should cap macOS runtime."
}
if (-not $screenshotWorkflowText.Contains("scripts/mac-capture-screenshots.sh")) {
    throw "App Store screenshot workflow should run the Mac screenshot script."
}
if (-not $screenshotWorkflowText.Contains("actions/upload-artifact")) {
    throw "App Store screenshot workflow should upload screenshot artifacts."
}
if (-not $screenshotWorkflowText.Contains("fastlane-screenshots")) {
    throw "App Store screenshot workflow should upload Fastlane screenshot artifacts."
}
$releaseReadinessWorkflowText = Get-Content ".github\workflows\release-readiness.yml" -Raw
if (-not $releaseReadinessWorkflowText.Contains("workflow_dispatch")) {
    throw "Release Readiness workflow should be manually runnable."
}
if (-not $releaseReadinessWorkflowText.Contains("timeout-minutes: 25")) {
    throw "Release Readiness workflow should cap macOS runtime."
}
if (-not $releaseReadinessWorkflowText.Contains("scripts/mac-release-readiness.sh")) {
    throw "Release Readiness workflow should run the Mac release readiness script."
}
if (-not $releaseReadinessWorkflowText.Contains("actions/upload-artifact")) {
    throw "Release Readiness workflow should upload artifacts."
}
if (-not $releaseReadinessWorkflowText.Contains("fastlane-screenshots")) {
    throw "Release Readiness workflow should upload Fastlane screenshot artifacts."
}
if (-not $releaseReadinessWorkflowText.Contains("scripts/mac-validate-review-contact-env.sh")) {
    throw "Release Readiness workflow should summarize review contact validation."
}
$appStoreConnectUploadWorkflowPath = ".github\workflows\app-store-connect-upload.yml"
if (-not (Test-Path $appStoreConnectUploadWorkflowPath)) {
    throw "Missing App Store Connect upload workflow."
}
$appStoreConnectUploadWorkflowText = Get-Content $appStoreConnectUploadWorkflowPath -Raw
if (-not $appStoreConnectUploadWorkflowText.Contains("workflow_dispatch")) {
    throw "App Store Connect upload workflow should be manually runnable."
}
if (-not $appStoreConnectUploadWorkflowText.Contains("timeout-minutes: 45")) {
    throw "App Store Connect upload workflow should cap macOS runtime."
}
if (-not $appStoreConnectUploadWorkflowText.Contains("APP_STORE_CONNECT_API_PRIVATE_KEY")) {
    throw "App Store Connect upload workflow should accept the private key from GitHub Secrets."
}
if (-not $appStoreConnectUploadWorkflowText.Contains("APP_STORE_CONNECT_API_KEY_PATH")) {
    throw "App Store Connect upload workflow should write a temporary API key path for Fastlane."
}
if (-not $appStoreConnectUploadWorkflowText.Contains('${RUNNER_TEMP}/app-store-connect')) {
    throw "App Store Connect upload workflow should store the temporary API key outside the repository."
}
if (-not $appStoreConnectUploadWorkflowText.Contains("scripts/mac-validate-upload-env.sh")) {
    throw "App Store Connect upload workflow should validate upload credentials before Fastlane."
}
if (-not $appStoreConnectUploadWorkflowText.Contains("bundle exec fastlane ios metadata")) {
    throw "App Store Connect upload workflow should upload metadata."
}
if (-not $appStoreConnectUploadWorkflowText.Contains("bundle exec fastlane ios screenshots")) {
    throw "App Store Connect upload workflow should upload screenshots."
}
if (-not $appStoreConnectUploadWorkflowText.Contains("bundle exec fastlane ios review_check")) {
    throw "App Store Connect upload workflow should run Fastlane precheck."
}
$testFlightUploadWorkflowPath = ".github\workflows\testflight-upload.yml"
if (-not (Test-Path $testFlightUploadWorkflowPath)) {
    throw "Missing TestFlight upload workflow."
}
$testFlightUploadWorkflowText = Get-Content $testFlightUploadWorkflowPath -Raw
if (-not $testFlightUploadWorkflowText.Contains("workflow_dispatch")) {
    throw "TestFlight upload workflow should be manually runnable."
}
if (-not $testFlightUploadWorkflowText.Contains("timeout-minutes: 45")) {
    throw "TestFlight upload workflow should cap macOS runtime."
}
foreach ($signingEnvVar in $requiredSigningEnvVars) {
    if (-not $testFlightUploadWorkflowText.Contains($signingEnvVar)) {
        throw "TestFlight upload workflow should read $signingEnvVar from GitHub Secrets."
    }
}
if (-not $testFlightUploadWorkflowText.Contains("scripts/mac-install-signing-assets.sh")) {
    throw "TestFlight upload workflow should install signing assets."
}
if (-not $testFlightUploadWorkflowText.Contains("bundle exec fastlane ios testflight")) {
    throw "TestFlight upload workflow should upload the signed build to TestFlight."
}
Write-Host "screenshot capture path present"

Write-Section "Static site links"
$htmlFiles = Get-ChildItem site -Filter *.html
foreach ($file in $htmlFiles) {
    $content = Get-Content $file.FullName -Raw
    $parts = $content -split "href="
    foreach ($part in $parts | Select-Object -Skip 1) {
        $quoteCode = [int][char]$part.Substring(0, 1)
        if ($quoteCode -ne 34 -and $quoteCode -ne 39) {
            continue
        }
        $quote = [char]$quoteCode
        $end = $part.IndexOf($quote, 1)
        if ($end -lt 1) {
            throw "Malformed href in $($file.Name)"
        }
        $href = $part.Substring(1, $end - 1)
        if ($href -notmatch '^https?:|^mailto:|^#') {
            $target = Join-Path $file.DirectoryName $href
            if (-not (Test-Path $target)) {
                throw "Missing link target $href in $($file.Name)"
            }
        }
    }
}
Write-Host "site links valid"

Write-Section "GitHub Pages workflow"
$iosCiWorkflowText = Get-Content ".github\workflows\ios-ci.yml" -Raw
if (-not $iosCiWorkflowText.Contains("timeout-minutes: 20")) {
    throw "iOS CI workflow should cap macOS runtime."
}
$pagesWorkflowText = Get-Content ".github\workflows\pages.yml" -Raw
if (-not $pagesWorkflowText.Contains("enablement: true")) {
    throw "GitHub Pages workflow should enable Pages when configuring the site."
}
if (-not $pagesWorkflowText.Contains("privacy.html")) {
    throw "GitHub Pages workflow should summarize the Privacy Policy URL."
}
if (-not $pagesWorkflowText.Contains("support.html")) {
    throw "GitHub Pages workflow should summarize the Support URL."
}
Write-Host "Pages workflow summarizes App Store URLs"

Write-Section "Toolchain report"
$tools = "swift", "xcodebuild", "xcodegen", "bash"
foreach ($tool in $tools) {
    $command = Get-Command $tool -ErrorAction SilentlyContinue
    if ($command) {
        Write-Host "$tool=$($command.Source)"
    } else {
        Write-Host "$tool=missing"
    }
}

Write-Host ""
Write-Host "Windows preflight completed."
