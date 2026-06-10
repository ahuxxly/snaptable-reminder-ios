# Current Release Status

This is the short operational status for SnapTable Reminder version 1.

## Current State

Local repository status:

- Native SwiftUI iPhone app source is present.
- XcodeGen project configuration is present in `project.yml`.
- Unit test source files are present for parsing, CSV export, date logic, settings persistence, and reminder date policy.
- App Store support site files are present in `site/`.
- GitHub Actions workflows are present for iOS CI, GitHub Pages, App Store screenshots, release readiness, and App Store Connect metadata/screenshot upload.
- Fastlane lanes are present for verify, archive, and TestFlight upload.
- GitHub login and publish helper script is present in `scripts/github-login-and-publish.ps1`.
- GitHub publish helper can enable GitHub Issues, prepare the support issue label, write public support request links, and write Fastlane store URL files after the repository URL is known.
- GitHub support issue template is present and warns users not to include private documents in public support requests.
- App Store metadata, privacy, age rating, export compliance, review notes, screenshot plan, monetization plan, and launch runbook are drafted.
- App Store account setup checklist is drafted in `docs/app-store/account-setup.md`.
- Machine-readable App Store Connect fields are present in `docs/app-store/app-store-fields.json` and covered by Windows preflight.
- Fastlane metadata files are present in `fastlane/metadata/` and covered by Windows preflight.
- App Store metadata length and keyword byte limits are covered by `scripts/validate-app-store-metadata.ps1`.
- Windows preflight scans source for networking, analytics, crash reporting, and cloud-AI code that would conflict with the version 1 privacy promise.
- GitHub Pages workflow prints the exact Privacy Policy and Support URLs after deployment.
- App Store screenshot UI test target and Mac capture script are present.
- Manual GitHub Actions workflow is present for App Store screenshot artifact generation.
- Fastlane screenshot staging and upload lane are present.
- Screenshot automation resets demo data to avoid stale simulator records.
- Mac release readiness script is present for local build, test, and screenshot staging checks.
- Fastlane `review_check` lane and Precheckfile are present for App Review metadata risk checks.
- Mac Fastlane upload environment validation script is present.
- App Review contact checklist and Mac environment validation script are present.

Verified on GitHub:

- Repository is public at `https://github.com/ahuxxly/snaptable-reminder-ios`.
- `iOS CI` is passing on macOS.
- `Release Readiness` is passing on macOS.
- `Publish App Store Site` is passing.
- Privacy URL is live: `https://ahuxxly.github.io/snaptable-reminder-ios/privacy.html`.
- Support URL is live: `https://ahuxxly.github.io/snaptable-reminder-ios/support.html`.
- Release Readiness generated `app-store-screenshots` and `fastlane-screenshots` artifacts.

Verified on this Windows workspace:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/windows-preflight.ps1
```

This verifies local static release gates only. It does not compile Swift or run iOS simulator tests.

## Not Yet Complete

These are still required before the goal is actually complete:

- Apple Developer Program membership active.
- Paid Apps Agreement, tax, and banking complete.
- App Store Connect app record created with bundle ID `com.snaptable.reminder`.
- Signing configured.
- App Store Connect upload secrets configured in GitHub.
- App Store metadata, screenshots, and precheck uploaded through Fastlane.
- App screenshots uploaded to App Store Connect.
- App archived and uploaded to TestFlight/App Store Connect.
- App Review contact details entered in App Store Connect.
- App Review submission completed.
- App status reaches Waiting for Review, then Ready for Distribution after approval.

## Fastest Next Path

1. Confirm these Actions pass:

- `iOS CI`
- `Publish App Store Site`
- `App Store Screenshots`
- `Release Readiness`

2. Copy live URLs into App Store Connect:

```text
https://ahuxxly.github.io/snaptable-reminder-ios/privacy.html
https://ahuxxly.github.io/snaptable-reminder-ios/support.html
```

3. Create the App Store Connect app record and API key.

4. Add the App Store Connect upload secrets listed in `docs/app-store/account-setup.md`.

5. Run the `App Store Connect Upload` workflow to upload metadata, screenshots, and precheck.

6. On a Mac, run:

```bash
brew install xcodegen
bundle install
bash scripts/mac-verify.sh
bash scripts/mac-release-readiness.sh
```

7. Configure Apple signing and upload a signed build to TestFlight/App Store Connect.

8. Before final App Review submission, set the `APP_REVIEW_*` contact environment variables and run:

```bash
bash scripts/mac-validate-review-contact-env.sh
```

9. Continue with `docs/app-store/launch-runbook.md`.

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
- completed App Review contact fields;
- App Store Connect fields copied from `docs/app-store/app-store-fields.json`;
- App Review submission status in App Store Connect.
