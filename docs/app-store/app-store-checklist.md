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

- Machine-readable App Store fields: `docs/app-store/app-store-fields.json`.
- App name candidate: SnapTable Reminder.
- Display name: SnapTable.
- Subtitle: Screenshots to tables.
- Category: Productivity.
- Price: paid upfront, suggested USD 1.99 or 2.99 equivalent.
- Privacy policy URL: host `site/privacy.html` before submission.
- Support URL: host `site/support.html` before submission.
- Contact email: publish before submission.
- App Store metadata draft: `docs/app-store/metadata.md`.
- Privacy questionnaire draft: `docs/app-store/privacy-questionnaire.md`.
- Privacy manifest includes UserDefaults required reason API entry.
- Export compliance draft: `docs/app-store/export-compliance.md`.
- Review notes draft: `docs/app-store/review-notes.md`.
- Age rating draft: `docs/app-store/age-rating.md`.
- Fastlane release notes: `docs/app-store/fastlane-release.md`.
- Fastlane metadata files: `fastlane/metadata/`.
- Screenshot plan: `docs/app-store/screenshot-plan.md`.
- Launch runbook: `docs/app-store/launch-runbook.md`.
- Monetization plan: `docs/app-store/monetization-plan.md`.

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

## Privacy Answers

- Data collected: none in version 1.
- Tracking: no.
- Third-party analytics: no.
- User account: no.
- Backend transmission: no.
- Photos/camera use: user-selected images only, processed on device.

## Mac Submission Steps

1. Generate the Xcode project with `xcodegen generate`.
2. Run unit tests and simulator build.
3. Configure signing with the Apple Developer account.
4. Archive in Xcode.
5. Upload to App Store Connect.
6. Host `site/privacy.html` and `site/support.html`, or push to GitHub and use `.github/workflows/pages.yml` to publish them with GitHub Pages.
7. Set paid price and selected country/region availability excluding China mainland.
8. Fill privacy details using `docs/app-store/privacy-questionnaire.md`.
9. Complete age rating and export compliance using the drafts in `docs/app-store`.
10. Submit for review.

Fastlane alternative:

```bash
bundle exec fastlane ios verify
bundle exec fastlane ios metadata
bundle exec fastlane ios archive
bundle exec fastlane ios testflight
```
