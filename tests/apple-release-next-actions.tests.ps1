$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$scriptPath = Join-Path $repoRoot "scripts\apple-release-next-actions.ps1"
$prepareMaterialsPath = Join-Path $repoRoot "scripts\prepare-apple-materials-folder.ps1"
$recordSetupPath = Join-Path $repoRoot "scripts\record-app-store-connect-setup-evidence.ps1"
$recordReleasePath = Join-Path $repoRoot "scripts\record-app-store-release-evidence.ps1"
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

function Assert-NotContains($text, $unexpected, $message) {
    if ($text.IndexOf($unexpected, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
        throw $message
    }
}

function Invoke-NextActions($arguments) {
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
    Set-Content -Path (Join-Path $target "01-app-store-connect-api-key\AuthKey_TESTKEY123.p8") -Encoding UTF8 -Value @"
-----BEGIN PRIVATE KEY-----
test-private-key
-----END PRIVATE KEY-----
"@
    [System.IO.File]::WriteAllBytes((Join-Path $target "02-signing\apple-distribution.p12"), [byte[]](1, 2, 3, 4))
    [System.IO.File]::WriteAllText((Join-Path $target "02-signing\app-store.mobileprovision"), "com.snaptable.reminder")
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

function Add-SetupEvidence($materials) {
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
        throw "Could not record test setup evidence."
    }
}

function Add-ReleaseEvidence($materials) {
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

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("snaptable-next-actions-tests-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempRoot | Out-Null

try {
    Run-Test "writes first-action packet when Apple folders do not exist" {
        $materials = Join-Path $tempRoot "missing-materials"
        $entryPack = Join-Path $tempRoot "missing-entry-pack"
        $outputPath = Join-Path $tempRoot "next-actions.md"

        $result = Invoke-NextActions @("-MaterialsDirectory", $materials, "-EntryPackDirectory", $entryPack, "-OutputPath", $outputPath)

        Assert-True ($result.ExitCode -eq 0) "expected exit 0, got $($result.ExitCode): $($result.Output)"
        Assert-True (Test-Path $outputPath) "next action packet should be written"
        $packet = Get-Content $outputPath -Raw
        Assert-Contains $packet "Create the private Apple materials folder" "packet should put folder creation first"
        Assert-Contains $packet "export-app-store-connect-entry-pack.ps1" "packet should include entry packet export command"
        Assert-Contains $packet "Do not paste private Apple values into GitHub issues" "packet should warn against leaking private values"
        Assert-Contains $result.Output "next=Create the private Apple materials folder" "console output should summarize the next action"
    }

    Run-Test "prioritizes missing Apple account and signing materials" {
        $materials = Join-Path $tempRoot "prepared-materials"
        $outputPath = Join-Path $tempRoot "prepared-next-actions.md"
        & powershell -NoProfile -ExecutionPolicy Bypass -File $prepareMaterialsPath -OutputDirectory $materials | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Could not prepare materials folder."
        }

        $result = Invoke-NextActions @("-MaterialsDirectory", $materials, "-OutputPath", $outputPath)

        Assert-True ($result.ExitCode -eq 0) "expected exit 0, got $($result.ExitCode): $($result.Output)"
        $packet = Get-Content $outputPath -Raw
        Assert-Contains $packet "Complete Apple account and paid app setup" "account readiness should be called out"
        Assert-Contains $packet "Download the App Store Connect API key" "API key should be called out"
        Assert-Contains $packet "Create Apple signing assets" "signing assets should be called out"
        Assert-NotContains $packet "All private materials and evidence are recorded" "packet should not claim readiness while materials are missing"
    }

    Run-Test "moves to setup evidence after private Apple materials are present" {
        $materials = Join-Path $tempRoot "complete-materials-without-evidence"
        $outputPath = Join-Path $tempRoot "complete-materials-next-actions.md"
        New-CompleteMaterialsFolder $materials

        $result = Invoke-NextActions @("-MaterialsDirectory", $materials, "-OutputPath", $outputPath)

        Assert-True ($result.ExitCode -eq 0) "expected exit 0, got $($result.ExitCode): $($result.Output)"
        $packet = Get-Content $outputPath -Raw
        Assert-Contains $packet "Record App Store Connect setup evidence" "setup evidence should be the next release proof"
        Assert-Contains $packet "record-app-store-connect-setup-evidence.ps1" "setup evidence command should be included"
        Assert-Contains $result.Output "next=Record App Store Connect setup evidence" "console output should show the setup evidence next action"
    }

    Run-Test "summarizes release evidence after setup evidence exists" {
        $materials = Join-Path $tempRoot "complete-materials-with-setup"
        $outputPath = Join-Path $tempRoot "setup-next-actions.md"
        New-CompleteMaterialsFolder $materials
        Add-SetupEvidence $materials

        $result = Invoke-NextActions @("-MaterialsDirectory", $materials, "-OutputPath", $outputPath)

        Assert-True ($result.ExitCode -eq 0) "expected exit 0, got $($result.ExitCode): $($result.Output)"
        $packet = Get-Content $outputPath -Raw
        Assert-Contains $packet "Upload metadata, screenshots, and TestFlight build" "packet should move to upload after setup evidence"
        Assert-Contains $packet "Record App Store release evidence" "release evidence should remain a required proof"
    }

    Run-Test "reports all local private evidence when release evidence exists" {
        $materials = Join-Path $tempRoot "complete-materials-with-release"
        $entryPack = Join-Path $tempRoot "final-entry-pack"
        $submissionPacket = Join-Path $tempRoot "final-submission-packet"
        $outputPath = Join-Path $tempRoot "release-next-actions.md"
        New-CompleteMaterialsFolder $materials
        Add-SetupEvidence $materials
        Add-ReleaseEvidence $materials
        New-Item -ItemType Directory -Path $entryPack | Out-Null
        New-Item -ItemType Directory -Path $submissionPacket | Out-Null

        $result = Invoke-NextActions @(
            "-MaterialsDirectory", $materials,
            "-EntryPackDirectory", $entryPack,
            "-SubmissionPacketDirectory", $submissionPacket,
            "-OutputPath", $outputPath
        )

        Assert-True ($result.ExitCode -eq 0) "expected exit 0, got $($result.ExitCode): $($result.Output)"
        $packet = Get-Content $outputPath -Raw
        Assert-Contains $packet "All private materials and evidence are recorded" "packet should report local evidence completion"
        Assert-Contains $packet "Run release doctor for final status" "release doctor should be the next verification"
        Assert-Contains $packet "Submission packet folder: $submissionPacket" "packet should record the public submission packet folder"
        Assert-Contains $packet "-SubmissionPacketDirectory `"$submissionPacket`"" "final release doctor command should include the public submission packet folder"
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
    Write-Host "apple-release-next-actions tests failed:"
    foreach ($failure in $failures) {
        Write-Host "- $failure"
    }
    exit 1
}

Write-Host ""
Write-Host "apple-release-next-actions tests passed."
