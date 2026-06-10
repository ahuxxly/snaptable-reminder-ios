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

After the repository is on GitHub, the same screenshot path is available through the manual `App Store Screenshots` workflow. Download `app-store-screenshots` for raw exports or `fastlane-screenshots` for the upload folder.

## GitHub Actions

The repository includes `.github/workflows/ios-ci.yml`. After pushing to GitHub, open the Actions tab and confirm the iOS CI workflow passes. This verifies the same project generation, test, and simulator build path on a hosted macOS runner.

If the local Mac run or CI fails, use `docs/testing/ci-failure-playbook.md` before retrying.

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
