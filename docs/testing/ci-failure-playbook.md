# CI and Mac Failure Playbook

Use this when the first Mac build, GitHub Actions run, archive, or TestFlight upload fails. Capture the full error text before retrying.

## XcodeGen Is Missing

Symptom:

- `xcodegen: command not found`
- GitHub Actions fails during `Generate Xcode project`

Action:

```bash
brew install xcodegen
xcodegen generate
```

If Homebrew is unavailable on the Mac, install Homebrew first, then rerun `bash scripts/mac-verify.sh`.

## Xcode Command Line Tools Point Elsewhere

Symptom:

- `xcodebuild: command not found`
- `xcodebuild` reports only CommandLineTools
- Build fails before loading the scheme

Action:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
xcodebuild -version
```

Open Xcode once and accept any license or component installation prompts.

## No iPhone Simulator Found

Symptom:

- `No available iPhone simulator was found.`
- `xcrun simctl list devices available` returns no iPhone devices

Action:

1. Open Xcode > Settings > Platforms.
2. Install an iOS simulator runtime.
3. Run:

```bash
xcrun simctl list devices available | grep iPhone
bash scripts/mac-verify.sh
```

## Swift Compile Error

Symptom:

- `xcodebuild test` fails with Swift compiler diagnostics.

Action:

1. Read the first Swift error, not the last summary line.
2. Fix the file and line named by the first error.
3. Run:

```bash
xcodegen generate
xcodebuild test -scheme SnapTableReminder -destination "platform=iOS Simulator,name=iPhone 16"
```

If that simulator name is not installed, use the ID printed by:

```bash
xcrun simctl list devices available | grep -m 1 -E 'iPhone'
```

## VisionKit Scanner Unavailable

Symptom:

- Scan button is disabled in simulator.
- Camera scanning cannot be opened on a Mac runner.

Action:

This is expected on simulator and CI. Verify scanner wiring on a physical iPhone. Simulator QA should use image import, pasted text, and demo data.

## Signing or Bundle ID Failure

Symptom:

- Archive fails with signing errors.
- App Store Connect says the bundle identifier is unavailable.

Action:

1. Confirm the bundle ID in `project.yml`: `com.snaptable.reminder`.
2. In Apple Developer, create or select the matching App ID.
3. In Xcode, set the signing team for the app target.
4. Archive again.

If the bundle ID is already owned by another Apple team, choose a new reverse-DNS bundle ID and update `project.yml`, `fastlane/Appfile`, and App Store Connect together.

## App Icon Warning

Symptom:

- Archive or upload reports missing required app icon sizes.

Action:

1. Open `SnapTableReminder/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`.
2. Confirm all referenced PNG files exist in the same folder.
3. Regenerate icons from the master icon if needed.
4. Rerun archive.

## Fastlane Missing Gems

Symptom:

- `bundle exec fastlane ios verify` fails before running Xcode commands.

Action:

```bash
bundle install
bundle exec fastlane ios verify
```

Use the system Ruby only if Bundler can install gems cleanly; otherwise install Ruby through Homebrew.

## TestFlight API Key Missing

Symptom:

- `APP_STORE_CONNECT_API_KEY_ID`
- `APP_STORE_CONNECT_API_ISSUER_ID`
- `APP_STORE_CONNECT_API_KEY_PATH`

Action:

Set these on the Mac shell before upload:

```bash
export APP_STORE_CONNECT_API_KEY_ID="key-id"
export APP_STORE_CONNECT_API_ISSUER_ID="issuer-id"
export APP_STORE_CONNECT_API_KEY_PATH="/absolute/path/to/AuthKey.p8"
bundle exec fastlane ios testflight
```

Never commit the `.p8` key.

## Paid App Setup Blocks Release

Symptom:

- Paid pricing cannot be selected.
- The app cannot be made available for sale.

Action:

In App Store Connect, complete:

- Paid Apps Agreement
- Tax forms
- Banking information

Wait until App Store Connect shows the agreement as active before submitting the paid app.

## GitHub Pages URLs Do Not Open

Symptom:

- Privacy URL or Support URL returns 404.
- App Store Connect rejects the URL.

Action:

1. Confirm `.github/workflows/pages.yml` passed.
2. Enable GitHub Pages from GitHub Actions in repository settings.
3. Open `privacy.html` and `support.html` in a private browser window.
4. Use those public URLs in App Store Connect.

## When to Stop and Escalate

Stop retries and capture the log if the same failure appears after two focused fixes. Keep the failing command, full terminal output, Xcode version, and simulator name together so the next pass can continue without guesswork.
