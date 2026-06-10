$ErrorActionPreference = "Stop"

$utf8 = [System.Text.Encoding]::UTF8

function Read-RequiredText($path) {
    if (-not (Test-Path $path)) {
        throw "Missing required metadata file: $path"
    }

    return (Get-Content $path -Raw).TrimEnd("`r", "`n")
}

function Assert-CharacterRange($label, $value, $minimum, $maximum) {
    $length = $value.Length
    if ($length -lt $minimum -or $length -gt $maximum) {
        throw "$label must be between $minimum and $maximum characters. Current length: $length"
    }
}

function Assert-CharacterLimit($label, $value, $maximum) {
    $length = $value.Length
    if ($length -gt $maximum) {
        throw "$label must be no more than $maximum characters. Current length: $length"
    }
}

function Assert-ByteLimit($label, $value, $maximum) {
    $length = $utf8.GetByteCount($value)
    if ($length -gt $maximum) {
        throw "$label must be no more than $maximum UTF-8 bytes. Current length: $length"
    }
}

function Assert-PlainText($label, $value) {
    if ($value -match "<[A-Za-z/][^>]*>") {
        throw "$label should be plain text and not contain HTML tags."
    }
}

$storeFields = Get-Content "docs\app-store\app-store-fields.json" -Raw | ConvertFrom-Json

$name = Read-RequiredText "fastlane\metadata\en-US\name.txt"
$subtitle = Read-RequiredText "fastlane\metadata\en-US\subtitle.txt"
$promotionalText = Read-RequiredText "fastlane\metadata\en-US\promotional_text.txt"
$description = Read-RequiredText "fastlane\metadata\en-US\description.txt"
$keywords = Read-RequiredText "fastlane\metadata\en-US\keywords.txt"
$releaseNotes = Read-RequiredText "fastlane\metadata\en-US\release_notes.txt"
$reviewNotes = Read-RequiredText "fastlane\metadata\review_information\notes.txt"
$primaryCategory = Read-RequiredText "fastlane\metadata\primary_category.txt"

Assert-CharacterRange "App name" $name 2 30
Assert-CharacterLimit "Subtitle" $subtitle 30
Assert-CharacterLimit "Promotional text" $promotionalText 170
Assert-CharacterLimit "Description" $description 4000
Assert-ByteLimit "Keywords" $keywords 100
Assert-CharacterLimit "What's New" $releaseNotes 4000
Assert-ByteLimit "App Review notes" $reviewNotes 4000

Assert-PlainText "Promotional text" $promotionalText
Assert-PlainText "Description" $description
Assert-PlainText "What's New" $releaseNotes
Assert-PlainText "App Review notes" $reviewNotes

if ($name -ne $storeFields.app.name) {
    throw "Fastlane app name does not match docs/app-store/app-store-fields.json."
}
if ($subtitle -ne $storeFields.storeListing.subtitle) {
    throw "Fastlane subtitle does not match docs/app-store/app-store-fields.json."
}
if ($promotionalText -ne $storeFields.storeListing.promotionalText) {
    throw "Fastlane promotional text does not match docs/app-store/app-store-fields.json."
}
if ($keywords -ne (($storeFields.storeListing.keywords) -join ",")) {
    throw "Fastlane keywords do not match docs/app-store/app-store-fields.json."
}
if ($primaryCategory -ne "PRODUCTIVITY") {
    throw "Fastlane primary category should be PRODUCTIVITY."
}

$sku = $storeFields.app.sku
if ($sku -notmatch "^[A-Za-z0-9][A-Za-z0-9._-]*$") {
    throw "SKU can contain letters, numbers, hyphens, periods, and underscores, but must not start with punctuation."
}

$keywordItems = $keywords -split "," | ForEach-Object { $_.Trim() }
if ($keywordItems.Count -eq 0) {
    throw "At least one keyword is required."
}
foreach ($keyword in $keywordItems) {
    if ($keyword.Length -le 2) {
        throw "Keyword '$keyword' must be greater than two characters."
    }
}

$appNameWords = @($storeFields.app.name -split "\s+") + @($storeFields.app.displayName)
foreach ($keyword in $keywordItems) {
    foreach ($word in $appNameWords) {
        if ($keyword.Equals($word, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Keyword '$keyword' duplicates the app name or display name."
        }
    }
}

$optionalUrlFiles = @(
    "fastlane\metadata\en-US\privacy_url.txt",
    "fastlane\metadata\en-US\support_url.txt"
)
foreach ($urlFile in $optionalUrlFiles) {
    if (Test-Path $urlFile) {
        $urlValue = Read-RequiredText $urlFile
        if ($urlValue -notmatch "^https://") {
            throw "Fastlane URL file must contain an https URL: $urlFile"
        }
    }
}

Write-Host "App Store metadata limits pass"
