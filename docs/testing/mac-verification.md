# Mac Verification

Run this on a Mac with Xcode installed.

## Install Tools

```bash
brew install xcodegen
```

If Xcode was newly installed, confirm command line tools:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
xcodebuild -version
```

## Run Full Verification

From the repository root:

```bash
bash scripts/mac-verify.sh
```

Expected result:

- `xcodegen generate` succeeds.
- `xcodebuild test` succeeds for `SnapTableReminderTests`.
- `xcodebuild build` succeeds for the first available iPhone simulator destination.
- `xcodebuild build-for-testing` succeeds for the screenshot UI test target.

## Capture App Store Screenshots

After full verification passes, run:

```bash
bash scripts/mac-capture-screenshots.sh
```

This uses reset demo data, exports screenshot attachments for Capture, Records, Dashboard, and Settings to `build/app-store-screenshots`, and stages Fastlane-ready screenshots in `fastlane/screenshots/en-US`.

After the repository is on GitHub, the same screenshot path is available through the manual `App Store Screenshots` workflow. The manual `Release Readiness` workflow runs Mac verification and screenshot capture together. Download `app-store-screenshots` for raw exports or `fastlane-screenshots` for the upload folder.

## GitHub Actions

The repository includes `.github/workflows/ios-ci.yml` and `.github/workflows/release-readiness.yml`. Both macOS workflows are manual while GitHub Actions minutes are near the monthly limit. Run `iOS CI` manually from the Actions tab when the current HEAD needs hosted macOS verification, and run `Release Readiness` manually before upload work. These verify project generation, tests, simulator build, screenshot UI test build, and screenshot artifact generation on a hosted macOS runner.

If the local Mac run or CI fails, use `docs/testing/ci-failure-playbook.md` before retrying.

## Run Release Readiness

Before App Store Connect upload work, run:

```bash
bash scripts/mac-release-readiness.sh
```

This runs Mac verification, captures screenshots, stages Fastlane screenshot files, and prints the next upload and submission checks.

## Archive for App Store Connect

After tests and simulator build pass:

1. Open `SnapTableReminder.xcodeproj`.
2. Set signing team and bundle identifier ownership.
3. Select Any iOS Device.
4. Choose Product > Archive.
5. In Organizer, choose Distribute App > App Store Connect > Upload.

## Required Account Items

- Apple Developer Program membership.
- Paid Apps Agreement active.
- Tax and banking complete.
- Hosted public URLs for `site/privacy.html` and `site/support.html`.
- Final screenshots from the simulator or a physical iPhone.
