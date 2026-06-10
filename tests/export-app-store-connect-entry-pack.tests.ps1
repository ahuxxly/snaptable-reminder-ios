$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$scriptPath = Join-Path $repoRoot "scripts\export-app-store-connect-entry-pack.ps1"
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

function Invoke-Exporter($arguments) {
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

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("snaptable-entry-pack-tests-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempRoot | Out-Null

try {
    Run-Test "exports paste-ready App Store Connect entry packet" {
        $target = Join-Path $tempRoot "entry-pack"
        $result = Invoke-Exporter @(
            "-OutputDirectory", $target,
            "-Owner", "test-owner",
            "-RepoName", "snaptable-reminder-ios"
        )

        Assert-True ($result.ExitCode -eq 0) "expected exit 0, got $($result.ExitCode): $($result.Output)"
        foreach ($fileName in @(
            "README.md",
            "00-app-record.txt",
            "01-pricing-availability.txt",
            "02-version-metadata.txt",
            "03-privacy-compliance.txt",
            "04-review.txt",
            "app-store-connect-entry-pack.json"
        )) {
            Assert-True (Test-Path (Join-Path $target $fileName)) "missing exported file $fileName"
        }

        $appRecord = Get-Content (Join-Path $target "00-app-record.txt") -Raw
        Assert-Contains $appRecord "SnapTable Reminder" "app record should include app name"
        Assert-Contains $appRecord "com.snaptable.reminder" "app record should include bundle id"
        Assert-Contains $appRecord "SNAPTABLE-REMINDER-IOS-V1" "app record should include SKU"
        Assert-Contains $appRecord "Productivity" "app record should include category"

        $metadata = Get-Content (Join-Path $target "02-version-metadata.txt") -Raw
        Assert-Contains $metadata "Screenshots to tables" "metadata should include subtitle"
        Assert-Contains $metadata "SnapTable Reminder is a local-first utility" "metadata should include description"
        Assert-Contains $metadata "screenshot OCR,doc scanner,CSV" "metadata should include keywords"
        Assert-Contains $metadata "https://test-owner.github.io/snaptable-reminder-ios/privacy.html" "metadata should include generated privacy URL"
        Assert-Contains $metadata "https://test-owner.github.io/snaptable-reminder-ios/support.html" "metadata should include generated support URL"

        $privacy = Get-Content (Join-Path $target "03-privacy-compliance.txt") -Raw
        Assert-Contains $privacy "Data collected: none" "privacy packet should include no-data answer"
        Assert-Contains $privacy "Tracking: No" "privacy packet should include tracking answer"
        Assert-Contains $privacy "ITSAppUsesNonExemptEncryption: false" "compliance packet should include export setting"
        Assert-Contains $privacy "EU DSA trader status decision required" "compliance packet should include DSA gate"
        Assert-Contains $privacy "Likely 4+" "compliance packet should include age rating draft"

        $review = Get-Content (Join-Path $target "04-review.txt") -Raw
        Assert-Contains $review "Text recognition runs on device" "review packet should include reviewer notes"
        Assert-Contains $review "No test account required" "review packet should include account answer"
        Assert-Contains $review "Tuition payment notice" "review packet should include demo text"
    }

    Run-Test "exports structured JSON from the same source fields" {
        $target = Join-Path $tempRoot "json-pack"
        $result = Invoke-Exporter @(
            "-OutputDirectory", $target,
            "-Owner", "json-owner",
            "-RepoName", "json-repo"
        )
        Assert-True ($result.ExitCode -eq 0) "expected exit 0, got $($result.ExitCode): $($result.Output)"

        $packet = Get-Content (Join-Path $target "app-store-connect-entry-pack.json") -Raw | ConvertFrom-Json
        Assert-True ($packet.app.name -eq "SnapTable Reminder") "JSON app name should match source"
        Assert-True ($packet.app.bundleId -eq "com.snaptable.reminder") "JSON bundle id should match source"
        Assert-True ($packet.urls.privacyPolicyUrl -eq "https://json-owner.github.io/json-repo/privacy.html") "JSON privacy URL should use owner and repo"
        Assert-True ($packet.availability.excludeCountriesOrRegions -contains "China mainland") "JSON availability should exclude China mainland"
        Assert-True ($packet.privacy.tracking -eq $false) "JSON privacy should preserve tracking=false"
        Assert-True ($packet.review.testAccountRequired -eq $false) "JSON review should preserve testAccountRequired=false"
        Assert-True ($packet.sources -contains "docs/app-store/app-store-fields.json") "JSON packet should cite source fields file"
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
    Write-Host "export-app-store-connect-entry-pack tests failed:"
    foreach ($failure in $failures) {
        Write-Host "- $failure"
    }
    exit 1
}

Write-Host ""
Write-Host "export-app-store-connect-entry-pack tests passed."
