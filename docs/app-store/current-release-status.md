# Current Release Status

This is the short operational status for SnapTable Reminder version 1.

## Current State

Local repository status:

- Native SwiftUI iPhone app source is present.
- XcodeGen project configuration is present in `project.yml`.
- Unit test source files are present for parsing, CSV export, date logic, settings persistence, and reminder date policy.
- App Store support site files are present in `site/`.
- GitHub Actions workflows are present for iOS CI, GitHub Pages, App Store screenshots, release readiness, App Store Connect metadata/screenshot upload, TestFlight upload, and protected App Review submission.
- Fastlane lanes are present for verify, archive, metadata upload, screenshot upload, review checks, TestFlight upload, and protected App Review submission.
- GitHub login and publish helper script is present in `scripts/github-login-and-publish.ps1`.
- GitHub publish helper can enable GitHub Issues, prepare the support issue label, write public support request links, and write Fastlane store URL files after the repository URL is known.
- GitHub support issue template is present and warns users not to include private documents in public support requests.
- App Store metadata, privacy, age rating, export compliance, review notes, screenshot plan, monetization plan, and launch runbook are drafted.
- App Store account setup checklist is drafted in `docs/app-store/account-setup.md`.
- EU Digital Services Act trader status checklist is drafted in `docs/app-store/eu-dsa-trader.md`.
- Machine-readable App Store Connect fields are present in `docs/app-store/app-store-fields.json` and covered by Windows preflight.
- Fastlane metadata files are present in `fastlane/metadata/` and covered by Windows preflight.
- App Store metadata length and keyword byte limits are covered by `scripts/validate-app-store-metadata.ps1`.
- Windows preflight scans source for networking, analytics, crash reporting, and cloud-AI code that would conflict with the version 1 privacy promise.
- GitHub Pages workflow prints the exact Privacy Policy and Support URLs after deployment.
- App Store screenshot UI test target and Mac capture script are present.
- Manual GitHub Actions workflow is present for App Store screenshot artifact generation.
- Windows Release Readiness artifact archive helper is present for downloading and verifying `fastlane-screenshots` and `app-store-screenshots` from a successful GitHub Actions run.
- Windows App Store submission packet builder is present for combining the entry packet, verified screenshots, and Release Readiness evidence into one non-secret local folder.
- Fastlane screenshot staging and upload lane are present.
- Screenshot automation resets demo data to avoid stale simulator records.
- Mac release readiness script is present for local build, test, and screenshot staging checks.
- Fastlane `review_check` lane and Precheckfile are present for App Review metadata risk checks.
- Mac Fastlane upload environment validation script is present.
- Mac Apple signing environment validation and installation scripts are present.
- Windows GitHub Apple secret helper is present for configuring upload, signing, and App Review contact secrets without committing private files.
- Windows private Apple materials folder helper is present for preparing and validating account, API key, signing, DSA, and review-contact evidence outside the repository.
- Windows Apple release next-actions helper is present for writing a local Markdown checklist that names the next Apple/account/release evidence step from the private materials folder state.
- Windows Apple release material staging helper is present for copying downloaded Apple files into the private materials folder and writing private release JSON from command parameters.
- Windows App Store Connect setup evidence recorder is present for validating app record, pricing, availability, privacy, age rating, export compliance, and EU DSA choices against source fields.
- Windows App Store release evidence recorder is present for storing TestFlight/App Review status evidence in the private materials folder.
- Windows App Store Connect entry packet exporter is present for generating paste-ready app record, metadata, privacy/compliance, and review fields from source files.
- Windows GitHub App Store release helper is present for checking secrets and triggering upload workflows.
- Windows GitHub App Review submit helper is present for checking review-contact secrets and triggering final submission with explicit confirmation.
- Release workflow helpers support dry-run planning before Apple secrets exist, while real workflow dispatch still blocks missing secrets.
- App Review contact checklist and Mac environment validation script are present.

Verified on GitHub:

- Repository is public at `https://github.com/ahuxxly/snaptable-reminder-ios`.
- `iOS CI` is passing on macOS.
- `Release Readiness` is passing on macOS.
- Release Readiness screenshot artifacts can be archived and verified locally with `scripts/archive-release-readiness-artifacts.ps1`.
- A public App Store submission packet can be built locally with `scripts/build-app-store-submission-packet.ps1`.
- `Publish App Store Site` is passing.
- Privacy URL is live: `https://ahuxxly.github.io/snaptable-reminder-ios/privacy.html`.
- Support URL is live: `https://ahuxxly.github.io/snaptable-reminder-ios/support.html`.
- Release Readiness generated `app-store-screenshots` and `fastlane-screenshots` artifacts.
- Remaining Apple account materials are tracked in `https://github.com/ahuxxly/snaptable-reminder-ios/issues/1`.
- Issue #1 can be refreshed with `scripts/sync-release-issue.ps1` when release gates change.

Verified on this Windows workspace:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/windows-preflight.ps1
```

This verifies local static release gates only. It does not compile Swift or run iOS simulator tests.

Release doctor command:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/release-doctor.ps1 -RunPreflight
```

This performs a read-only status sweep over local gates, GitHub workflows, hosted support URLs, GitHub secrets, and remaining Apple account blockers. It does not trigger uploads or App Review submission.
It also writes a local `SnapTableReminder-Apple-Next-Actions.md` checklist so the next Apple/account action is visible after the diagnosis.

Local-only artifact diagnosis:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/release-doctor.ps1 -LocalOnly `
  -EntryPackDirectory "C:\path\outside\repo\SnapTableReminder-AppStoreConnect-EntryPack" `
  -MaterialsDirectory "C:\path\outside\repo\SnapTableReminder-Apple-Materials" `
  -NextActionsOutputPath "C:\path\outside\repo\SnapTableReminder-Apple-Next-Actions.md"
```

## Not Yet Complete

These are still required before the goal is actually complete:

- Apple Developer Program membership active.
- Paid Apps Agreement, tax, and banking complete.
- EU Digital Services Act trader status declared for EU storefronts, or EU storefronts intentionally excluded.
- App Store Connect app record created with bundle ID `com.snaptable.reminder`.
- Signing configured.
- App Store Connect upload secrets configured in GitHub.
- Apple signing secrets configured in GitHub.
- App Store metadata, screenshots, and precheck uploaded through Fastlane.
- App screenshots uploaded to App Store Connect.
- App archived and uploaded to TestFlight/App Store Connect.
- App Review contact details entered in App Store Connect.
- App Review contact secrets configured in GitHub.
- App Review submission completed.
- App status reaches Waiting for Review, then Ready for Distribution after approval.

## Fastest Next Path

1. Confirm these Actions pass:

- `iOS CI`
- `Publish App Store Site`
- `Release Readiness`

You can run `scripts/release-doctor.ps1 -RunPreflight` to see this status plus the missing Apple account and GitHub secret gates in one place.
After `Release Readiness` succeeds, archive its screenshots with `scripts/archive-release-readiness-artifacts.ps1 -RunId "<run-id>"`.
Then build the public submission packet with `scripts/build-app-store-submission-packet.ps1`.

2. Copy live URLs into App Store Connect:

```text
https://ahuxxly.github.io/snaptable-reminder-ios/privacy.html
https://ahuxxly.github.io/snaptable-reminder-ios/support.html
```

3. Create the App Store Connect app record and API key.

4. Prepare and validate the private Apple material folder:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/prepare-apple-materials-folder.ps1
powershell -ExecutionPolicy Bypass -File scripts/apple-release-next-actions.ps1
powershell -ExecutionPolicy Bypass -File scripts/stage-apple-release-materials.ps1 -OutputDirectory "C:\path\outside\repo\SnapTableReminder-Apple-Materials" -AppStoreConnectApiKeyPath "C:\path\to\AuthKey_KEYID1234.p8" -AppleDistributionCertificatePath "C:\path\to\apple-distribution.p12" -AppleAppStoreProfilePath "C:\path\to\SnapTableReminder_AppStore.mobileprovision" -DsaEvidencePath "C:\path\to\dsa-private-evidence.md" -AppStoreConnectUsername "account@example.invalid" -AppleDeveloperTeamId "TEAMID1234" -AppStoreConnectApiKeyId "KEYID1234" -AppStoreConnectApiIssuerId "00000000-0000-0000-0000-000000000000" -AppleDistributionCertificatePassword "p12-export-password" -AppleCodesignKeychainPassword "temporary-ci-keychain-password" -ReviewFirstName "App" -ReviewLastName "Reviewer" -ReviewEmail "reviewer@example.invalid" -ReviewPhone "+1 555 010 1000" -AppleDeveloperProgramActive -PaidAppsAgreementActive -TaxComplete -BankingComplete -AppStoreConnectAppCreated -DryRun
powershell -ExecutionPolicy Bypass -File scripts/record-app-store-connect-setup-evidence.ps1 -MaterialsDirectory "C:\path\outside\repo\SnapTableReminder-Apple-Materials" -AppStoreConnectAppId "1234567890" -AppName "SnapTable Reminder" -BundleId "com.snaptable.reminder" -Sku "SNAPTABLE-REMINDER-IOS-V1" -PrimaryLanguage "en-US" -PrimaryCategory "Productivity" -PriceCurrency "USD" -PriceAmount "1.99" -AvailabilityMode "selectedCountriesOrRegions" -ExcludedCountriesOrRegions "China mainland" -PrivacyPolicyUrl "https://ahuxxly.github.io/snaptable-reminder-ios/privacy.html" -SupportUrl "https://ahuxxly.github.io/snaptable-reminder-ios/support.html" -PrivacyAnswersCompleted -AgeRatingCompleted -ExportComplianceCompleted -EuDsaTraderStatusCompleted -DryRun
powershell -ExecutionPolicy Bypass -File scripts/prepare-apple-materials-folder.ps1 -OutputDirectory "C:\path\outside\repo\SnapTableReminder-Apple-Materials" -ValidateOnly
powershell -ExecutionPolicy Bypass -File scripts/export-app-store-connect-entry-pack.ps1
```

Remove `-DryRun` from `scripts/stage-apple-release-materials.ps1` and `scripts/record-app-store-connect-setup-evidence.ps1` only after the previews show the right source files and App Store Connect fields.

5. Add the App Store Connect upload secrets with `scripts/github-set-apple-secrets.ps1 -UploadOnly -MaterialsDirectory "C:\path\outside\repo\SnapTableReminder-Apple-Materials"`.

6. Dry-run and then run `scripts/github-run-app-store-release.ps1 -SkipTestFlight` to upload metadata, screenshots, and precheck:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/github-run-app-store-release.ps1 -SkipTestFlight -DryRun
powershell -ExecutionPolicy Bypass -File scripts/github-run-app-store-release.ps1 -SkipTestFlight -Wait
```

7. Add the Apple signing secrets with `scripts/github-set-apple-secrets.ps1 -SigningOnly -MaterialsDirectory "C:\path\outside\repo\SnapTableReminder-Apple-Materials"`.

8. Complete the EU DSA trader status decision in `docs/app-store/eu-dsa-trader.md`.

9. Dry-run and then run `scripts/github-run-app-store-release.ps1` to upload metadata, screenshots, precheck, and a signed TestFlight build:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/github-run-app-store-release.ps1 -DryRun
powershell -ExecutionPolicy Bypass -File scripts/github-run-app-store-release.ps1 -Wait
```

10. Add App Review contact secrets with `scripts/github-set-apple-secrets.ps1 -ReviewOnly -MaterialsDirectory "C:\path\outside\repo\SnapTableReminder-Apple-Materials"`.

11. After App Store Connect shows the build is processed, dry-run and then run protected App Review submission:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/github-submit-app-review.ps1 -ConfirmSubmitForReview YES -DryRun
powershell -ExecutionPolicy Bypass -File scripts/github-submit-app-review.ps1 -ConfirmSubmitForReview YES -Wait
powershell -ExecutionPolicy Bypass -File scripts/record-app-store-release-evidence.ps1 -MaterialsDirectory "C:\path\outside\repo\SnapTableReminder-Apple-Materials" -AppStoreConnectAppId "1234567890" -AppVersion "1.0" -BuildNumber "1" -MetadataWorkflowRunUrl "https://github.com/owner/repo/actions/runs/100" -TestFlightWorkflowRunUrl "https://github.com/owner/repo/actions/runs/101" -AppReviewWorkflowRunUrl "https://github.com/owner/repo/actions/runs/102" -MetadataUploaded -ScreenshotsUploaded -ReviewCheckPassed -TestFlightUploaded -BuildProcessed -AppReviewSubmitted -AppStatus "Waiting for Review" -DryRun
```

Remove `-DryRun` from the evidence command only after App Store Connect shows the same status.

12. On a Mac, run:

```bash
brew install xcodegen
bundle install
bash scripts/mac-verify.sh
bash scripts/mac-release-readiness.sh
```

13. Before final App Review submission, set the `APP_REVIEW_*` contact environment variables and run:

```bash
bash scripts/mac-validate-review-contact-env.sh
```

14. Continue with `docs/app-store/launch-runbook.md`.

## Release Boundaries

Keep version 1 intentionally small:

- paid upfront app;
- no backend;
- no analytics;
- no tracking;
- no account system;
- no cloud AI parser;
- no legal, medical, tax, financial, or investment advice;
- no China mainland availability in version 1.

## Evidence Needed to Close the Goal

Do not mark the project complete until there is evidence for:

- passing macOS build/test output;
- hosted privacy and support URLs;
- uploaded build in App Store Connect;
- completed App Store metadata, privacy, age rating, pricing, and availability;
- completed EU DSA trader status decision for the chosen EU availability;
- completed App Review contact fields;
- App Store Connect fields copied from `docs/app-store/app-store-fields.json`;
- App Review submission status in App Store Connect.
