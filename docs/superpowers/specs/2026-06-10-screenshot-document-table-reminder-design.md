# Screenshot Document Table Reminder iOS MVP Design

Date: 2026-06-10
Working title: 截图文档转表格与提醒
Global launch name candidate: SnapTable Reminder
Primary goal: ship a small paid iOS utility that turns screenshots and document photos into editable records, CSV tables, and local reminders without a backend or cloud AI cost.

## Decision

Build a native SwiftUI iPhone app for screenshot/document OCR, structured extraction, table review, and local reminders. Version 1 will avoid account systems, backend services, cloud OCR, cloud AI parsing, tax/legal certification, and complex PDF workflows. The app stores data locally, uses Apple on-device Vision/VisionKit text recognition where possible, and ships as a paid upfront app first.

The first App Store release targets public distribution in selected countries and regions outside China mainland. Chinese language support can be included for users outside China mainland, but China mainland availability should be excluded until ICP and local compliance are intentionally handled.

## Current Context

The workspace started empty and was not a Git repository. Git is available. The current Windows environment does not expose Xcode, Swift, or `xcodebuild`, and the Build iOS Apps plugin did not expose XcodeBuildMCP tools in this session. Source code, XcodeGen configuration, docs, and tests can be created here; compilation, simulator testing, signing, TestFlight upload, and App Store submission still require a Mac with Xcode or a macOS CI/cloud build path.

Apple official references checked on 2026-06-10:

- Apple requires a privacy policy URL for iOS App Store submissions: https://developer.apple.com/help/app-store-connect/reference/app-information/app-information/
- App Store Connect privacy information is managed separately and the privacy policy URL is required for all apps: https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/
- Public distribution and country/region availability are managed in App Store Connect: https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/set-distribution-methods/
- App availability can be managed across App Store countries and regions: https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/manage-availability-for-your-app-on-the-app-store/
- China mainland availability can be blocked by missing ICP filing information: https://developer.apple.com/help/app-store-connect/reference/app-information/app-and-submission-statuses/
- Paid apps require the Paid Apps Agreement, banking, and tax setup: https://developer.apple.com/help/app-store-connect/manage-agreements/sign-and-update-agreements/
- Vision can recognize text in images through `VNRecognizeTextRequest`: https://developer.apple.com/documentation/vision/recognizing-text-in-images
- VisionKit can scan text through the camera: https://developer.apple.com/documentation/visionkit/scanning-data-with-the-camera/
- UserNotifications supports local notification scheduling: https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app

## Product Thesis

People receive important information as screenshots and photos: school notices, hospital appointments, payment slips, warranty cards, contracts, receipts, event tickets, renewal reminders, delivery notes, and handwritten-ish forms. The pain is not scanning documents for archival quality. The pain is that dates, amounts, names, and deadlines remain trapped in images and are easy to forget.

The app wins if a user can turn one screenshot into a useful reminder and CSV row in under 60 seconds:

- "What is this document about?"
- "Is there an amount, deadline, appointment time, or renewal date?"
- "Can I edit the extracted fields before saving?"
- "Can I export everything as a table?"
- "Can my phone remind me before the date?"

## Target User

Primary user:

- students, parents, freelancers, creators, administrators, small business owners, and personal productivity users who save many screenshots and notices.

Secondary user:

- anyone who needs lightweight OCR-to-table export without paying for a heavyweight scanner or spreadsheet workflow.

Version 1 explicitly does not target accountants, tax filing, invoice authentication, legal contract analysis, medical advice, regulated finance, enterprise document management, or automated compliance workflows.

## Approaches Considered

### Recommended: Local OCR Utility

Build a local-only SwiftUI paid app with image import/camera scan, Apple Vision OCR, deterministic parsing rules, user confirmation, local reminder scheduling, and CSV export.

Pros:

- fastest to build and review;
- no backend or model cost;
- strong privacy story;
- simple App Store review explanation;
- easier for a zero-basis founder to operate.

Cons:

- OCR and table extraction will be less magical than cloud AI;
- messy screenshots may require manual correction;
- first release is a utility, not a full document management platform.

### Alternative: Cloud AI Document Parser

Send screenshots to a backend or AI API to identify fields and table structure.

Pros:

- higher extraction quality on messy documents;
- stronger "AI" marketing angle.

Cons:

- requires backend, API keys, data retention policy, privacy disclosures, support burden, and model spend;
- increases review and trust surface;
- not ideal for fast first revenue.

### Alternative: General Document Scanner

Build a polished scanner that saves searchable PDFs and folders.

Pros:

- familiar category with broad demand;
- document scanning APIs are mature.

Cons:

- crowded market;
- heavier product expectations;
- weaker differentiation than "extract dates/amounts into table + reminders."

## MVP Scope

### Must Have

1. Capture and import

- Import an image from Photos or Files.
- Open camera/document scanner when available.
- Store the original image reference or local copied image when practical.

2. On-device OCR

- Recognize text from the selected image with Apple Vision.
- Keep raw recognized text so the user can inspect and edit it.
- Show OCR failure states clearly.

3. Structured extraction

- Extract likely title, amount, currency, date/time, due date, phone/email, location, category, and notes.
- Use deterministic rules and confidence labels.
- Never silently save parsed data; user confirms and edits first.

4. Record table

- Save extracted items as local records.
- Fields: title, category, amount, currency, event date, due date, reminder date, source type, status, raw text, notes, createdAt, updatedAt.
- List records with search, category filter, and sort by date, amount, or title.

5. Local reminders

- Schedule local notifications for due date or event date.
- Default reminder timing: 1 day before.
- Allow reminders to be disabled per record.

6. Export

- Export saved records to CSV through the iOS share sheet.
- Include raw text optionally in CSV so power users can audit extraction.

7. Settings and privacy

- Local-only data statement in app.
- Privacy policy link.
- Delete all local data.
- No login.

### Should Have

- Simple dashboard: saved records, upcoming reminders, total amount in current month, uncategorized count.
- English and Simplified Chinese localization.
- Starter app icon and screenshots suitable for TestFlight and App Store listing.
- Manual entry path for users who do not want OCR.

### Not in Version 1

- Cloud AI parsing.
- User accounts.
- Bank/email/calendar imports.
- Automatic App Store or WeChat scraping.
- PDF multi-page OCR beyond a future import path.
- Spreadsheet formula editing.
- Team sharing.
- Tax, legal, medical, or investment advice.
- China mainland App Store availability.

## Information Architecture

The app has four main tabs:

1. Capture

- import image;
- run OCR;
- review raw text and parsed fields;
- save as a record.

2. Records

- searchable table/list;
- filters and sorting;
- detail/edit screen;
- delete records.

3. Dashboard

- upcoming reminders;
- saved record count;
- current-month amount summary;
- records missing dates or categories.

4. Settings

- default currency;
- default reminder timing;
- export CSV;
- privacy policy;
- delete all data.

## Data Model

DocumentRecord:

- id: UUID
- title: String
- category: enum notice, bill, appointment, warranty, contract, receipt, travel, school, medical, other
- amount: Decimal optional
- currencyCode: String
- eventDate: Date optional
- dueDate: Date optional
- reminderDate: Date optional
- reminderEnabled: Bool
- status: enum open, done, archived
- sourceType: enum camera, photoLibrary, fileImport, manual
- rawText: String
- notes: String
- createdAt: Date
- updatedAt: Date

Derived values:

- displayDate
- isUpcoming
- isOverdue
- requiresReview

Local persistence should use a small Codable JSON store for speed and easy source review. SwiftData can be considered later, but JSON is sufficient for the v1 data size and can be written on Windows without Xcode template dependencies.

## Parsing Rules

Version 1 parsing should be deterministic and explainable:

- detect currency symbols and ISO currency codes;
- detect amount patterns near words such as total, amount, due, paid, balance, price, fee, cost, 合计, 金额, 应付, 费用;
- detect dates in ISO, US, EU, and common Chinese formats;
- detect deadline intent near words such as due, deadline, expires, appointment, renewal, before, 截止, 到期, 预约, 缴费, 续费;
- detect phone numbers and email addresses;
- derive a title from the first meaningful OCR line or known document keywords;
- infer category from keyword lists;
- assign confidence: high when title plus date or amount exists, medium when only one key field exists, low when extraction is sparse.

When confidence is low, the app should prefill only safe fields and make review status visible.

## UX Principles

- First screen should be usable capture, not a marketing page.
- Empty states should offer Import Image and Add Manually.
- Parsed values must always be editable before saving.
- The UI should feel like a focused productivity tool, not a bloated finance app.
- Use practical language: "Review needed", "Reminder scheduled", "Export CSV".
- Do not claim guaranteed accuracy. Use "likely", "detected", and "review before saving."

## Monetization

Recommended v1:

- paid upfront app at a low global price point, such as USD 1.99 or 2.99 equivalent;
- no in-app purchases in v1.

Why:

- fastest path to release;
- avoids StoreKit and subscription-review complexity;
- no cloud AI cost before revenue exists;
- easy support story for a first-time app publisher.

Possible v1.1:

- add Pro subscription only after there is real ongoing value: batch OCR, PDF import, iCloud sync, or cloud AI parser.

## App Store Strategy

Distribution:

- Public App Store distribution.
- Select "Specific Countries or Regions".
- Include major non-China mainland storefronts at launch.
- Exclude China mainland until ICP and local compliance path is intentionally handled.

Launch metadata:

- Category: Productivity.
- Age rating: likely 4+, subject to final Apple questionnaire.
- Price: paid upfront.
- Privacy: no tracking, no account, no backend, no third-party analytics in v1.
- Privacy policy: host a simple public page before submission.

Submission notes:

- State that OCR runs on device through Apple frameworks.
- State that extracted records are stored locally on device.
- State that reminders are local notifications.
- State that users review and edit extracted values before saving.
- State that the app does not provide legal, tax, medical, financial, or investment advice.

## Technical Architecture

Native iOS app:

- SwiftUI for UI.
- XcodeGen for project generation from source-controlled `project.yml`.
- Foundation Codable JSON local persistence.
- Vision and VisionKit for on-device OCR and scanning.
- PhotosUI / file importer for image selection where available.
- UserNotifications for local reminders.
- ShareLink for CSV export.

No backend in v1.
No external AI API in v1.
No third-party analytics in v1.

## Error Handling

- OCR unavailable: show manual entry fallback.
- OCR returns no text: keep image path when possible and ask user to type or retry.
- Invalid amount: allow save without amount, but flag the field for review.
- Missing date: allow save without reminder, but do not schedule notification.
- Notification permission denied: show non-blocking settings hint.
- Export failure: show retry/share fallback.
- Corrupt local store: back up unreadable data file and start with an empty store.

## Testing Scope

Automated tests if feasible:

- amount extraction;
- date extraction;
- category inference;
- confidence scoring;
- CSV formatting;
- overdue/upcoming logic;
- JSON store round trip.

Manual verification:

- import image path opens;
- OCR text appears or failure state appears;
- parsed values can be edited before saving;
- add/edit/delete record;
- reminder scheduling does not crash when permission is denied;
- CSV export opens share sheet;
- delete all data works;
- no network permission or backend call exists.

## Open Dependencies

The user or account holder must eventually provide:

- Apple Developer Program account;
- legal developer name or organization enrollment details;
- Paid Apps Agreement, tax, and banking setup in App Store Connect;
- final app name choice after App Store availability check;
- privacy policy hosting URL;
- support URL or contact email;
- access to a Mac/Xcode or approved macOS build pipeline for signing and upload.

These are not blockers for product design or most source-code creation, but they are blockers for actual App Store submission.

## Success Criteria

The first public version is successful if:

- a new user can create a record from a screenshot in under 60 seconds;
- OCR and parsed fields are shown before saving;
- saved records are searchable and editable;
- reminders work locally;
- CSV export works;
- all data is local-only in v1;
- the app can be submitted to App Store Connect as a public paid Productivity app outside China mainland.

## Self-Review

- No placeholders remain.
- Scope is intentionally limited to one iOS utility app.
- The design avoids regulated advice, backend costs, and China mainland compliance risk in v1.
- The implementation path acknowledges the current Windows environment cannot complete native iOS signing/upload without Mac/Xcode or macOS CI.
- Monetization is aligned with fastest release rather than maximum long-term revenue.
