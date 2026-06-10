param(
    [string]$RepoFullName = "ahuxxly/snaptable-reminder-ios",
    [string]$RunId = "",
    [string]$OutputDirectory = "",
    [string]$SourceDirectory = "",
    [switch]$SkipDownload
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

function Reset-ChildDirectory($parent, $leafName) {
    $target = Join-Path $parent $leafName
    Assert-ChildPath $parent $target
    if (Test-Path $target) {
        Remove-Item -LiteralPath $target -Recurse -Force
    }
    New-Item -ItemType Directory -Path $target -Force | Out-Null
    return $target
}

function Copy-ArtifactDirectory($sourceRoot, $outputRoot, $artifactName) {
    $source = Join-Path $sourceRoot $artifactName
    if (-not (Test-Path $source -PathType Container)) {
        throw "Missing artifact directory: $source"
    }

    $target = Reset-ChildDirectory $outputRoot $artifactName
    Copy-Item -Path (Join-Path $source "*") -Destination $target -Recurse -Force
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
        Path = [System.IO.Path]::GetFullPath($path)
        FileName = [System.IO.Path]::GetFileName($path)
        Width = [int]$width
        Height = [int]$height
        ColorType = [int]$colorType
        Bytes = [int64]$bytes.Length
    }
}

function Get-LatestSuccessfulReleaseReadinessRun($ghPath, $repoFullName) {
    $runJson = & $ghPath run list --repo $repoFullName --workflow release-readiness.yml --branch master --limit 20 --json databaseId,status,conclusion,url,headSha,displayTitle
    if ($LASTEXITCODE -ne 0) {
        throw "Could not list Release Readiness workflow runs for $repoFullName."
    }

    $runs = @($runJson | ConvertFrom-Json)
    $run = $runs | Where-Object { $_.status -eq "completed" -and $_.conclusion -eq "success" } | Select-Object -First 1
    if ($null -eq $run) {
        throw "No successful Release Readiness run was found on master."
    }
    return $run
}

function Download-ReleaseReadinessArtifacts($ghPath, $repoFullName, $runId, $outputRoot) {
    foreach ($artifactName in @("fastlane-screenshots", "app-store-screenshots")) {
        $artifactDirectory = Reset-ChildDirectory $outputRoot $artifactName
        & $ghPath run download $runId --repo $repoFullName --name $artifactName --dir $artifactDirectory
        if ($LASTEXITCODE -ne 0) {
            throw "Could not download artifact '$artifactName' from Release Readiness run $runId."
        }
    }
}

function Test-ReleaseReadinessArtifacts($outputRoot) {
    $expectedWidth = 1320
    $expectedHeight = 2868
    $fastlaneRoot = Join-Path $outputRoot "fastlane-screenshots\en-US"
    $rawRoot = Join-Path $outputRoot "app-store-screenshots"

    if (-not (Test-Path $fastlaneRoot -PathType Container)) {
        throw "Missing Fastlane screenshot directory: $fastlaneRoot"
    }
    if (-not (Test-Path $rawRoot -PathType Container)) {
        throw "Missing raw App Store screenshot directory: $rawRoot"
    }

    $expectedFastlaneFiles = @(
        "01-Capture.png",
        "02-Records.png",
        "03-Dashboard.png",
        "04-Settings.png"
    )
    $fastlanePngs = @()
    foreach ($fileName in $expectedFastlaneFiles) {
        $path = Join-Path $fastlaneRoot $fileName
        if (-not (Test-Path $path -PathType Leaf)) {
            throw "Missing Fastlane screenshot: $fileName"
        }
        $fastlanePngs += Get-Item -LiteralPath $path
    }

    $rawPngs = @(Get-ChildItem -LiteralPath $rawRoot -Recurse -Filter *.png -File | Sort-Object FullName)
    if ($rawPngs.Count -ne 4) {
        throw "Expected 4 raw App Store screenshots, found $($rawPngs.Count)."
    }

    $allPngs = @($fastlanePngs + $rawPngs)
    $metadata = @()
    foreach ($png in $allPngs) {
        $pngMetadata = Read-PngMetadata $png.FullName
        if ($pngMetadata.Width -ne $expectedWidth -or $pngMetadata.Height -ne $expectedHeight) {
            throw "Screenshot $($png.Name) must be ${expectedWidth}x${expectedHeight}, but is $($pngMetadata.Width)x$($pngMetadata.Height)."
        }
        $metadata += $pngMetadata
    }

    [pscustomobject]@{
        ExpectedWidth = $expectedWidth
        ExpectedHeight = $expectedHeight
        FastlaneScreenshotCount = $fastlanePngs.Count
        RawScreenshotCount = $rawPngs.Count
        PngCount = $allPngs.Count
        Files = $metadata
    }
}

function Write-ArchiveSummary($outputRoot, $repoFullName, $runId, $runUrl, $headSha, $sourceDirectory, $verification) {
    $summaryPath = Join-Path $outputRoot "release-readiness-artifacts-summary.md"
    $jsonPath = Join-Path $outputRoot "release-readiness-artifacts.json"
    $generatedAt = [DateTimeOffset]::UtcNow.ToString("o")

    $record = [ordered]@{
        schemaVersion = 1
        generatedAt = $generatedAt
        repoFullName = $repoFullName
        runId = $RunId
        runUrl = $runUrl
        headSha = $headSha
        sourceDirectory = $sourceDirectory
        outputDirectory = $outputRoot
        requiredDimensions = [ordered]@{
            width = $verification.ExpectedWidth
            height = $verification.ExpectedHeight
        }
        pngCount = $verification.PngCount
        fastlaneScreenshotCount = $verification.FastlaneScreenshotCount
        rawScreenshotCount = $verification.RawScreenshotCount
        files = @($verification.Files)
    }

    $record | ConvertTo-Json -Depth 7 | Set-Content -Path $jsonPath -Encoding UTF8

    $lines = New-Object "System.Collections.Generic.List[string]"
    $lines.Add("# Release Readiness Artifacts") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("Generated at: $generatedAt") | Out-Null
    $lines.Add("Repository: $repoFullName") | Out-Null
    if (-not [string]::IsNullOrWhiteSpace($runId)) {
        $lines.Add("Run: $runUrl") | Out-Null
        $lines.Add("Run id: $runId") | Out-Null
    }
    if (-not [string]::IsNullOrWhiteSpace($headSha)) {
        $lines.Add("Commit: $headSha") | Out-Null
    }
    if (-not [string]::IsNullOrWhiteSpace($sourceDirectory)) {
        $lines.Add("Source directory: $sourceDirectory") | Out-Null
    }
    $lines.Add("Output directory: $outputRoot") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("Verified $($verification.PngCount) PNGs at $($verification.ExpectedWidth)x$($verification.ExpectedHeight).") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("- Fastlane screenshots: $($verification.FastlaneScreenshotCount)") | Out-Null
    $lines.Add("- Raw App Store screenshots: $($verification.RawScreenshotCount)") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("## Files") | Out-Null
    foreach ($file in $verification.Files) {
        $relativePath = $file.Path
        if ($relativePath.StartsWith($outputRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            $relativePath = $relativePath.Substring($outputRoot.Length).TrimStart("\", "/")
        }
        $lines.Add("- $relativePath ($($file.Width)x$($file.Height), $($file.Bytes) bytes)") | Out-Null
    }

    Set-Content -Path $summaryPath -Encoding UTF8 -Value ($lines -join [Environment]::NewLine)
}

if ($SkipDownload -and [string]::IsNullOrWhiteSpace($SourceDirectory)) {
    throw "SourceDirectory is required when SkipDownload is set."
}

$ghPath = $null
$runUrl = ""
$headSha = ""
if (-not $SkipDownload) {
    $ghPath = Resolve-GitHubCli
    if ([string]::IsNullOrWhiteSpace($RunId)) {
        $latestRun = Get-LatestSuccessfulReleaseReadinessRun $ghPath $RepoFullName
        $RunId = [string]$latestRun.databaseId
        $runUrl = [string]$latestRun.url
        $headSha = [string]$latestRun.headSha
    } else {
        $runUrl = "https://github.com/$RepoFullName/actions/runs/$RunId"
    }
}

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    if (-not [string]::IsNullOrWhiteSpace($RunId)) {
        $OutputDirectory = "SnapTableReminder-ReleaseReadiness-$RunId"
    } else {
        $OutputDirectory = "SnapTableReminder-ReleaseReadiness-Artifacts"
    }
}
$outputRoot = Resolve-FullPath $OutputDirectory "SnapTableReminder-ReleaseReadiness-Artifacts"
New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null

if ($SkipDownload) {
    $sourceRoot = Resolve-FullPath $SourceDirectory "SnapTableReminder-ReleaseReadiness-Artifacts"
    Copy-ArtifactDirectory $sourceRoot $outputRoot "fastlane-screenshots"
    Copy-ArtifactDirectory $sourceRoot $outputRoot "app-store-screenshots"
} else {
    Download-ReleaseReadinessArtifacts $ghPath $RepoFullName $RunId $outputRoot
}

$verification = Test-ReleaseReadinessArtifacts $outputRoot
if ([string]::IsNullOrWhiteSpace($runUrl) -and -not [string]::IsNullOrWhiteSpace($RunId)) {
    $runUrl = "https://github.com/$RepoFullName/actions/runs/$RunId"
}
Write-ArchiveSummary $outputRoot $RepoFullName $RunId $runUrl $headSha $SourceDirectory $verification

Write-Section "Release Readiness artifacts"
Write-Host "repo=$RepoFullName"
Write-Host "runId=$RunId"
Write-Host "output=$outputRoot"
Write-Host "pngCount=$($verification.PngCount)"
Write-Host "fastlaneScreenshots=$($verification.FastlaneScreenshotCount)"
Write-Host "rawScreenshots=$($verification.RawScreenshotCount)"
