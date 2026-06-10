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
xcodebuild test -scheme SnapTableReminder -destination 'platform=iOS Simulator,name=iPhone 15'
xcodebuild build -scheme SnapTableReminder -destination 'platform=iOS Simulator,name=iPhone 15'
```

## App Store Direction

Version 1 is planned as a paid upfront Productivity app distributed outside China mainland at launch. See `docs/app-store/app-store-checklist.md`.
