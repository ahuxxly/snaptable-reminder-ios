param(
    [string]$OutputDirectory = "",
    [string]$Owner = "ahuxxly",
    [string]$RepoName = "snaptable-reminder-ios"
)

$ErrorActionPreference = "Stop"

function Write-Section($title) {
    Write-Host ""
    Write-Host "== $title =="
}

function Get-DefaultOutputDirectory {
    $documents = [Environment]::GetFolderPath("MyDocuments")
    if ([string]::IsNullOrWhiteSpace($documents)) {
        $documents = [Environment]::GetFolderPath("UserProfile")
    }
    if ([string]::IsNullOrWhiteSpace($documents)) {
        $documents = [System.IO.Path]::GetTempPath()
    }

    return Join-Path $documents "SnapTableReminder-AppStoreConnect-EntryPack"
}

function Resolve-FullPath($path) {
    if ([string]::IsNullOrWhiteSpace($path)) {
        throw "OutputDirectory cannot be empty."
    }

    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path $path))
}

function Read-RequiredTextFile($path) {
    if (-not (Test-Path $path)) {
        throw "Missing source text file: $path"
    }

    return (Get-Content $path -Raw).Trim()
}

function Write-Utf8NoBomFile($path, $content) {
    $parent = Split-Path -Parent $path
    if (-not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($path, $content, $utf8NoBom)
}

function New-SectionText($pairs) {
    $lines = New-Object "System.Collections.Generic.List[string]"
    foreach ($pair in $pairs) {
        $lines.Add("$($pair.Label): $($pair.Value)") | Out-Null
    }
    return ($lines.ToArray() -join [Environment]::NewLine)
}

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Get-DefaultOutputDirectory
}

if ([string]::IsNullOrWhiteSpace($Owner)) {
    throw "Owner is required."
}
if ([string]::IsNullOrWhiteSpace($RepoName)) {
    throw "RepoName is required."
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$outputRoot = Resolve-FullPath $OutputDirectory
New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null

$storeFieldsPath = Join-Path $repoRoot "docs\app-store\app-store-fields.json"
$storeFields = Get-Content $storeFieldsPath -Raw | ConvertFrom-Json

$subtitle = Read-RequiredTextFile (Join-Path $repoRoot "fastlane\metadata\en-US\subtitle.txt")
$promotionalText = Read-RequiredTextFile (Join-Path $repoRoot "fastlane\metadata\en-US\promotional_text.txt")
$description = Read-RequiredTextFile (Join-Path $repoRoot "fastlane\metadata\en-US\description.txt")
$keywords = Read-RequiredTextFile (Join-Path $repoRoot "fastlane\metadata\en-US\keywords.txt")
$reviewNotes = Read-RequiredTextFile (Join-Path $repoRoot "fastlane\metadata\review_information\notes.txt")

$privacyUrl = "https://$Owner.github.io/$RepoName/privacy.html"
$supportUrl = "https://$Owner.github.io/$RepoName/support.html"
$excludeRegions = @($storeFields.availability.excludeCountriesOrRegions)
$requiredScreens = @($storeFields.screenshots.requiredScreens)

$appRecordText = @"
App Store Connect App Record

App name: $($storeFields.app.name)
Bundle ID: $($storeFields.app.bundleId)
SKU: $($storeFields.app.sku)
Primary language: $($storeFields.app.primaryLanguage)
Category: $($storeFields.app.category)
Content rights: $($storeFields.app.contentRights)
"@

$pricingAvailabilityText = @"
Pricing and Availability

Distribution method: $($storeFields.availability.distributionMethod)
Availability strategy: $($storeFields.availability.strategy)
Include all other supported regions: $($storeFields.availability.includeAllOtherSupportedRegions)
Exclude countries or regions: $($excludeRegions -join ', ')
Paid model: $($storeFields.pricing.model)
Starting price: $($storeFields.pricing.startingPrice.currency) $($storeFields.pricing.startingPrice.amount)
Backup price: $($storeFields.pricing.backupPrice.currency) $($storeFields.pricing.backupPrice.amount)
EU DSA trader status decision required: $($storeFields.compliance.euDigitalServicesAct.traderStatusDecisionRequired)
"@

$metadataText = @"
Version Metadata

Name:
$($storeFields.app.name)

Subtitle:
$subtitle

Promotional text:
$promotionalText

Description:
$description

Keywords:
$keywords

Privacy Policy URL:
$privacyUrl

Support URL:
$supportUrl

Screenshots required:
$($storeFields.screenshots.requiredDevice): $($requiredScreens -join ', ')
"@

$privacyComplianceText = @"
Privacy and Compliance

Data collected: $($storeFields.privacy.dataCollected)
Tracking: $(if ($storeFields.privacy.tracking) { "Yes" } else { "No" })
Third-party analytics: $(if ($storeFields.privacy.thirdPartyAnalytics) { "Yes" } else { "No" })
User account: $(if ($storeFields.privacy.userAccount) { "Yes" } else { "No" })
Backend transmission: $(if ($storeFields.privacy.backendTransmission) { "Yes" } else { "No" })
Cloud AI parsing: $(if ($storeFields.privacy.cloudAiParsing) { "Yes" } else { "No" })
ITSAppUsesNonExemptEncryption: false
Uses only standard Apple platform encryption: $($storeFields.compliance.usesOnlyStandardApplePlatformEncryption)
Contains legal, medical, tax, financial, or investment advice: $($storeFields.compliance.containsLegalMedicalTaxFinancialInvestmentAdvice)
Targets children: $($storeFields.compliance.targetsChildren)
Requires reviewer account: $($storeFields.compliance.requiresReviewerAccount)
EU storefronts included in V1: $($storeFields.compliance.euDigitalServicesAct.euStorefrontsIncludedInV1)
EU DSA trader status decision required: $($storeFields.compliance.euDigitalServicesAct.traderStatusDecisionRequired)
Age rating draft: Likely 4+
"@

$reviewText = @"
App Review

No test account required.
Test account required: $($storeFields.review.testAccountRequired)

Review notes:
$reviewNotes

Demo flow:
1. Open Capture.
2. Paste: $($storeFields.review.demoPasteText)
3. Tap Parse and Review.
4. Review the extracted fields and save.
5. Open Records and confirm the saved record appears.
6. Open Settings and export CSV.

Demo paste text:
$($storeFields.review.demoPasteText)
"@

$readmeText = @"
# SnapTable Reminder App Store Connect Entry Pack

Paste-ready fields for creating and filling the App Store Connect app record for $($storeFields.app.bundleId).

Use these files together with docs/app-store/launch-runbook.md. Do not add private Apple credentials, tax records, banking records, DSA evidence, or App Review contact details to this packet.

Generated files:

- 00-app-record.txt
- 01-pricing-availability.txt
- 02-version-metadata.txt
- 03-privacy-compliance.txt
- 04-review.txt
- app-store-connect-entry-pack.json
"@

$packet = [ordered]@{
    generatedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    app = [ordered]@{
        name = $storeFields.app.name
        displayName = $storeFields.app.displayName
        bundleId = $storeFields.app.bundleId
        sku = $storeFields.app.sku
        primaryLanguage = $storeFields.app.primaryLanguage
        category = $storeFields.app.category
    }
    storeListing = [ordered]@{
        subtitle = $subtitle
        promotionalText = $promotionalText
        description = $description
        keywords = $keywords
    }
    pricing = $storeFields.pricing
    availability = $storeFields.availability
    urls = [ordered]@{
        privacyPolicyUrl = $privacyUrl
        supportUrl = $supportUrl
    }
    privacy = $storeFields.privacy
    compliance = $storeFields.compliance
    review = [ordered]@{
        testAccountRequired = $storeFields.review.testAccountRequired
        notes = $reviewNotes
        demoPasteText = $storeFields.review.demoPasteText
    }
    screenshots = $storeFields.screenshots
    sources = @(
        "docs/app-store/app-store-fields.json",
        "fastlane/metadata/en-US/subtitle.txt",
        "fastlane/metadata/en-US/promotional_text.txt",
        "fastlane/metadata/en-US/description.txt",
        "fastlane/metadata/en-US/keywords.txt",
        "fastlane/metadata/review_information/notes.txt",
        "docs/app-store/privacy-questionnaire.md",
        "docs/app-store/age-rating.md",
        "docs/app-store/export-compliance.md",
        "docs/app-store/eu-dsa-trader.md"
    )
}

Write-Utf8NoBomFile (Join-Path $outputRoot "README.md") $readmeText
Write-Utf8NoBomFile (Join-Path $outputRoot "00-app-record.txt") $appRecordText
Write-Utf8NoBomFile (Join-Path $outputRoot "01-pricing-availability.txt") $pricingAvailabilityText
Write-Utf8NoBomFile (Join-Path $outputRoot "02-version-metadata.txt") $metadataText
Write-Utf8NoBomFile (Join-Path $outputRoot "03-privacy-compliance.txt") $privacyComplianceText
Write-Utf8NoBomFile (Join-Path $outputRoot "04-review.txt") $reviewText
Write-Utf8NoBomFile (Join-Path $outputRoot "app-store-connect-entry-pack.json") ($packet | ConvertTo-Json -Depth 20)

Write-Section "App Store Connect entry pack"
Write-Host "output=$outputRoot"
Write-Host "privacy=$privacyUrl"
Write-Host "support=$supportUrl"
Write-Host "bundle=$($storeFields.app.bundleId)"
