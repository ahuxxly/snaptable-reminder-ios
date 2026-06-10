# Current Release Status

This is the short operational status for SnapTable Reminder version 1.

## Current State

Local repository status:

- Native SwiftUI iPhone app source is present.
- XcodeGen project configuration is present in `project.yml`.
- Unit test source files are present for parsing, CSV export, date logic, settings persistence, and reminder date policy.
- App Store support site files are present in `site/`.
- GitHub Actions workflows are present for iOS CI and GitHub Pages.
- Fastlane lanes are present for verify, archive, and TestFlight upload.
- App Store metadata, privacy, age rating, export compliance, review notes, screenshot plan, monetization plan, and launch runbook are drafted.
- Machine-readable App Store Connect fields are present in `docs/app-store/app-store-fields.json` and covered by Windows preflight.
- Fastlane metadata files are present in `fastlane/metadata/` and covered by Windows preflight.
- App Store metadata length and keyword byte limits are covered by `scripts/validate-app-store-metadata.ps1`.

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
- App Review submission completed.
- App status reaches Waiting for Review, then Ready for Distribution after approval.

## Fastest Next Path

1. Install and log in to GitHub CLI on Windows:

```powershell
winget install --id GitHub.cli -e --source winget
gh auth login
```

2. Publish this repository:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/github-publish.ps1 -RepoName snaptable-reminder-ios -Visibility public
```

3. In GitHub repository settings, enable Pages with Source set to GitHub Actions.

4. Confirm these Actions pass:

- `iOS CI`
- `Publish App Store Site`

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
```

7. Continue with `docs/app-store/launch-runbook.md`.

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
- App Store Connect fields copied from `docs/app-store/app-store-fields.json`;
- App Review submission status in App Store Connect.
