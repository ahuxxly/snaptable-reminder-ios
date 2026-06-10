# Export Compliance Draft

This is a non-legal working note for App Store Connect export compliance. Confirm in App Store Connect and with the account holder before final submission.

## Version 1 Technical Position

SnapTable Reminder version 1:

- does not include custom cryptography;
- does not implement end-to-end encrypted messaging;
- does not include a VPN;
- does not connect to a backend;
- does not use cloud AI APIs;
- stores user records locally through iOS app storage;
- uses Apple system frameworks for OCR, Photos selection, document scanning, notifications, and sharing.

## Likely App Store Connect Direction

If asked whether the app uses encryption, the practical answer is expected to be that the app does not use custom or non-exempt encryption. If Apple asks about standard encryption provided by the operating system, follow the current App Store Connect wording.

The app Info.plist declares `ITSAppUsesNonExemptEncryption` as `false` for version 1. Apple documents this key as the way to provide export compliance information in the app's information property list so App Store Connect can avoid asking the encryption questions on every submission when the app does not use non-exempt encryption.

Official references:

- https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance/
- https://developer.apple.com/documentation/bundleresources/information-property-list/itsappusesnonexemptencryption

## Re-check Required If Added Later

Revisit export compliance if a future version adds:

- account login over HTTPS to a backend;
- cloud AI parsing;
- custom encrypted backups;
- secure messaging;
- VPN or tunneling;
- cryptographic libraries beyond standard Apple platform APIs.
