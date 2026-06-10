# Current Release Status

This is the short operational status for SnapTable Reminder version 1.

## Current State

Local repository status:

- Native SwiftUI iPhone app source is present.
- XcodeGen project configuration is present in `project.yml`.
- Unit test source files are present for parsing, CSV export, date logic, settings persistence, and reminder date policy.
- App Store support site files are present in `site/`.
- GitHub Actions workflows are present for iOS CI, GitHub Pages, App Store screenshots, and release readiness.
- Fastlane lanes are present for verify, archive, and TestFlight upload.
- GitHub login and publish helper script is present in `scripts/github-login-and-publish.ps1`.
- GitHub publish helper can write public support request links and Fastlane store URL files after the repository URL is known.
- App Store metadata, privacy, age rating, export compliance, review notes, screenshot plan, monetization plan, and launch runbook are drafted.
- App Store account setup checklist is drafted in `docs/app-store/account-setup.md`.
- Machine-readable App Store Connect fields are present in `docs/app-store/app-store-fields.json` and covered by Windows preflight.
- Fastlane metadata files are present in `fastlane/metadata/` and covered by Windows preflight.
- App Store metadata length and keyword byte limits are covered by `scripts/validate-app-store-metadata.ps1`.
- GitHub Pages workflow prints the exact Privacy Policy and Support URLs after deployment.
- App Store screenshot UI test target and Mac capture script are present.
- Manual GitHub Actions workflow is present for App Store screenshot artifact generation.
- Fastlane screenshot staging and upload lane are present.
- Screenshot automation resets demo data to avoid stale simulator records.
- Mac release readiness script is present for local build, test, and screenshot staging checks.
- Fastlane `review_check` lane and Precheckfile are present for App Review metadata risk checks.
- Mac Fastlane upload environment validation script is present.
- App Review contact checklist and Mac environment validation script are present.

Verified on this Windows workspace:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/windows-preflight.ps1
```

This verifies local static release gates only. It does not compile Swift or run iOS simulator tests.

## Not Yet Complete

These are still required before the goal is actually complete:

- Repository pushed to GitHub.
- GitHub Actions `iOS CI` passing on a macOS runner.
- GitHub Pages privacy and support URLs live.
- Mac or CI Xcode build and unit tests passing.
- Apple Developer Program membership active.
- Paid Apps Agreement, tax, and banking complete.
- App Store Connect app record created with bundle ID `com.snaptable.reminder`.
- Signing configured.
- App screenshots captured and uploaded.
- App archived and uploaded to TestFlight/App Store Connect.
- App Review contact details entered in App Store Connect.
- App Review submission completed.
- App status reaches Waiting for Review, then Ready for Distribution after approval.

## Fastest Next Path

1. Install GitHub CLI on Windows if needed:

```powershell
winget install --id GitHub.cli -e --source winget
```

2. Log in and publish this repository:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/github-login-and-publish.ps1 -RepoName snaptable-reminder-ios -Visibility public
```

3. In GitHub repository settings, enable Pages with Source set to GitHub Actions.

4. Confirm these Actions pass:

- `iOS CI`
- `Publish App Store Site`
- `App Store Screenshots`
- `Release Readiness`

5. Copy live URLs into App Store Connect:

```text
https://<owner>.github.io/<repo>/privacy.html
https://<owner>.github.io/<repo>/support.html
```

6. On a Mac, run:

```bash
brew install xcodegen
bundle install
bash scripts/mac-verify.sh
bash scripts/mac-release-readiness.sh
```

7. Before final App Review submission, set the `APP_REVIEW_*` contact environment variables and run:

```bash
bash scripts/mac-validate-review-contact-env.sh
```

8. Continue with `docs/app-store/launch-runbook.md`.

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
