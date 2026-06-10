$ErrorActionPreference = "Stop"

function Write-Section($title) {
    Write-Host ""
    Write-Host "== $title =="
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
[xml](Get-Content "SnapTableReminder\Resources\Info.plist" -Raw) | Out-Null
$privacyManifest = [xml](Get-Content "SnapTableReminder\Resources\PrivacyInfo.xcprivacy" -Raw)
Write-Host "resources parse"

Write-Section "Release configuration consistency"
$projectText = Get-Content "project.yml" -Raw
$appfileText = Get-Content "fastlane\Appfile" -Raw
$fastfileText = Get-Content "fastlane\Fastfile" -Raw
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
if (-not $projectText.Contains("SnapTableReminderUITests")) {
    throw "project.yml should include the screenshot UI test target."
}
if (-not $projectText.Contains("SnapTableReminderScreenshots")) {
    throw "project.yml should include the screenshot scheme."
}
if (-not $projectText.Contains("TEST_TARGET_NAME: SnapTableReminder")) {
    throw "Screenshot UI test target should point at SnapTableReminder."
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
$storePathFields = @(
    $storeFields.storeListing.descriptionPath,
    $storeFields.urls.privacyPolicyPath,
    $storeFields.urls.supportPath,
    $storeFields.review.notesPath,
    $storeFields.review.demoFlowPath
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
Write-Host "Fastlane metadata files align"

Write-Section "App Store metadata limits"
powershell -ExecutionPolicy Bypass -File scripts\validate-app-store-metadata.ps1

Write-Section "Asset references"
$appIconDirectory = "SnapTableReminder\Resources\Assets.xcassets\AppIcon.appiconset"
foreach ($image in $appIconContents.images) {
    if ($image.filename) {
        $imagePath = Join-Path $appIconDirectory $image.filename
        if (-not (Test-Path $imagePath)) {
            throw "Missing app icon file referenced by asset catalog: $($image.filename)"
        }
    }
}
Write-Host "app icon references valid"

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

Write-Section "Test coverage files"
$requiredTestFiles = @(
    "SnapTableReminderTests\DocumentParserTests.swift",
    "SnapTableReminderTests\CSVExporterTests.swift",
    "SnapTableReminderTests\RecordDateLogicTests.swift",
    "SnapTableReminderTests\AppStateSettingsTests.swift",
    "SnapTableReminderTests\ReminderDatePolicyTests.swift",
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
    "docs\app-store\monetization-plan.md"
)
foreach ($releaseDoc in $requiredReleaseDocs) {
    if (-not (Test-Path $releaseDoc)) {
        throw "Missing required release document: $releaseDoc"
    }
}
Write-Host "required release docs present"

Write-Section "Screenshot automation"
if (-not (Test-Path "scripts\mac-capture-screenshots.sh")) {
    throw "Missing Mac screenshot capture script."
}
$screenshotScriptText = Get-Content "scripts\mac-capture-screenshots.sh" -Raw
if (-not $screenshotScriptText.Contains("SnapTableReminderScreenshots")) {
    throw "Screenshot script should run the SnapTableReminderScreenshots scheme."
}
if (-not $screenshotScriptText.Contains("xcresulttool export attachments")) {
    throw "Screenshot script should export XCTest screenshot attachments."
}
if (-not $screenshotScriptText.Contains("iPhone 16 Pro Max") -and -not $screenshotScriptText.Contains("iPhone 17 Pro Max")) {
    throw "Screenshot script should prefer current App Store iPhone screenshot simulators."
}
if (-not $launchRunbookText.Contains("scripts/mac-capture-screenshots.sh")) {
    throw "Launch runbook should mention the screenshot capture script."
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
$pagesWorkflowText = Get-Content ".github\workflows\pages.yml" -Raw
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
