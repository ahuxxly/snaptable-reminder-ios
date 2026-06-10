# App Store Privacy Questionnaire Draft

Use this as the version 1 draft when filling App Store Connect privacy details. Re-check after any SDK, analytics, backend, or cloud parsing feature is added.

## Tracking

- Does this app use data for tracking? No.
- Does this app share data with data brokers? No.
- Does this app use third-party advertising or analytics SDKs? No.

## Data Collection

Version 1 answer: the app does not collect data from this device or transmit user data to the developer or third parties.

Reasoning:

- Records are stored locally on device.
- OCR runs on device using Apple frameworks.
- CSV export is initiated by the user through the iOS share sheet.
- Local reminders are scheduled on device.
- No account system, backend, cloud AI parser, analytics SDK, or tracking SDK is included.

## User Content

If App Store Connect asks about user content, answer based on Apple's current questionnaire wording. The app allows users to create local records and OCR text, but version 1 does not collect or transmit that content to the developer.

## Identifiers

- User ID: No.
- Device ID: No.
- Advertising ID: No.

## Diagnostics

- Crash data: No third-party crash reporting in version 1.
- Performance data: No third-party performance reporting in version 1.

## Privacy Manifest Required Reason API

- UserDefaults: declared in `SnapTableReminder/Resources/PrivacyInfo.xcprivacy`.
- Reason code: `CA92.1`.
- Use: storing app-specific defaults, currently default currency and reminder lead days.
- No app group, cross-app, advertising, analytics, or tracking use.

## Location

- Precise location: No.
- Coarse location: No.

## Contacts, Photos, Camera, and Files

- Photos/camera/file access is user-initiated and used only to recognize text on device.
- The app does not upload selected images or files.
- The app does not access the user's contacts database.

## Notes for Future Versions

Update this file if adding:

- analytics;
- crash reporting SDKs;
- cloud AI parsing;
- account login;
- iCloud sync;
- backend storage;
- subscription purchases;
- server logs that include user identifiers or document content.
