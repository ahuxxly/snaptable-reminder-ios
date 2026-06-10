# SnapTable Reminder

SnapTable Reminder is a local-only iOS utility that turns screenshots and document photos into editable records, CSV rows, and local reminders. The first release focuses on fast App Store submission: no account system, no backend, no bank integrations, no cloud AI dependency, and no legal, medical, tax, financial, or investment advice.

## What the MVP Does

- Imports a screenshot or document photo.
- Extracts text on device with Apple Vision.
- Parses likely title, category, amount, currency, date, deadline, phone, email, and notes.
- Lets the user review and edit parsed fields before saving.
- Stores records locally on device.
- Schedules local reminders before due dates or appointments.
- Exports records as CSV.

## Development Environment

This repository can be edited on Windows, but iOS compilation, simulator testing, signing, TestFlight upload, and App Store upload require macOS with Xcode.

Recommended Mac tools:

```bash
brew install xcodegen
xcodegen generate
open SnapTableReminder.xcodeproj
```

## Build on Mac

```bash
xcodegen generate
xcodebuild test -scheme SnapTableReminder -destination 'platform=iOS Simulator,id=<available iPhone simulator id>'
xcodebuild build -scheme SnapTableReminder -destination 'platform=iOS Simulator,id=<available iPhone simulator id>'
```

Or run:

```bash
bash scripts/mac-verify.sh
```

## Windows Preflight

On this Windows workspace, run the static checks with:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/windows-preflight.ps1
```

This checks git cleanliness, unfinished markers, common encoding damage, resource parsing, static site links, and reports whether the iOS toolchain is available.

## GitHub CI

The repository includes `.github/workflows/ios-ci.yml`. After this project is pushed to GitHub, GitHub Actions can run XcodeGen, unit tests, and an iPhone simulator build on macOS. Signing and App Store upload still require Apple Developer account setup.

## Fastlane on Mac

Fastlane is available for repeatable Mac release commands:

```bash
bundle install
bundle exec fastlane ios verify
bundle exec fastlane ios archive
```

TestFlight upload is documented in `docs/app-store/fastlane-release.md` and requires App Store Connect API key environment variables.

## App Store Support Site

The `site/` folder contains static privacy and support pages. The repository includes `.github/workflows/pages.yml`, which can publish those pages with GitHub Pages after the project is pushed to GitHub and Pages is enabled.

Use the hosted URLs for:

- Privacy Policy URL: `/privacy.html`
- Support URL: `/support.html`

## App Store Direction

Version 1 is planned as a paid upfront Productivity app distributed outside China mainland at launch. See `docs/app-store/app-store-checklist.md`.

For the full launch sequence, follow `docs/app-store/launch-runbook.md`.
