# Fastlane Release Path

This project includes Fastlane as an optional Mac release helper. It does not store Apple credentials in the repository.

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

## Notes

- The bundle identifier is `com.snaptable.reminder`.
- The lane uploads to TestFlight only; final App Review submission still requires App Store Connect metadata, screenshots, privacy answers, pricing, and country/region availability.
- Do not commit `.p8` API keys, certificates, provisioning profiles, or exported archives.
