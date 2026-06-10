# Fastlane Release Path

This project includes Fastlane as an optional Mac release helper. It does not store Apple credentials in the repository.

Before using Fastlane upload lanes, complete `docs/app-store/account-setup.md`.

## Install

Run on macOS:

```bash
bundle install
brew install xcodegen
```

## Verify

```bash
bundle exec fastlane ios verify
```

This generates the Xcode project, runs unit tests, and runs an iPhone simulator build.

## Archive

```bash
bundle exec fastlane ios archive
```

This creates `build/SnapTableReminder.ipa` using App Store export settings. Signing must already be configured in Xcode or through the local Apple Developer account.

## TestFlight Upload

Set these environment variables on the Mac before uploading:

```bash
export APP_STORE_CONNECT_USERNAME="account-holder-email"
export APPLE_DEVELOPER_TEAM_ID="team-id"
export APP_STORE_CONNECT_API_KEY_ID="api-key-id"
export APP_STORE_CONNECT_API_ISSUER_ID="issuer-id"
export APP_STORE_CONNECT_API_KEY_PATH="/absolute/path/to/AuthKey.p8"
```

Then run:

```bash
bundle exec fastlane ios testflight
```

## Metadata Upload

Fastlane metadata files live in `fastlane/metadata/`. They mirror the public listing copy from `docs/app-store/app-store-fields.json` and `docs/app-store/metadata.md`.

Check metadata limits before upload:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/validate-app-store-metadata.ps1
```

After the App Store Connect app record exists and the public privacy/support URLs are live, add these two files locally or through App Store Connect before final submission:

```text
fastlane/metadata/en-US/privacy_url.txt
fastlane/metadata/en-US/support_url.txt
```

For GitHub Pages hosting, generate them with:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/write-fastlane-store-urls.ps1 -Owner <owner> -RepoName <repo>
```

Then run:

```bash
bundle exec fastlane ios metadata
```

This uploads metadata only. It does not upload a binary, upload screenshots, or submit the app for review.

## Notes

- The bundle identifier is `com.snaptable.reminder`.
- The `testflight` lane uploads a build. The `metadata` lane uploads listing metadata. Final App Review submission still requires screenshots, privacy answers, pricing, and country/region availability.
- Do not commit `.p8` API keys, certificates, provisioning profiles, or exported archives.
