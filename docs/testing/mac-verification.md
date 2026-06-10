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
- `xcodebuild build` succeeds for the iPhone simulator destination.

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
