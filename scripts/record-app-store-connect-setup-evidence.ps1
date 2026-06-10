param(
    [string]$MaterialsDirectory = "",
    [string]$AppStoreConnectAppId,

    [string]$AppName,
    [string]$BundleId,
    [string]$Sku,
    [string]$PrimaryLanguage,
    [string]$PrimaryCategory,

    [string]$PriceCurrency,
    [decimal]$PriceAmount,
    [string]$AvailabilityMode,
    [string[]]$ExcludedCountriesOrRegions = @(),

    [string]$PrivacyPolicyUrl,
    [string]$SupportUrl,

    [switch]$PrivacyAnswersCompleted,
    [switch]$AgeRatingCompleted,
    [switch]$ExportComplianceCompleted,
    [switch]$EuDsaTraderStatusCompleted,

    [switch]$DryRun,
    [switch]$AllowWorkspacePath
)

$ErrorActionPreference = "Stop"

function Write-Section($title) {
    Write-Host ""
    Write-Host "== $title =="
}

function Resolve-RepositoryRoot {
    $repoRoot = ""
    try {
        $repoRoot = (git rev-parse --show-toplevel 2>$null).Trim()
    } catch {
        $repoRoot = ""
    }

    if ([string]::IsNullOrWhiteSpace($repoRoot)) {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
    }

    return [System.IO.Path]::GetFullPath($repoRoot)
}

function Get-DefaultMaterialsDirectory {
    $documents = [Environment]::GetFolderPath("MyDocuments")
    if ([string]::IsNullOrWhiteSpace($documents)) {
        $documents = [Environment]::GetFolderPath("UserProfile")
    }
    if ([string]::IsNullOrWhiteSpace($documents)) {
        $documents = [System.IO.Path]::GetTempPath()
    }

    return (Join-Path $documents "SnapTableReminder-Apple-Materials")
}

function Resolve-FullPath($path, $fieldName) {
    if ([string]::IsNullOrWhiteSpace($path)) {
        throw "$fieldName cannot be empty."
    }

    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path $path))
}

function Assert-OutsideRepository($path, $repoRoot, $allowWorkspacePath, $label) {
    if ($allowWorkspacePath) {
        return
    }

    $resolvedPath = [System.IO.Path]::GetFullPath($path)
    $resolvedRepoRoot = [System.IO.Path]::GetFullPath($repoRoot)
    $repoPrefix = $resolvedRepoRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar

    if ($resolvedPath.Equals($resolvedRepoRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
        $resolvedPath.StartsWith($repoPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "$label must be stored outside this repository: $resolvedPath"
    }
}

function Assert-RequiredText($value, $fieldName) {
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw "$fieldName cannot be empty."
    }
}

function Assert-Url($value, $fieldName) {
    Assert-RequiredText $value $fieldName
    if ($value -notmatch "^https://") {
        throw "$fieldName must be an https URL."
    }
}

function Add-Mismatch($mismatches, $message) {
    $mismatches.Add($message) | Out-Null
}

function Assert-MatchesStoreFields($storeFields) {
    $mismatches = New-Object "System.Collections.Generic.List[string]"

    if ($AppName -ne $storeFields.app.name) {
        Add-Mismatch $mismatches "AppName '$AppName' does not match '$($storeFields.app.name)'."
    }
    if ($BundleId -ne $storeFields.app.bundleId) {
        Add-Mismatch $mismatches "BundleId '$BundleId' does not match '$($storeFields.app.bundleId)'."
    }
    if ($Sku -ne $storeFields.app.sku) {
        Add-Mismatch $mismatches "Sku '$Sku' does not match '$($storeFields.app.sku)'."
    }
    if ($PrimaryLanguage -ne $storeFields.app.primaryLanguage) {
        Add-Mismatch $mismatches "PrimaryLanguage '$PrimaryLanguage' does not match '$($storeFields.app.primaryLanguage)'."
    }
    if ($PrimaryCategory -ne $storeFields.app.category) {
        Add-Mismatch $mismatches "PrimaryCategory '$PrimaryCategory' does not match '$($storeFields.app.category)'."
    }
    if ($PriceCurrency -ne $storeFields.pricing.startingPrice.currency -or [decimal]$PriceAmount -ne [decimal]$storeFields.pricing.startingPrice.amount) {
        Add-Mismatch $mismatches "Price '$PriceCurrency $PriceAmount' does not match '$($storeFields.pricing.startingPrice.currency) $($storeFields.pricing.startingPrice.amount)'."
    }
    if ($AvailabilityMode -ne $storeFields.availability.strategy) {
        Add-Mismatch $mismatches "AvailabilityMode '$AvailabilityMode' does not match '$($storeFields.availability.strategy)'."
    }
    foreach ($excludedRegion in @($storeFields.availability.excludeCountriesOrRegions)) {
        if (-not ($ExcludedCountriesOrRegions -contains $excludedRegion)) {
            Add-Mismatch $mismatches "ExcludedCountriesOrRegions must include $excludedRegion."
        }
    }
    if (-not ($ExcludedCountriesOrRegions -contains "China mainland")) {
        Add-Mismatch $mismatches "China mainland must be excluded for version 1 availability."
    }
    if ($storeFields.compliance.euDigitalServicesAct.euStorefrontsIncludedInV1 -eq $true -and $storeFields.compliance.euDigitalServicesAct.traderStatusDecisionRequired -eq $true -and -not $EuDsaTraderStatusCompleted) {
        Add-Mismatch $mismatches "EU DSA trader status must be completed when EU storefronts are included."
    }

    if ($mismatches.Count -gt 0) {
        throw "App Store Connect setup evidence does not match release source fields: $($mismatches -join ' ')"
    }
}

function Write-JsonFile($path, $value) {
    $parent = Split-Path -Parent $path
    if (-not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    $json = $value | ConvertTo-Json -Depth 6
    Set-Content -Path $path -Encoding UTF8 -Value $json
}

function Write-SummaryFile($path, $evidence) {
    $parent = Split-Path -Parent $path
    if (-not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    $lines = @(
        "# App Store Connect Setup Evidence",
        "",
        "Recorded at: $($evidence.recordedAt)",
        "App Store Connect app id: $($evidence.appStoreConnectAppId)",
        "App name: $($evidence.app.name)",
        "Bundle id: $($evidence.app.bundleId)",
        "SKU: $($evidence.app.sku)",
        "Primary language: $($evidence.app.primaryLanguage)",
        "Primary category: $($evidence.app.primaryCategory)",
        "Price: $($evidence.pricing.currency) $($evidence.pricing.amount)",
        "Availability mode: $($evidence.availability.mode)",
        "Excluded regions: $($evidence.availability.excludeCountriesOrRegions -join ', ')",
        "Privacy URL: $($evidence.urls.privacyPolicyUrl)",
        "Support URL: $($evidence.urls.supportUrl)",
        "",
        "## Compliance",
        "",
        "- Privacy answers completed: $($evidence.compliance.privacyAnswersCompleted)",
        "- Age rating completed: $($evidence.compliance.ageRatingCompleted)",
        "- Export compliance completed: $($evidence.compliance.exportComplianceCompleted)",
        "- EU DSA trader status completed: $($evidence.compliance.euDsaTraderStatusCompleted)"
    )
    Set-Content -Path $path -Encoding UTF8 -Value ($lines -join [Environment]::NewLine)
}

if ([string]::IsNullOrWhiteSpace($MaterialsDirectory)) {
    $MaterialsDirectory = Get-DefaultMaterialsDirectory
}

foreach ($required in @(
    @($AppStoreConnectAppId, "AppStoreConnectAppId"),
    @($AppName, "AppName"),
    @($BundleId, "BundleId"),
    @($Sku, "Sku"),
    @($PrimaryLanguage, "PrimaryLanguage"),
    @($PrimaryCategory, "PrimaryCategory"),
    @($PriceCurrency, "PriceCurrency"),
    @($AvailabilityMode, "AvailabilityMode")
)) {
    Assert-RequiredText $required[0] $required[1]
}
Assert-Url $PrivacyPolicyUrl "PrivacyPolicyUrl"
Assert-Url $SupportUrl "SupportUrl"

if (-not $PrivacyAnswersCompleted) {
    throw "PrivacyAnswersCompleted is required before release."
}
if (-not $AgeRatingCompleted) {
    throw "AgeRatingCompleted is required before release."
}
if (-not $ExportComplianceCompleted) {
    throw "ExportComplianceCompleted is required before release."
}

$repoRoot = Resolve-RepositoryRoot
$materialsRoot = Resolve-FullPath $MaterialsDirectory "MaterialsDirectory"
Assert-OutsideRepository $materialsRoot $repoRoot $AllowWorkspacePath "App Store Connect setup evidence folder"
if (-not (Test-Path $materialsRoot)) {
    throw "MaterialsDirectory does not exist: $materialsRoot"
}

$storeFieldsPath = Join-Path $repoRoot "docs\app-store\app-store-fields.json"
$storeFields = Get-Content $storeFieldsPath -Raw | ConvertFrom-Json
Assert-MatchesStoreFields $storeFields

$evidenceDirectory = Join-Path $materialsRoot "05-release-evidence"
$evidenceJsonPath = Join-Path $evidenceDirectory "app-store-connect-setup.private.json"
$summaryPath = Join-Path $evidenceDirectory "app-store-connect-setup-summary.md"

$evidence = [ordered]@{
    schemaVersion = 1
    recordedAt = [DateTimeOffset]::UtcNow.ToString("o")
    appStoreConnectAppId = $AppStoreConnectAppId
    app = [ordered]@{
        name = $AppName
        bundleId = $BundleId
        sku = $Sku
        primaryLanguage = $PrimaryLanguage
        primaryCategory = $PrimaryCategory
    }
    pricing = [ordered]@{
        currency = $PriceCurrency
        amount = [decimal]$PriceAmount
    }
    availability = [ordered]@{
        mode = $AvailabilityMode
        excludeCountriesOrRegions = @($ExcludedCountriesOrRegions)
    }
    urls = [ordered]@{
        privacyPolicyUrl = $PrivacyPolicyUrl
        supportUrl = $SupportUrl
    }
    compliance = [ordered]@{
        privacyAnswersCompleted = [bool]$PrivacyAnswersCompleted
        ageRatingCompleted = [bool]$AgeRatingCompleted
        exportComplianceCompleted = [bool]$ExportComplianceCompleted
        euDsaTraderStatusCompleted = [bool]$EuDsaTraderStatusCompleted
    }
}

Write-Section "Record App Store Connect setup evidence"
Write-Host "materials=$materialsRoot"
Write-Host "appStoreConnectAppId=$AppStoreConnectAppId"
Write-Host "bundleId=$BundleId"
Write-Host "price=$PriceCurrency $PriceAmount"

if ($DryRun) {
    Write-Host "dry-run: would write App Store Connect setup evidence JSON to $evidenceJsonPath"
    Write-Host "dry-run: would write App Store Connect setup summary to $summaryPath"
    Write-Host ""
    Write-Host "Dry run complete; no files were written."
    exit 0
}

Write-JsonFile $evidenceJsonPath $evidence
Write-SummaryFile $summaryPath ([pscustomobject]$evidence)

Write-Host ""
Write-Host "Wrote App Store Connect setup evidence JSON: $evidenceJsonPath"
Write-Host "Wrote App Store Connect setup summary: $summaryPath"
