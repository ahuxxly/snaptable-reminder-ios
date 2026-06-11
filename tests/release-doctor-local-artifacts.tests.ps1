$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$releaseDoctorPath = Join-Path $repoRoot "scripts\release-doctor.ps1"
$entryPackExporterPath = Join-Path $repoRoot "scripts\export-app-store-connect-entry-pack.ps1"
$submissionPacketBuilderPath = Join-Path $repoRoot "scripts\build-app-store-submission-packet.ps1"
$materialsPrepPath = Join-Path $repoRoot "scripts\prepare-apple-materials-folder.ps1"
$recordSetupPath = Join-Path $repoRoot "scripts\record-app-store-connect-setup-evidence.ps1"
$recordEvidencePath = Join-Path $repoRoot "scripts\record-app-store-release-evidence.ps1"
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

function Invoke-ReleaseDoctor($arguments) {
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $releaseDoctorPath @arguments 2>&1 | Out-String
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

function New-CompleteMaterialsFolder($target) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $materialsPrepPath -OutputDirectory $target | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Could not prepare test materials folder."
    }

    Set-Content -Path (Join-Path $target "00-account\account-private-status.md") -Encoding UTF8 -Value @"
# Private Account Status

- Apple Developer Program: active
- Paid Apps Agreement: accepted
- Tax: complete
- Banking: complete
- App Store Connect app: com.snaptable.reminder created
"@
    Set-Content -Path (Join-Path $target "release-secrets.private.json") -Encoding UTF8 -Value @"
{
  "appStoreConnectUsername": "account@example.invalid",
  "appleDeveloperTeamId": "TEAM123456",
  "appStoreConnectApiKeyId": "TESTKEY123",
  "appStoreConnectApiIssuerId": "00000000-0000-0000-0000-000000000000",
  "appleDistributionCertificatePassword": "p12-password",
  "appleCodesignKeychainPassword": "temporary-keychain-password"
}
"@
    Set-Content -Path (Join-Path $target "01-app-store-connect-api-key\AuthKey_TESTKEY123.p8") -Encoding UTF8 -Value @"
-----BEGIN PRIVATE KEY-----
test-private-key
-----END PRIVATE KEY-----
"@
    [System.IO.File]::WriteAllBytes((Join-Path $target "02-signing\apple-distribution.p12"), [byte[]](1, 2, 3, 4))
    [System.IO.File]::WriteAllText((Join-Path $target "02-signing\app-store.mobileprovision"), "com.snaptable.reminder")
    Set-Content -Path (Join-Path $target "03-review-contact\review-contact.private.json") -Encoding UTF8 -Value @"
{
  "firstName": "App",
  "lastName": "Reviewer",
  "email": "reviewer@example.invalid",
  "phone": "+1 555 010 1000"
}
"@
    Set-Content -Path (Join-Path $target "04-eu-dsa\dsa-private-evidence.md") -Encoding UTF8 -Value @"
# Private EU DSA Evidence

- EU storefronts: included
- Trader status decision: completed
"@
}

function Add-CompleteReleaseEvidence($materials) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $recordEvidencePath `
        -MaterialsDirectory $materials `
        -AppStoreConnectAppId "1234567890" `
        -AppVersion "1.0" `
        -BuildNumber "1" `
        -MetadataWorkflowRunUrl "https://github.com/owner/repo/actions/runs/100" `
        -TestFlightWorkflowRunUrl "https://github.com/owner/repo/actions/runs/101" `
        -AppReviewWorkflowRunUrl "https://github.com/owner/repo/actions/runs/102" `
        -MetadataUploaded `
        -ScreenshotsUploaded `
        -ReviewCheckPassed `
        -TestFlightUploaded `
        -BuildProcessed `
        -AppReviewSubmitted `
        -AppStatus "Waiting for Review" | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Could not record test release evidence."
    }
}

function Add-CompleteSetupEvidence($materials) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $recordSetupPath `
        -MaterialsDirectory $materials `
        -AppStoreConnectAppId "1234567890" `
        -AppName "SnapTable Reminder" `
        -BundleId "com.snaptable.reminder" `
        -Sku "SNAPTABLE-REMINDER-IOS-V1" `
        -PrimaryLanguage "en-US" `
        -PrimaryCategory "Productivity" `
        -PriceCurrency "USD" `
        -PriceAmount "1.99" `
        -AvailabilityMode "selectedCountriesOrRegions" `
        -ExcludedCountriesOrRegions "China mainland" `
        -PrivacyPolicyUrl "https://ahuxxly.github.io/snaptable-reminder-ios/privacy.html" `
        -SupportUrl "https://ahuxxly.github.io/snaptable-reminder-ios/support.html" `
        -PrivacyAnswersCompleted `
        -AgeRatingCompleted `
        -ExportComplianceCompleted `
        -EuDsaTraderStatusCompleted | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Could not record test App Store Connect setup evidence."
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

function New-ScreenshotArchive($root) {
    foreach ($name in @("01-Capture.png", "02-Records.png", "03-Dashboard.png", "04-Settings.png")) {
        Write-FakePng (Join-Path $root "fastlane-screenshots\en-US\$name")
    }
    foreach ($name in @("raw-capture.png", "raw-records.png", "raw-dashboard.png", "raw-settings.png")) {
        Write-FakePng (Join-Path $root "app-store-screenshots\$name")
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

function New-CompleteSubmissionPacket($entryPack, $target) {
    $screenshots = Join-Path $tempRoot ("screenshots-" + [guid]::NewGuid().ToString("N"))
    New-ScreenshotArchive $screenshots
    & powershell -NoProfile -ExecutionPolicy Bypass -File $submissionPacketBuilderPath `
        -EntryPackDirectory $entryPack `
        -ScreenshotArchiveDirectory $screenshots `
        -OutputDirectory $target | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Could not build test App Store submission packet."
    }
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("snaptable-release-doctor-local-tests-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempRoot | Out-Null

try {
    Run-Test "local-only doctor accepts complete entry packet and materials folder" {
        $entryPack = Join-Path $tempRoot "entry-pack"
        $submissionPacket = Join-Path $tempRoot "submission-packet"
        $materials = Join-Path $tempRoot "materials"
        & powershell -NoProfile -ExecutionPolicy Bypass -File $entryPackExporterPath -OutputDirectory $entryPack | Out-Null
        Assert-True ($LASTEXITCODE -eq 0) "entry pack setup failed"
        New-CompleteSubmissionPacket $entryPack $submissionPacket
        New-CompleteMaterialsFolder $materials
        Add-CompleteSetupEvidence $materials
        Add-CompleteReleaseEvidence $materials

        $result = Invoke-ReleaseDoctor @(
            "-LocalOnly",
            "-EntryPackDirectory", $entryPack,
            "-SubmissionPacketDirectory", $submissionPacket,
            "-MaterialsDirectory", $materials
        )

        Assert-True ($result.ExitCode -ne 2) "complete local artifacts should not create blocked gates: $($result.Output)"
        Assert-Contains $result.Output "[OK] App Store Connect entry packet" "entry pack gate should be OK"
        Assert-Contains $result.Output "[OK] App Store submission packet" "submission packet gate should be OK"
        Assert-Contains $result.Output "[OK] Apple private material folder" "materials gate should be OK"
        Assert-Contains $result.Output "[OK] App Store Connect setup evidence" "setup evidence gate should be OK"
        Assert-Contains $result.Output "[OK] App Store release evidence" "release evidence gate should be OK"
        Assert-Contains $result.Output "blocked=0" "local-only doctor should report zero blocked gates for complete local artifacts"
    }

    Run-Test "local-only doctor blocks missing explicit artifact folders" {
        $missingEntryPack = Join-Path $tempRoot "missing-entry-pack"
        $missingSubmissionPacket = Join-Path $tempRoot "missing-submission-packet"
        $missingMaterials = Join-Path $tempRoot "missing-materials"

        $result = Invoke-ReleaseDoctor @(
            "-LocalOnly",
            "-EntryPackDirectory", $missingEntryPack,
            "-SubmissionPacketDirectory", $missingSubmissionPacket,
            "-MaterialsDirectory", $missingMaterials
        )

        Assert-True ($result.ExitCode -eq 2) "missing explicit artifact folders should exit 2: $($result.Output)"
        Assert-Contains $result.Output "[BLOCKED] App Store Connect entry packet" "missing entry pack should be blocked"
        Assert-Contains $result.Output "[BLOCKED] App Store submission packet" "missing submission packet should be blocked"
        Assert-Contains $result.Output "[BLOCKED] Apple private material folder" "missing materials should be blocked"
    }

    Run-Test "local-only doctor writes next action packet for incomplete Apple materials" {
        $entryPack = Join-Path $tempRoot "next-action-entry-pack"
        $materials = Join-Path $tempRoot "next-action-materials"
        $nextActionsPath = Join-Path $tempRoot "doctor-next-actions.md"
        & powershell -NoProfile -ExecutionPolicy Bypass -File $entryPackExporterPath -OutputDirectory $entryPack | Out-Null
        Assert-True ($LASTEXITCODE -eq 0) "entry pack setup failed"
        & powershell -NoProfile -ExecutionPolicy Bypass -File $materialsPrepPath -OutputDirectory $materials | Out-Null
        Assert-True ($LASTEXITCODE -eq 0) "materials setup failed"

        $result = Invoke-ReleaseDoctor @(
            "-LocalOnly",
            "-EntryPackDirectory", $entryPack,
            "-MaterialsDirectory", $materials,
            "-NextActionsOutputPath", $nextActionsPath
        )

        Assert-True ($result.ExitCode -eq 2) "incomplete Apple materials should block release: $($result.Output)"
        Assert-Contains $result.Output "[OK] Apple release next actions" "doctor should write the next-actions packet even when blocked"
        Assert-Contains $result.Output $nextActionsPath "doctor output should include the generated next-actions path"
        Assert-True (Test-Path $nextActionsPath) "doctor should create the next-actions Markdown packet"
        $nextActions = Get-Content $nextActionsPath -Raw
        Assert-Contains $nextActions "Complete Apple account and paid app setup" "next-actions packet should name the first missing Apple action"
        Assert-Contains $nextActions "Do not paste private Apple values into GitHub issues" "next-actions packet should include privacy guardrails"
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
    Write-Host "release-doctor local artifact tests failed:"
    foreach ($failure in $failures) {
        Write-Host "- $failure"
    }
    exit 1
}

Write-Host ""
Write-Host "release-doctor local artifact tests passed."
