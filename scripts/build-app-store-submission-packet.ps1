param(
    [string]$EntryPackDirectory = "",
    [string]$ScreenshotArchiveDirectory = "",
    [string]$OutputDirectory = ""
)

$ErrorActionPreference = "Stop"

function Write-Section($title) {
    Write-Host ""
    Write-Host "== $title =="
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

function Resolve-FullPath($path, $defaultLeafName) {
    if ([string]::IsNullOrWhiteSpace($path)) {
        return [System.IO.Path]::GetFullPath((Join-Path (Get-DocumentsDirectory) $defaultLeafName))
    }
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path $path))
}

function Assert-ChildPath($parent, $child) {
    $resolvedParent = [System.IO.Path]::GetFullPath($parent).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    $resolvedChild = [System.IO.Path]::GetFullPath($child)
    if (-not $resolvedChild.StartsWith($resolvedParent, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to modify a path outside the output directory: $resolvedChild"
    }
}

function Reset-OutputDirectory($path) {
    if (Test-Path $path) {
        Remove-Item -LiteralPath $path -Recurse -Force
    }
    New-Item -ItemType Directory -Path $path -Force | Out-Null
}

function Reset-ChildDirectory($parent, $leafName) {
    $target = Join-Path $parent $leafName
    Assert-ChildPath $parent $target
    if (Test-Path $target) {
        Remove-Item -LiteralPath $target -Recurse -Force
    }
    New-Item -ItemType Directory -Path $target -Force | Out-Null
    return $target
}

function Copy-DirectoryContents($source, $target) {
    if (-not (Test-Path $source -PathType Container)) {
        throw "Missing directory: $source"
    }
    New-Item -ItemType Directory -Path $target -Force | Out-Null
    Copy-Item -Path (Join-Path $source "*") -Destination $target -Recurse -Force
}

function Assert-NoPrivateAppleFiles($path) {
    if (-not (Test-Path $path)) {
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
    foreach ($pattern in $privatePatterns) {
        $match = Get-ChildItem -LiteralPath $path -Recurse -Force -File -Filter $pattern -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($null -ne $match) {
            throw "Private Apple file '$($match.Name)' must not be included in the public submission packet source: $($match.FullName)"
        }
    }
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

    [pscustomobject]@{
        Path = [System.IO.Path]::GetFullPath($path)
        FileName = [System.IO.Path]::GetFileName($path)
        Width = [int]$width
        Height = [int]$height
        Bytes = [int64]$bytes.Length
    }
}

function Test-EntryPack($entryPackPath) {
    if (-not (Test-Path $entryPackPath -PathType Container)) {
        throw "EntryPackDirectory does not exist: $entryPackPath"
    }

    $requiredFiles = @(
        "README.md",
        "00-app-record.txt",
        "01-pricing-availability.txt",
        "02-version-metadata.txt",
        "03-privacy-compliance.txt",
        "04-review.txt",
        "app-store-connect-entry-pack.json"
    )
    foreach ($requiredFile in $requiredFiles) {
        $path = Join-Path $entryPackPath $requiredFile
        if (-not (Test-Path $path -PathType Leaf)) {
            throw "Entry pack is missing $requiredFile."
        }
    }

    $entryPacket = Get-Content (Join-Path $entryPackPath "app-store-connect-entry-pack.json") -Raw | ConvertFrom-Json
    if ($entryPacket.app.bundleId -ne "com.snaptable.reminder") {
        throw "Entry packet bundle id must be com.snaptable.reminder."
    }
    if ($entryPacket.app.name -ne "SnapTable Reminder") {
        throw "Entry packet app name must be SnapTable Reminder."
    }
    if ([string]::IsNullOrWhiteSpace([string]$entryPacket.urls.privacyPolicyUrl) -or [string]::IsNullOrWhiteSpace([string]$entryPacket.urls.supportUrl)) {
        throw "Entry packet must include privacy and support URLs."
    }

    return $entryPacket
}

function Test-ScreenshotArchive($screenshotArchivePath) {
    if (-not (Test-Path $screenshotArchivePath -PathType Container)) {
        throw "ScreenshotArchiveDirectory does not exist: $screenshotArchivePath"
    }

    $summaryPath = Join-Path $screenshotArchivePath "release-readiness-artifacts-summary.md"
    $jsonPath = Join-Path $screenshotArchivePath "release-readiness-artifacts.json"
    if (-not (Test-Path $summaryPath -PathType Leaf)) {
        throw "Screenshot archive is missing release-readiness-artifacts-summary.md."
    }
    if (-not (Test-Path $jsonPath -PathType Leaf)) {
        throw "Screenshot archive is missing release-readiness-artifacts.json."
    }
    $evidence = Get-Content $jsonPath -Raw | ConvertFrom-Json
    if ([int]$evidence.fastlaneScreenshotCount -ne 4 -or [int]$evidence.rawScreenshotCount -ne 4 -or [int]$evidence.pngCount -ne 8) {
        throw "Release Readiness artifact evidence must record 4 Fastlane screenshots, 4 raw screenshots, and 8 PNGs."
    }

    $expectedWidth = 1320
    $expectedHeight = 2868
    $fastlaneRoot = Join-Path $screenshotArchivePath "fastlane-screenshots\en-US"
    $rawRoot = Join-Path $screenshotArchivePath "app-store-screenshots"
    $expectedFastlaneFiles = @(
        "01-Capture.png",
        "02-Records.png",
        "03-Dashboard.png",
        "04-Settings.png"
    )

    $fastlaneMetadata = @()
    foreach ($fileName in $expectedFastlaneFiles) {
        $path = Join-Path $fastlaneRoot $fileName
        if (-not (Test-Path $path -PathType Leaf)) {
            throw "Missing Fastlane screenshot: $fileName"
        }
        $metadata = Read-PngMetadata $path
        if ($metadata.Width -ne $expectedWidth -or $metadata.Height -ne $expectedHeight) {
            throw "Screenshot $fileName must be ${expectedWidth}x${expectedHeight}, but is $($metadata.Width)x$($metadata.Height)."
        }
        $fastlaneMetadata += $metadata
    }

    $rawPngs = @(Get-ChildItem -LiteralPath $rawRoot -Recurse -Filter *.png -File | Sort-Object FullName)
    if ($rawPngs.Count -ne 4) {
        throw "Expected 4 raw App Store screenshots, found $($rawPngs.Count)."
    }
    $rawMetadata = @()
    foreach ($rawPng in $rawPngs) {
        $metadata = Read-PngMetadata $rawPng.FullName
        if ($metadata.Width -ne $expectedWidth -or $metadata.Height -ne $expectedHeight) {
            throw "Raw screenshot $($rawPng.Name) must be ${expectedWidth}x${expectedHeight}, but is $($metadata.Width)x$($metadata.Height)."
        }
        $rawMetadata += $metadata
    }

    [pscustomobject]@{
        Evidence = $evidence
        FastlaneFiles = $fastlaneMetadata
        RawFiles = $rawMetadata
        SummaryPath = $summaryPath
        JsonPath = $jsonPath
    }
}

function Write-PacketReadme($path, $entryPacket, $screenshotEvidence, $outputRoot) {
    $generatedAt = [DateTimeOffset]::UtcNow.ToString("o")
    $lines = New-Object "System.Collections.Generic.List[string]"
    $lines.Add("# SnapTable Reminder App Store Submission Packet") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("Generated at: $generatedAt") | Out-Null
    $lines.Add("App: $($entryPacket.app.name)") | Out-Null
    $lines.Add("Bundle ID: $($entryPacket.app.bundleId)") | Out-Null
    $lines.Add("Privacy URL: $($entryPacket.urls.privacyPolicyUrl)") | Out-Null
    $lines.Add("Support URL: $($entryPacket.urls.supportUrl)") | Out-Null
    $lines.Add("Output directory: $outputRoot") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("## Contents") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add('- `01-app-store-connect-entry-pack/`: paste-ready public App Store Connect fields.') | Out-Null
    $lines.Add('- `02-fastlane-screenshots/en-US/`: four Fastlane screenshot files for upload.') | Out-Null
    $lines.Add('- `03-raw-screenshots/`: four raw XCTest screenshot exports.') | Out-Null
    $lines.Add('- `04-release-readiness-evidence/`: Release Readiness artifact summary and JSON evidence.') | Out-Null
    $lines.Add('- `app-store-submission-packet.json`: machine-readable packet summary.') | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("## Boundaries") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("- Do not add private Apple keys, certificates, provisioning profiles, passwords, banking/tax records, identity documents, or App Review contact details to this packet.") | Out-Null
    $lines.Add("- Version 1 availability excludes China mainland.") | Out-Null
    $lines.Add("- Version 1 is paid upfront, local-only, no backend, no analytics, and no tracking.") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("## Next Use") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("Use this packet when filling App Store Connect metadata and uploading screenshots after Apple account, API key, signing, and review-contact materials are ready.") | Out-Null
    $lines.Add("Fastlane screenshot count: $($screenshotEvidence.FastlaneFiles.Count)") | Out-Null
    $lines.Add("Raw screenshot count: $($screenshotEvidence.RawFiles.Count)") | Out-Null

    Set-Content -Path $path -Encoding UTF8 -Value ($lines -join [Environment]::NewLine)
}

function Write-PacketJson($path, $entryPacket, $screenshotEvidence, $outputRoot) {
    $record = [ordered]@{
        schemaVersion = 1
        generatedAt = [DateTimeOffset]::UtcNow.ToString("o")
        appName = $entryPacket.app.name
        bundleId = $entryPacket.app.bundleId
        sku = $entryPacket.app.sku
        primaryLanguage = $entryPacket.app.primaryLanguage
        category = $entryPacket.app.category
        privacyPolicyUrl = $entryPacket.urls.privacyPolicyUrl
        supportUrl = $entryPacket.urls.supportUrl
        releaseReadinessRunUrl = $screenshotEvidence.Evidence.runUrl
        releaseReadinessRunId = $screenshotEvidence.Evidence.runId
        outputDirectory = $outputRoot
        fastlaneScreenshotCount = $screenshotEvidence.FastlaneFiles.Count
        rawScreenshotCount = $screenshotEvidence.RawFiles.Count
        fastlaneScreenshots = @($screenshotEvidence.FastlaneFiles | ForEach-Object { $_.FileName })
        rawScreenshots = @($screenshotEvidence.RawFiles | ForEach-Object { $_.FileName })
    }
    $record | ConvertTo-Json -Depth 5 | Set-Content -Path $path -Encoding UTF8
}

if ([string]::IsNullOrWhiteSpace($EntryPackDirectory)) {
    $EntryPackDirectory = "SnapTableReminder-AppStoreConnect-EntryPack"
}
if ([string]::IsNullOrWhiteSpace($ScreenshotArchiveDirectory)) {
    $ScreenshotArchiveDirectory = "SnapTableReminder-ReleaseReadiness-Artifacts"
}
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = "SnapTableReminder-AppStoreSubmissionPacket"
}

$entryPackPath = Resolve-FullPath $EntryPackDirectory "SnapTableReminder-AppStoreConnect-EntryPack"
$screenshotArchivePath = Resolve-FullPath $ScreenshotArchiveDirectory "SnapTableReminder-ReleaseReadiness-Artifacts"
$outputRoot = Resolve-FullPath $OutputDirectory "SnapTableReminder-AppStoreSubmissionPacket"

Assert-NoPrivateAppleFiles $entryPackPath
Assert-NoPrivateAppleFiles $screenshotArchivePath
$entryPacket = Test-EntryPack $entryPackPath
$screenshotEvidence = Test-ScreenshotArchive $screenshotArchivePath

Reset-OutputDirectory $outputRoot
Assert-NoPrivateAppleFiles $outputRoot

$entryPackOutput = Reset-ChildDirectory $outputRoot "01-app-store-connect-entry-pack"
Copy-DirectoryContents $entryPackPath $entryPackOutput

$fastlaneOutput = Reset-ChildDirectory $outputRoot "02-fastlane-screenshots"
Copy-DirectoryContents (Join-Path $screenshotArchivePath "fastlane-screenshots") $fastlaneOutput

$rawOutput = Reset-ChildDirectory $outputRoot "03-raw-screenshots"
Copy-DirectoryContents (Join-Path $screenshotArchivePath "app-store-screenshots") $rawOutput

$evidenceOutput = Reset-ChildDirectory $outputRoot "04-release-readiness-evidence"
Copy-Item -LiteralPath (Join-Path $screenshotArchivePath "release-readiness-artifacts-summary.md") -Destination $evidenceOutput -Force
Copy-Item -LiteralPath (Join-Path $screenshotArchivePath "release-readiness-artifacts.json") -Destination $evidenceOutput -Force

Write-PacketReadme (Join-Path $outputRoot "SUBMISSION-PACKET-README.md") $entryPacket $screenshotEvidence $outputRoot
Write-PacketJson (Join-Path $outputRoot "app-store-submission-packet.json") $entryPacket $screenshotEvidence $outputRoot

Assert-NoPrivateAppleFiles $outputRoot

Write-Section "App Store submission packet"
Write-Host "submissionPacket=$outputRoot"
Write-Host "bundleId=$($entryPacket.app.bundleId)"
Write-Host "fastlaneScreenshots=$($screenshotEvidence.FastlaneFiles.Count)"
Write-Host "rawScreenshots=$($screenshotEvidence.RawFiles.Count)"
