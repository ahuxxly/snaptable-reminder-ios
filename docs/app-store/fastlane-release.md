# Fastlane Release Path

This project includes Fastlane as an optional Mac release helper. It does not store Apple credentials in the repository.

Before using Fastlane upload lanes, complete `docs/app-store/account-setup.md`.

Official Fastlane references:

- https://docs.fastlane.tools/actions/deliver/
- https://docs.fastlane.tools/actions/precheck/

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

Check that the upload environment is ready:

```bash
bash scripts/mac-validate-upload-env.sh
```

Then run:

```bash
bundle exec fastlane ios testflight
```

GitHub Actions alternative:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/github-set-apple-secrets.ps1
powershell -ExecutionPolicy Bypass -File scripts/github-run-app-store-release.ps1
```

The first helper writes upload and signing secrets to GitHub and refuses `.p8`, `.p12`, and `.mobileprovision` files stored inside this repository.
The second helper checks the configured secrets, triggers App Store Connect metadata/screenshot/precheck upload, and triggers TestFlight upload.

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

For GitHub Pages hosting, `scripts/github-publish.ps1` generates them automatically after the repository URL is known. They can also be generated manually with:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/write-fastlane-store-urls.ps1 -Owner <owner> -RepoName <repo>
```

Then run:

```bash
bash scripts/mac-validate-upload-env.sh
bundle exec fastlane ios metadata
```

This uploads metadata only. It does not upload a binary, upload screenshots, or submit the app for review.

## Screenshot Upload

Generate and stage screenshots first:

```bash
bash scripts/mac-capture-screenshots.sh
```

This creates `fastlane/screenshots/en-US`. Then run:

```bash
bash scripts/mac-validate-upload-env.sh
bundle exec fastlane ios screenshots
```

This uploads screenshots only. It does not upload a binary, upload metadata, or submit the app for review.

## Review Risk Check

After metadata and screenshots are uploaded, run:

```bash
bash scripts/mac-validate-upload-env.sh
bundle exec fastlane ios review_check
```

This uses Fastlane precheck against App Store Connect metadata. It scans for common App Review risks such as placeholder text, test words, other platforms, future functionality claims, unreachable URLs, and selected risky marketing claims. It does not upload a binary or submit the app for review.

Before final App Review submission, also run:

```bash
bash scripts/mac-validate-review-contact-env.sh
```

This validates that the local submission session has reviewer contact details ready. The real first name, last name, email, and phone number still need to be entered in App Store Connect.

## Notes

- The bundle identifier is `com.snaptable.reminder`.
- The `testflight` lane uploads a build. The `metadata` lane uploads listing metadata. The `screenshots` lane uploads staged screenshots. The `review_check` lane runs Fastlane precheck. Final App Review submission still requires privacy answers, pricing, country/region availability, and App Review contact details.
- Do not commit `.p8` API keys, certificates, provisioning profiles, or exported archives.
