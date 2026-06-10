$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$scriptPath = Join-Path $repoRoot "scripts\archive-release-readiness-artifacts.ps1"
$failures = New-Object "System.Collections.Generic.List[string]"

function Assert-True($condition, $message) {
    if (-not $condition) {
        throw $message
    }
}

function Assert-Contains($text, $expected, $message) {
    if ($text.IndexOf($expected, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) {
        throw $message
    }
}

function Invoke-ArchiveScript($arguments) {
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath @arguments 2>&1 | Out-String
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    [pscustomobject]@{
        ExitCode = $exitCode
        Output = $output
    }
}

function Run-Test($name, [scriptblock]$body) {
    try {
        & $body
        Write-Host "[PASS] $name"
    } catch {
        $failures.Add("$name`: $($_.Exception.Message)") | Out-Null
        Write-Host "[FAIL] $name"
        Write-Host $_.Exception.Message
    }
}

function Write-FakePng($path, $width = 1320, $height = 2868) {
    $parent = Split-Path -Parent $path
    if (-not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    $bytes = New-Object byte[] 33
    [byte[]]$signature = 137, 80, 78, 71, 13, 10, 26, 10
    [Array]::Copy($signature, 0, $bytes, 0, $signature.Length)
    [byte[]]$ihdr = 73, 72, 68, 82
    [Array]::Copy($ihdr, 0, $bytes, 12, $ihdr.Length)
    $bytes[16] = [byte](($width -shr 24) -band 255)
    $bytes[17] = [byte](($width -shr 16) -band 255)
    $bytes[18] = [byte](($width -shr 8) -band 255)
    $bytes[19] = [byte]($width -band 255)
    $bytes[20] = [byte](($height -shr 24) -band 255)
    $bytes[21] = [byte](($height -shr 16) -band 255)
    $bytes[22] = [byte](($height -shr 8) -band 255)
    $bytes[23] = [byte]($height -band 255)
    $bytes[24] = 8
    $bytes[25] = 2
    [System.IO.File]::WriteAllBytes($path, $bytes)
}

function New-ReleaseReadinessArtifactTree($root, $width = 1320, $height = 2868) {
    foreach ($name in @("01-Capture.png", "02-Records.png", "03-Dashboard.png", "04-Settings.png")) {
        Write-FakePng (Join-Path $root "fastlane-screenshots\en-US\$name") $width $height
    }
    foreach ($name in @("raw-capture.png", "raw-records.png", "raw-dashboard.png", "raw-settings.png")) {
        Write-FakePng (Join-Path $root "app-store-screenshots\$name") $width $height
    }
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("snaptable-readiness-artifacts-tests-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempRoot | Out-Null

try {
    Run-Test "validates existing Release Readiness artifacts and writes summary" {
        $source = Join-Path $tempRoot "valid-source"
        $output = Join-Path $tempRoot "valid-output"
        New-ReleaseReadinessArtifactTree $source

        $result = Invoke-ArchiveScript @(
            "-SourceDirectory", $source,
            "-OutputDirectory", $output,
            "-RepoFullName", "owner/repo",
            "-RunId", "123456789",
            "-SkipDownload"
        )

        Assert-True ($result.ExitCode -eq 0) "expected exit 0, got $($result.ExitCode): $($result.Output)"
        Assert-Contains $result.Output "pngCount=8" "console output should summarize verified PNG count"
        $summaryPath = Join-Path $output "release-readiness-artifacts-summary.md"
        $jsonPath = Join-Path $output "release-readiness-artifacts.json"
        Assert-True (Test-Path $summaryPath) "summary markdown should be written"
        Assert-True (Test-Path $jsonPath) "summary JSON should be written"
        $summary = Get-Content $summaryPath -Raw
        Assert-Contains $summary "Release Readiness Artifacts" "summary should have a clear title"
        Assert-Contains $summary "https://github.com/owner/repo/actions/runs/123456789" "summary should link the run"
        Assert-Contains $summary "8 PNGs" "summary should include the total PNG count"
        Assert-Contains $summary "1320x2868" "summary should include screenshot dimensions"
        $json = Get-Content $jsonPath -Raw | ConvertFrom-Json
        Assert-True ($json.pngCount -eq 8) "JSON should record eight PNGs"
        Assert-True ($json.fastlaneScreenshotCount -eq 4) "JSON should record four Fastlane screenshots"
        Assert-True ($json.rawScreenshotCount -eq 4) "JSON should record four raw screenshots"
    }

    Run-Test "rejects missing Fastlane screenshot" {
        $source = Join-Path $tempRoot "missing-fastlane"
        $output = Join-Path $tempRoot "missing-fastlane-output"
        New-ReleaseReadinessArtifactTree $source
        Remove-Item -LiteralPath (Join-Path $source "fastlane-screenshots\en-US\04-Settings.png") -Force

        $result = Invoke-ArchiveScript @(
            "-SourceDirectory", $source,
            "-OutputDirectory", $output,
            "-RunId", "123456789",
            "-SkipDownload"
        )

        Assert-True ($result.ExitCode -ne 0) "expected nonzero exit when a named Fastlane screenshot is missing"
        Assert-Contains $result.Output "04-Settings.png" "failure should name the missing screenshot"
    }

    Run-Test "rejects wrong screenshot dimensions" {
        $source = Join-Path $tempRoot "wrong-dimensions"
        $output = Join-Path $tempRoot "wrong-dimensions-output"
        New-ReleaseReadinessArtifactTree $source
        Write-FakePng (Join-Path $source "fastlane-screenshots\en-US\03-Dashboard.png") 1170 2532

        $result = Invoke-ArchiveScript @(
            "-SourceDirectory", $source,
            "-OutputDirectory", $output,
            "-RunId", "123456789",
            "-SkipDownload"
        )

        Assert-True ($result.ExitCode -ne 0) "expected nonzero exit for wrong screenshot dimensions"
        Assert-Contains $result.Output "03-Dashboard.png" "failure should name the screenshot with wrong dimensions"
        Assert-Contains $result.Output "1320x2868" "failure should mention required dimensions"
    }
} finally {
    $resolvedTempRoot = [System.IO.Path]::GetFullPath($tempRoot)
    $resolvedTempBase = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
    if ($resolvedTempRoot.StartsWith($resolvedTempBase, [System.StringComparison]::OrdinalIgnoreCase)) {
        Remove-Item -LiteralPath $resolvedTempRoot -Recurse -Force
    }
}

if ($failures.Count -gt 0) {
    Write-Host ""
    Write-Host "archive-release-readiness-artifacts tests failed:"
    foreach ($failure in $failures) {
        Write-Host "- $failure"
    }
    exit 1
}

Write-Host ""
Write-Host "archive-release-readiness-artifacts tests passed."
