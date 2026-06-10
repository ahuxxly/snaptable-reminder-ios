$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$scriptPath = Join-Path $repoRoot "scripts\build-app-store-submission-packet.ps1"
$entryPackExporterPath = Join-Path $repoRoot "scripts\export-app-store-connect-entry-pack.ps1"
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

function Invoke-PacketScript($arguments) {
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

function New-ScreenshotArchive($root, $width = 1320, $height = 2868) {
    foreach ($name in @("01-Capture.png", "02-Records.png", "03-Dashboard.png", "04-Settings.png")) {
        Write-FakePng (Join-Path $root "fastlane-screenshots\en-US\$name") $width $height
    }
    foreach ($name in @("raw-capture.png", "raw-records.png", "raw-dashboard.png", "raw-settings.png")) {
        Write-FakePng (Join-Path $root "app-store-screenshots\$name") $width $height
    }
    Set-Content -Path (Join-Path $root "release-readiness-artifacts-summary.md") -Encoding UTF8 -Value @"
# Release Readiness Artifacts

Run: https://github.com/owner/repo/actions/runs/123456789
Verified 8 PNGs at 1320x2868.
"@
    Set-Content -Path (Join-Path $root "release-readiness-artifacts.json") -Encoding UTF8 -Value @"
{
  "schemaVersion": 1,
  "repoFullName": "owner/repo",
  "runId": "123456789",
  "runUrl": "https://github.com/owner/repo/actions/runs/123456789",
  "headSha": "abc123",
  "pngCount": 8,
  "fastlaneScreenshotCount": 4,
  "rawScreenshotCount": 4
}
"@
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("snaptable-submission-packet-tests-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempRoot | Out-Null

try {
    Run-Test "builds public App Store submission packet from entry pack and verified screenshots" {
        $entryPack = Join-Path $tempRoot "entry-pack"
        $screenshots = Join-Path $tempRoot "screenshots"
        $output = Join-Path $tempRoot "submission-packet"
        & powershell -NoProfile -ExecutionPolicy Bypass -File $entryPackExporterPath -OutputDirectory $entryPack -Owner "owner" -RepoName "repo" | Out-Null
        Assert-True ($LASTEXITCODE -eq 0) "entry pack export failed"
        New-ScreenshotArchive $screenshots

        $result = Invoke-PacketScript @(
            "-EntryPackDirectory", $entryPack,
            "-ScreenshotArchiveDirectory", $screenshots,
            "-OutputDirectory", $output
        )

        Assert-True ($result.ExitCode -eq 0) "expected exit 0, got $($result.ExitCode): $($result.Output)"
        Assert-Contains $result.Output "submissionPacket" "console output should name the submission packet"
        Assert-True (Test-Path (Join-Path $output "SUBMISSION-PACKET-README.md")) "packet README should be written"
        Assert-True (Test-Path (Join-Path $output "app-store-submission-packet.json")) "packet JSON should be written"
        Assert-True (Test-Path (Join-Path $output "01-app-store-connect-entry-pack\app-store-connect-entry-pack.json")) "entry packet should be copied"
        Assert-True (Test-Path (Join-Path $output "02-fastlane-screenshots\en-US\01-Capture.png")) "Fastlane screenshots should be copied"
        Assert-True (Test-Path (Join-Path $output "03-raw-screenshots\raw-capture.png")) "raw screenshots should be copied"
        Assert-True (Test-Path (Join-Path $output "04-release-readiness-evidence\release-readiness-artifacts-summary.md")) "release readiness summary should be copied"

        $readme = Get-Content (Join-Path $output "SUBMISSION-PACKET-README.md") -Raw
        Assert-Contains $readme "Do not add private Apple keys" "README should warn against private files"
        Assert-Contains $readme "SnapTable Reminder" "README should include app name"
        Assert-Contains $readme "China mainland" "README should include availability boundary"
        Assert-Contains $readme '`01-app-store-connect-entry-pack/`' "README should include the entry-pack directory as literal markdown code"
        Assert-Contains $readme '`02-fastlane-screenshots/en-US/`' "README should include the Fastlane screenshot directory as literal markdown code"
        Assert-Contains $readme '`03-raw-screenshots/`' "README should include the raw screenshot directory as literal markdown code"
        Assert-Contains $readme '`04-release-readiness-evidence/`' "README should include the evidence directory as literal markdown code"
        Assert-Contains $readme '`app-store-submission-packet.json`' "README should include the packet JSON as literal markdown code"
        Assert-True ($readme -notmatch '[\x00-\x08\x0B\x0C\x0E-\x1F]') "README should not contain control characters"
        $json = Get-Content (Join-Path $output "app-store-submission-packet.json") -Raw | ConvertFrom-Json
        Assert-True ($json.bundleId -eq "com.snaptable.reminder") "packet JSON should record bundle id"
        Assert-True ($json.fastlaneScreenshotCount -eq 4) "packet JSON should record Fastlane screenshot count"
        Assert-True ($json.rawScreenshotCount -eq 4) "packet JSON should record raw screenshot count"
    }

    Run-Test "rejects screenshot archives missing verification summary" {
        $entryPack = Join-Path $tempRoot "entry-pack-no-summary"
        $screenshots = Join-Path $tempRoot "screenshots-no-summary"
        $output = Join-Path $tempRoot "submission-no-summary"
        & powershell -NoProfile -ExecutionPolicy Bypass -File $entryPackExporterPath -OutputDirectory $entryPack | Out-Null
        Assert-True ($LASTEXITCODE -eq 0) "entry pack export failed"
        New-ScreenshotArchive $screenshots
        Remove-Item -LiteralPath (Join-Path $screenshots "release-readiness-artifacts.json") -Force

        $result = Invoke-PacketScript @(
            "-EntryPackDirectory", $entryPack,
            "-ScreenshotArchiveDirectory", $screenshots,
            "-OutputDirectory", $output
        )

        Assert-True ($result.ExitCode -ne 0) "expected nonzero exit without release readiness JSON"
        Assert-Contains $result.Output "release-readiness-artifacts.json" "failure should name the missing verification JSON"
    }

    Run-Test "rejects private Apple files inside the submission packet source folders" {
        $entryPack = Join-Path $tempRoot "entry-pack-private-file"
        $screenshots = Join-Path $tempRoot "screenshots-private-file"
        $output = Join-Path $tempRoot "submission-private-file"
        & powershell -NoProfile -ExecutionPolicy Bypass -File $entryPackExporterPath -OutputDirectory $entryPack | Out-Null
        Assert-True ($LASTEXITCODE -eq 0) "entry pack export failed"
        New-ScreenshotArchive $screenshots
        Set-Content -Path (Join-Path $entryPack "AuthKey_TEST.p8") -Encoding UTF8 -Value "secret"

        $result = Invoke-PacketScript @(
            "-EntryPackDirectory", $entryPack,
            "-ScreenshotArchiveDirectory", $screenshots,
            "-OutputDirectory", $output
        )

        Assert-True ($result.ExitCode -ne 0) "expected nonzero exit when source contains private Apple key"
        Assert-Contains $result.Output ".p8" "failure should name the private file type"
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
    Write-Host "build-app-store-submission-packet tests failed:"
    foreach ($failure in $failures) {
        Write-Host "- $failure"
    }
    exit 1
}

Write-Host ""
Write-Host "build-app-store-submission-packet tests passed."
