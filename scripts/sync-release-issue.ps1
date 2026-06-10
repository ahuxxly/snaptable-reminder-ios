param(
    [string]$RepoFullName = "",
    [int]$IssueNumber = 1,
    [switch]$DryRun
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

function Get-RepoFullName($ghPath, $repoFullName) {
    if (-not [string]::IsNullOrWhiteSpace($repoFullName)) {
        return $repoFullName.Trim()
    }

    $detectedRepo = (& $ghPath repo view --json nameWithOwner --jq ".nameWithOwner").Trim()
    if (-not $detectedRepo -or -not $detectedRepo.Contains("/")) {
        throw "Could not determine GitHub repository. Pass -RepoFullName owner/repo."
    }
    return $detectedRepo
}

function New-ReleaseIssueBody {
    @'
This issue tracks the private Apple-account work required before SnapTable Reminder can be uploaded, submitted, and sold on the App Store. Do not paste secrets, certificates, private keys, banking/tax documents, phone numbers, identity documents, or DSA contact details into this public issue.

## Current Public Release Evidence

- Repository: https://github.com/ahuxxly/snaptable-reminder-ios
- Privacy URL: https://ahuxxly.github.io/snaptable-reminder-ios/privacy.html
- Support URL: https://ahuxxly.github.io/snaptable-reminder-ios/support.html
- Local release doctor: `powershell -ExecutionPolicy Bypass -File scripts/release-doctor.ps1 -RunPreflight`
- Local artifact doctor: `powershell -ExecutionPolicy Bypass -File scripts/release-doctor.ps1 -LocalOnly -EntryPackDirectory "C:\path\outside\repo\SnapTableReminder-AppStoreConnect-EntryPack" -MaterialsDirectory "C:\path\outside\repo\SnapTableReminder-Apple-Materials"`
- Windows preflight: `powershell -ExecutionPolicy Bypass -File scripts/windows-preflight.ps1`
- Private Apple material folder helper: `powershell -ExecutionPolicy Bypass -File scripts/prepare-apple-materials-folder.ps1`
- Apple release material staging helper: `powershell -ExecutionPolicy Bypass -File scripts/stage-apple-release-materials.ps1`
- App Store Connect setup evidence recorder: `powershell -ExecutionPolicy Bypass -File scripts/record-app-store-connect-setup-evidence.ps1`
- App Store release evidence recorder: `powershell -ExecutionPolicy Bypass -File scripts/record-app-store-release-evidence.ps1`
- App Store Connect entry packet exporter: `powershell -ExecutionPolicy Bypass -File scripts/export-app-store-connect-entry-pack.ps1`
- Main release docs:
  - `docs/app-store/current-release-status.md`
  - `docs/app-store/launch-runbook.md`
  - `docs/app-store/account-setup.md`
  - `docs/app-store/eu-dsa-trader.md`
  - `docs/app-store/app-store-fields.json`

## Apple Account Checklist

- [ ] Apple Developer Program membership is active.
- [ ] Paid Apps Agreement is active.
- [ ] Tax information is submitted.
- [ ] Banking information is submitted.
- [ ] EU Digital Services Act trader status is declared for EU storefronts, or EU storefronts are intentionally excluded.
- [ ] Bundle ID `com.snaptable.reminder` exists in Apple Developer.
- [ ] App Store Connect app record exists.
- [ ] App name is `SnapTable Reminder`.
- [ ] SKU is `SNAPTABLE-REMINDER-IOS-V1`.
- [ ] Primary language is English (U.S.).
- [ ] Category is Productivity.
- [ ] Paid price is set, starting at USD 1.99 equivalent.
- [ ] Availability is selected countries or regions, excluding China mainland.
- [ ] Privacy URL and Support URL are entered in App Store Connect.

## Private Apple Files and Secrets

- [ ] Private Apple material folder is prepared and validated outside the repository:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/prepare-apple-materials-folder.ps1
powershell -ExecutionPolicy Bypass -File scripts/stage-apple-release-materials.ps1 -OutputDirectory "C:\path\outside\repo\SnapTableReminder-Apple-Materials" -AppStoreConnectApiKeyPath "C:\path\to\AuthKey_KEYID1234.p8" -AppleDistributionCertificatePath "C:\path\to\apple-distribution.p12" -AppleAppStoreProfilePath "C:\path\to\SnapTableReminder_AppStore.mobileprovision" -DsaEvidencePath "C:\path\to\dsa-private-evidence.md" -AppStoreConnectUsername "account@example.invalid" -AppleDeveloperTeamId "TEAMID1234" -AppStoreConnectApiKeyId "KEYID1234" -AppStoreConnectApiIssuerId "00000000-0000-0000-0000-000000000000" -AppleDistributionCertificatePassword "p12-export-password" -AppleCodesignKeychainPassword "temporary-ci-keychain-password" -ReviewFirstName "App" -ReviewLastName "Reviewer" -ReviewEmail "reviewer@example.invalid" -ReviewPhone "+1 555 010 1000" -AppleDeveloperProgramActive -PaidAppsAgreementActive -TaxComplete -BankingComplete -AppStoreConnectAppCreated -DryRun
powershell -ExecutionPolicy Bypass -File scripts/record-app-store-connect-setup-evidence.ps1 -MaterialsDirectory "C:\path\outside\repo\SnapTableReminder-Apple-Materials" -AppStoreConnectAppId "1234567890" -AppName "SnapTable Reminder" -BundleId "com.snaptable.reminder" -Sku "SNAPTABLE-REMINDER-IOS-V1" -PrimaryLanguage "en-US" -PrimaryCategory "Productivity" -PriceCurrency "USD" -PriceAmount "1.99" -AvailabilityMode "selectedCountriesOrRegions" -ExcludedCountriesOrRegions "China mainland" -PrivacyPolicyUrl "https://ahuxxly.github.io/snaptable-reminder-ios/privacy.html" -SupportUrl "https://ahuxxly.github.io/snaptable-reminder-ios/support.html" -PrivacyAnswersCompleted -AgeRatingCompleted -ExportComplianceCompleted -EuDsaTraderStatusCompleted -DryRun
powershell -ExecutionPolicy Bypass -File scripts/prepare-apple-materials-folder.ps1 -OutputDirectory "C:\path\outside\repo\SnapTableReminder-Apple-Materials" -ValidateOnly
powershell -ExecutionPolicy Bypass -File scripts/github-set-apple-secrets.ps1 -MaterialsDirectory "C:\path\outside\repo\SnapTableReminder-Apple-Materials" -DryRun
powershell -ExecutionPolicy Bypass -File scripts/export-app-store-connect-entry-pack.ps1
```

Remove `-DryRun` from the staging command only after the preview shows the right paths. Do not paste real passwords or phone numbers into this public issue.

- [ ] App Store Connect API key is generated and stored outside the repository.
- [ ] App Store Connect setup evidence is recorded in `05-release-evidence/app-store-connect-setup.private.json`.
- [ ] Apple Distribution `.p12` certificate is exported and stored outside the repository.
- [ ] App Store provisioning profile for `com.snaptable.reminder` is downloaded and stored outside the repository.
- [ ] App Review contact details are chosen and stored privately.
- [ ] GitHub upload secrets are configured:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/github-set-apple-secrets.ps1 -UploadOnly -MaterialsDirectory "C:\path\outside\repo\SnapTableReminder-Apple-Materials"
```

- [ ] GitHub signing secrets are configured:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/github-set-apple-secrets.ps1 -SigningOnly -MaterialsDirectory "C:\path\outside\repo\SnapTableReminder-Apple-Materials"
```

- [ ] GitHub App Review contact secrets are configured:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/github-set-apple-secrets.ps1 -ReviewOnly -MaterialsDirectory "C:\path\outside\repo\SnapTableReminder-Apple-Materials"
```

## Upload and Submission

- [ ] Metadata, screenshots, and precheck upload succeeds:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/github-run-app-store-release.ps1 -SkipTestFlight -DryRun
powershell -ExecutionPolicy Bypass -File scripts/github-run-app-store-release.ps1 -SkipTestFlight -Wait
```

- [ ] TestFlight upload succeeds:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/github-run-app-store-release.ps1 -DryRun
powershell -ExecutionPolicy Bypass -File scripts/github-run-app-store-release.ps1 -Wait
```

- [ ] App Store Connect shows the uploaded build as processed.
- [ ] App Review contact fields are entered in App Store Connect.
- [ ] App is submitted for review:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/github-submit-app-review.ps1 -ConfirmSubmitForReview YES -DryRun
powershell -ExecutionPolicy Bypass -File scripts/github-submit-app-review.ps1 -ConfirmSubmitForReview YES -Wait
powershell -ExecutionPolicy Bypass -File scripts/record-app-store-release-evidence.ps1 -MaterialsDirectory "C:\path\outside\repo\SnapTableReminder-Apple-Materials" -AppStoreConnectAppId "1234567890" -AppVersion "1.0" -BuildNumber "1" -MetadataWorkflowRunUrl "https://github.com/owner/repo/actions/runs/100" -TestFlightWorkflowRunUrl "https://github.com/owner/repo/actions/runs/101" -AppReviewWorkflowRunUrl "https://github.com/owner/repo/actions/runs/102" -MetadataUploaded -ScreenshotsUploaded -ReviewCheckPassed -TestFlightUploaded -BuildProcessed -AppReviewSubmitted -AppStatus "Waiting for Review" -DryRun
```

- [ ] Private release evidence is recorded in `05-release-evidence/release-evidence.private.json`.
- [ ] App status reaches Waiting for Review.
- [ ] App status reaches Ready for Distribution after approval.

## Safety Notes

- Store `.p8`, `.p12`, and `.mobileprovision` files outside the repo.
- The helper scripts reject Apple credential files placed inside the repository.
- This issue is public; use it only as a checklist, not as storage for private values.
'@
}

$ghPath = Resolve-GitHubCli
$RepoFullName = Get-RepoFullName $ghPath $RepoFullName

Write-Section "Target"
Write-Host "repo=$RepoFullName"
Write-Host "issue=$IssueNumber"

$body = New-ReleaseIssueBody
if ($DryRun) {
    Write-Section "Dry run body"
    Write-Host $body
    Write-Host ""
    Write-Host "Dry run complete; issue was not updated."
    exit 0
}

$tempBodyPath = Join-Path ([System.IO.Path]::GetTempPath()) ("snaptable-release-issue-" + [guid]::NewGuid().ToString("N") + ".md")
try {
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($tempBodyPath, $body, $utf8NoBom)
    & $ghPath issue edit $IssueNumber --repo $RepoFullName --body-file $tempBodyPath
    if ($LASTEXITCODE -ne 0) {
        throw "Could not update GitHub issue #$IssueNumber."
    }
} finally {
    if (Test-Path $tempBodyPath) {
        Remove-Item -LiteralPath $tempBodyPath -Force
    }
}

Write-Host "Updated release issue: https://github.com/$RepoFullName/issues/$IssueNumber"
