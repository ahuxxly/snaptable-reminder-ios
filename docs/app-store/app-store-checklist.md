# App Store Release Checklist

## Account

- Apple Developer Program membership is active.
- Paid Apps Agreement is accepted in App Store Connect.
- Tax and banking information is complete.
- Account Holder, Admin, or App Manager access is available for upload and submission.

## Availability

- Distribution method: Public.
- Availability: Specific Countries or Regions.
- China mainland: excluded for version 1.

## Metadata

- App name candidate: SnapTable Reminder.
- Display name: SnapTable.
- Subtitle: Screenshots to tables.
- Category: Productivity.
- Price: paid upfront, suggested USD 1.99 or 2.99 equivalent.
- Privacy policy URL: hosted from `docs/app-store/privacy-policy.md`.
- Support URL: publish before submission.
- Contact email: publish before submission.

## Screenshots

- 6.7 inch iPhone Capture screenshot.
- 6.7 inch iPhone Records screenshot.
- 6.7 inch iPhone Dashboard screenshot.
- 6.7 inch iPhone Settings screenshot.

## Keywords

screenshot OCR, document scanner, table export, reminder, receipt organizer, deadline tracker

## Review Notes

- The app recognizes text on device using Apple frameworks.
- The app stores records locally on device.
- The app does not create accounts or connect to a backend.
- The app does not use third-party analytics or tracking.
- The app does not provide legal, medical, tax, financial, or investment advice.
- Parsed fields require user review and confirmation before saving.

## Mac Submission Steps

1. Generate the Xcode project with `xcodegen generate`.
2. Run unit tests and simulator build.
3. Configure signing with the Apple Developer account.
4. Archive in Xcode.
5. Upload to App Store Connect.
6. Set paid price and selected country/region availability excluding China mainland.
7. Fill privacy details and submit for review.
