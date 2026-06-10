$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$recordSetupPath = Join-Path $repoRoot "scripts\record-app-store-connect-setup-evidence.ps1"
$recordReleasePath = Join-Path $repoRoot "scripts\record-app-store-release-evidence.ps1"
$prepareMaterialsPath = Join-Path $repoRoot "scripts\prepare-apple-materials-folder.ps1"
$exportEntryPackPath = Join-Path $repoRoot "scripts\export-app-store-connect-entry-pack.ps1"
$releaseDoctorPath = Join-Path $repoRoot "scripts\release-doctor.ps1"
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

function Invoke-RecordSetup($arguments) {
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $recordSetupPath @arguments 2>&1 | Out-String
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    [pscustomobject]@{
        ExitCode = $exitCode
        Output = $output
    }
}

function Invoke-ReleaseDoctor($entryPack, $materials) {
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $releaseDoctorPath -LocalOnly -EntryPackDirectory $entryPack -MaterialsDirectory $materials 2>&1 | Out-String
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
    & powershell -NoProfile -ExecutionPolicy Bypass -File $prepareMaterialsPath -OutputDirectory $target | Out-Null
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

function New-CompleteSetupArguments($materials, $excludedCountriesOrRegions = @("China mainland")) {
    @(
        "-MaterialsDirectory", $materials,
        "-AppStoreConnectAppId", "1234567890",
        "-AppName", "SnapTable Reminder",
        "-BundleId", "com.snaptable.reminder",
        "-Sku", "SNAPTABLE-REMINDER-IOS-V1",
        "-PrimaryLanguage", "en-US",
        "-PrimaryCategory", "Productivity",
        "-PriceCurrency", "USD",
        "-PriceAmount", "1.99",
        "-AvailabilityMode", "selectedCountriesOrRegions",
        "-ExcludedCountriesOrRegions", $excludedCountriesOrRegions,
        "-PrivacyPolicyUrl", "https://ahuxxly.github.io/snaptable-reminder-ios/privacy.html",
        "-SupportUrl", "https://ahuxxly.github.io/snaptable-reminder-ios/support.html",
        "-PrivacyAnswersCompleted",
        "-AgeRatingCompleted",
        "-ExportComplianceCompleted",
        "-EuDsaTraderStatusCompleted"
    )
}

function Add-CompleteReleaseEvidence($materials) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $recordReleasePath `
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

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("snaptable-record-setup-tests-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempRoot | Out-Null

try {
    Run-Test "records App Store Connect setup evidence that matches source fields" {
        $materials = Join-Path $tempRoot "materials"
        New-CompleteMaterialsFolder $materials

        $result = Invoke-RecordSetup (New-CompleteSetupArguments $materials)

        Assert-True ($result.ExitCode -eq 0) "expected exit 0, got $($result.ExitCode): $($result.Output)"
        Assert-Contains $result.Output "app-store-connect-setup.private.json" "record script should mention the private setup JSON"
        $setupPath = Join-Path $materials "05-release-evidence\app-store-connect-setup.private.json"
        Assert-True (Test-Path $setupPath) "setup evidence JSON should be written"
        $setup = Get-Content $setupPath -Raw | ConvertFrom-Json
        Assert-True ($setup.app.bundleId -eq "com.snaptable.reminder") "setup should record bundle id"
        Assert-True ($setup.availability.excludeCountriesOrRegions -contains "China mainland") "setup should record China mainland exclusion"
        Assert-True ($setup.compliance.euDsaTraderStatusCompleted -eq $true) "setup should record DSA completion"
    }

    Run-Test "rejects setup evidence when China mainland is not excluded" {
        $materials = Join-Path $tempRoot "bad-availability-materials"
        New-CompleteMaterialsFolder $materials

        $result = Invoke-RecordSetup (New-CompleteSetupArguments $materials @("Canada"))

        Assert-True ($result.ExitCode -ne 0) "expected non-zero exit when China mainland is not excluded"
        Assert-Contains $result.Output "China mainland" "failure should explain the China mainland exclusion"
    }

    Run-Test "release doctor accepts complete local artifacts with setup and release evidence" {
        $entryPack = Join-Path $tempRoot "entry-pack"
        $materials = Join-Path $tempRoot "doctor-materials"
        & powershell -NoProfile -ExecutionPolicy Bypass -File $exportEntryPackPath -OutputDirectory $entryPack -Owner "doctor-owner" -RepoName "doctor-repo" | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Could not export test entry pack."
        }
        New-CompleteMaterialsFolder $materials
        $setup = Invoke-RecordSetup (New-CompleteSetupArguments $materials)
        Assert-True ($setup.ExitCode -eq 0) "could not record setup evidence: $($setup.Output)"
        Add-CompleteReleaseEvidence $materials

        $doctor = Invoke-ReleaseDoctor $entryPack $materials

        Assert-True ($doctor.ExitCode -ne 2) "complete local artifacts and evidence should not create blocked gates: $($doctor.Output)"
        Assert-Contains $doctor.Output "[OK] App Store Connect setup evidence" "doctor should accept complete setup evidence"
        Assert-Contains $doctor.Output "[OK] App Store release evidence" "doctor should accept complete release evidence"
        Assert-Contains $doctor.Output "blocked=0" "doctor should report zero blocked local gates"
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
    Write-Host "record-app-store-connect-setup-evidence tests failed:"
    foreach ($failure in $failures) {
        Write-Host "- $failure"
    }
    exit 1
}

Write-Host ""
Write-Host "record-app-store-connect-setup-evidence tests passed."
