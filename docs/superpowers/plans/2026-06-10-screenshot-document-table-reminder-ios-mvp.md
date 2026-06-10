# Screenshot Document Table Reminder iOS MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the native iOS MVP for 截图文档转表格与提醒 / SnapTable Reminder: a local-only SwiftUI app that imports or scans screenshots/documents, extracts text on device, parses key fields into editable records, schedules local reminders, and exports CSV.

**Architecture:** The app is a small SwiftUI project generated with XcodeGen so source can be created on Windows and built later on macOS. Business logic lives in focused Swift files under `SnapTableReminder/Core`, OCR is abstracted behind `OCRService`, persistence is local JSON through `DocumentRecordStore`, and SwiftUI views use `ObservableObject` state without a backend.

**Tech Stack:** Swift 5.9+, SwiftUI, Foundation, Vision, VisionKit, PhotosUI, UniformTypeIdentifiers, UserNotifications, XCTest, XcodeGen for project generation, Xcode 15+ on macOS for final build/sign/upload.

---

## File Structure

- `.gitignore`: ignores Xcode, SwiftPM, macOS, worktree, and generated build artifacts.
- `README.md`: beginner-friendly project overview, Windows/Mac constraints, and App Store path.
- `project.yml`: XcodeGen project definition for one iOS app target and one unit test target.
- `SnapTableReminder/App/SnapTableReminderApp.swift`: SwiftUI app entry point.
- `SnapTableReminder/App/AppState.swift`: shared app state and service wiring.
- `SnapTableReminder/Core/DocumentRecord.swift`: data model, categories, status, source type, derived date helpers.
- `SnapTableReminder/Core/ParsedDocumentDraft.swift`: parser output and confidence model.
- `SnapTableReminder/Core/DocumentParser.swift`: deterministic text parser.
- `SnapTableReminder/Core/CSVExporter.swift`: CSV generation.
- `SnapTableReminder/Core/ReminderScheduler.swift`: local notification scheduling.
- `SnapTableReminder/Core/OCRService.swift`: Vision OCR service and protocol.
- `SnapTableReminder/Persistence/DocumentRecordStore.swift`: local JSON persistence.
- `SnapTableReminder/Views/CaptureView.swift`: import/paste/manual entry and parse confirmation.
- `SnapTableReminder/Views/RecordsView.swift`: searchable record list.
- `SnapTableReminder/Views/RecordFormView.swift`: add/edit form.
- `SnapTableReminder/Views/DashboardView.swift`: upcoming reminders and summary.
- `SnapTableReminder/Views/SettingsView.swift`: defaults, CSV export, privacy, reset.
- `SnapTableReminder/Views/Components/MetricTile.swift`: compact summary metric component.
- `SnapTableReminder/Resources/Assets.xcassets`: colors and app icon.
- `SnapTableReminder/Resources/Info.plist`: app permissions and launch config.
- `SnapTableReminder/Resources/Localizable.xcstrings`: English and Simplified Chinese starter strings.
- `SnapTableReminder/Resources/PrivacyInfo.xcprivacy`: privacy manifest declaring no tracking.
- `SnapTableReminderTests/DocumentParserTests.swift`: parser tests.
- `SnapTableReminderTests/CSVExporterTests.swift`: CSV tests.
- `SnapTableReminderTests/RecordDateLogicTests.swift`: upcoming/overdue tests.
- `docs/app-store/app-store-checklist.md`: release account, metadata, privacy, country availability, and submission checklist.
- `docs/app-store/privacy-policy.md`: first draft privacy policy text for hosting.
- `docs/testing/manual-qa.md`: manual QA script for TestFlight and App Review readiness.

## Task 1: Repository and XcodeGen Foundation

**Files:**
- Modify: `.gitignore`
- Create: `README.md`
- Create: `project.yml`
- Create: `docs/app-store/app-store-checklist.md`
- Create: `docs/testing/manual-qa.md`

- [ ] **Step 1: Create repository support files**

Create `README.md` with the app purpose, no-backend privacy promise, Mac build requirement, and App Store direction.

Create `project.yml` with one iOS app target named `SnapTableReminder`, one unit-test target named `SnapTableReminderTests`, iOS deployment target `17.0`, bundle id `com.snaptable.reminder`, and resources under `SnapTableReminder/Resources`.

Create `docs/app-store/app-store-checklist.md` covering Apple Developer account, Paid Apps Agreement, tax/banking, selected country/region availability excluding China mainland, privacy policy URL, support URL, screenshots, and review notes.

Create `docs/testing/manual-qa.md` with flows for fresh install, image import/OCR, paste text fallback, record CRUD, reminders, CSV export, reset, and App Store review sanity checks.

- [ ] **Step 2: Commit foundation**

Run:

```bash
git add .gitignore README.md project.yml docs/app-store/app-store-checklist.md docs/testing/manual-qa.md
git commit -m "chore: add iOS project foundation"
```

Expected: commit succeeds.

## Task 2: Core Record Model and Date Logic

**Files:**
- Create: `SnapTableReminder/Core/DocumentRecord.swift`
- Create: `SnapTableReminder/Core/ParsedDocumentDraft.swift`
- Create: `SnapTableReminderTests/RecordDateLogicTests.swift`

- [ ] **Step 1: Write date logic tests**

Tests must prove:

- a future due date within 7 days is upcoming;
- a past due date is overdue;
- a record with no due/event date requires review;
- `displayDate` prefers due date over event date.

- [ ] **Step 2: Implement model**

Implement `DocumentRecord`, `DocumentCategory`, `DocumentStatus`, `DocumentSourceType`, `ParsedDocumentDraft`, and `ParseConfidence`. Include a `sample` factory for tests and previews.

- [ ] **Step 3: Run Mac test later**

Run on macOS:

```bash
xcodegen generate
xcodebuild test -scheme SnapTableReminder -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:SnapTableReminderTests/RecordDateLogicTests
```

Expected: tests pass.

- [ ] **Step 4: Commit model**

Run:

```bash
git add SnapTableReminder/Core/DocumentRecord.swift SnapTableReminder/Core/ParsedDocumentDraft.swift SnapTableReminderTests/RecordDateLogicTests.swift
git commit -m "feat: add document record model"
```

Expected: commit succeeds.

## Task 3: Deterministic Document Parser

**Files:**
- Create: `SnapTableReminder/Core/DocumentParser.swift`
- Create: `SnapTableReminderTests/DocumentParserTests.swift`

- [ ] **Step 1: Write parser tests**

Tests must cover:

- English bill text with title, amount, USD, and due date;
- Chinese payment notice text with amount and deadline;
- appointment text with phone/email;
- sparse text returning low confidence.

- [ ] **Step 2: Implement parser**

Implement deterministic parsing with:

- currency symbol and ISO code detection;
- decimal amount detection near English and Chinese amount keywords;
- ISO, slash, US, and Chinese date format detection;
- deadline/event keyword scoring;
- phone and email regex extraction;
- category inference from keyword lists;
- confidence scoring based on extracted key fields.

- [ ] **Step 3: Run Mac parser tests later**

Run:

```bash
xcodegen generate
xcodebuild test -scheme SnapTableReminder -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:SnapTableReminderTests/DocumentParserTests
```

Expected: tests pass.

- [ ] **Step 4: Commit parser**

Run:

```bash
git add SnapTableReminder/Core/DocumentParser.swift SnapTableReminderTests/DocumentParserTests.swift
git commit -m "feat: add document text parser"
```

Expected: commit succeeds.

## Task 4: Storage, CSV Export, OCR, and Reminders

**Files:**
- Create: `SnapTableReminder/Persistence/DocumentRecordStore.swift`
- Create: `SnapTableReminder/Core/CSVExporter.swift`
- Create: `SnapTableReminder/Core/OCRService.swift`
- Create: `SnapTableReminder/Core/ReminderScheduler.swift`
- Create: `SnapTableReminder/App/AppState.swift`
- Create: `SnapTableReminderTests/CSVExporterTests.swift`

- [ ] **Step 1: Write CSV tests**

Tests must prove CSV includes title, category, amount, currency, event date, due date, reminder enabled, status, notes, and raw text with escaped quotes/newlines.

- [ ] **Step 2: Implement local JSON store**

Use `ObservableObject`, `@Published var records`, `JSONEncoder`, `JSONDecoder`, and app support directory storage. Include add, update, delete, deleteAll, and load methods. If decoding fails, move the bad JSON to a `.bak` path and start empty.

- [ ] **Step 3: Implement CSV exporter**

Generate a UTF-8 CSV string with stable column order and RFC-style quote escaping.

- [ ] **Step 4: Implement OCR service**

Create `OCRServicing` protocol and `VisionOCRService` implementation using `VNRecognizeTextRequest`. Keep the service isolated so UI can compile with a mock when needed.

- [ ] **Step 5: Implement reminders and app state**

Use `UNUserNotificationCenter` to request authorization and schedule one local notification for `reminderDate`. `AppState` wires store, parser, exporter, OCR service, and scheduler.

- [ ] **Step 6: Commit services**

Run:

```bash
git add SnapTableReminder/Core/CSVExporter.swift SnapTableReminder/Core/OCRService.swift SnapTableReminder/Core/ReminderScheduler.swift SnapTableReminder/Persistence/DocumentRecordStore.swift SnapTableReminder/App/AppState.swift SnapTableReminderTests/CSVExporterTests.swift
git commit -m "feat: add storage export ocr and reminders"
```

Expected: commit succeeds.

## Task 5: SwiftUI App Shell and Screens

**Files:**
- Create: `SnapTableReminder/App/SnapTableReminderApp.swift`
- Create: `SnapTableReminder/Views/CaptureView.swift`
- Create: `SnapTableReminder/Views/RecordsView.swift`
- Create: `SnapTableReminder/Views/RecordFormView.swift`
- Create: `SnapTableReminder/Views/DashboardView.swift`
- Create: `SnapTableReminder/Views/SettingsView.swift`
- Create: `SnapTableReminder/Views/Components/MetricTile.swift`

- [ ] **Step 1: Build app shell**

Create a `TabView` with Capture, Records, Dashboard, and Settings tabs. Inject `AppState` and `DocumentRecordStore` through environment objects.

- [ ] **Step 2: Build Capture flow**

Support pasted text first, plus image selection/import hooks for OCR. Show raw text, parsed fields, confidence, and a Save/Edit flow. Users must confirm before saving.

- [ ] **Step 3: Build Records flow**

Support search, category filter, sort menu, add manually, edit, delete, and visible review state.

- [ ] **Step 4: Build Dashboard and Settings**

Dashboard shows upcoming records, overdue count, saved record count, and current-month amount. Settings supports default currency, CSV export, local-only privacy statement, privacy policy text, and delete all data.

- [ ] **Step 5: Commit UI**

Run:

```bash
git add SnapTableReminder/App/SnapTableReminderApp.swift SnapTableReminder/Views
git commit -m "feat: add SwiftUI MVP screens"
```

Expected: commit succeeds.

## Task 6: Resources, Privacy, and Store Docs

**Files:**
- Create: `SnapTableReminder/Resources/Assets.xcassets/Contents.json`
- Create: `SnapTableReminder/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Create: `SnapTableReminder/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`
- Create: `SnapTableReminder/Resources/Info.plist`
- Create: `SnapTableReminder/Resources/Localizable.xcstrings`
- Create: `SnapTableReminder/Resources/PrivacyInfo.xcprivacy`
- Create: `docs/app-store/privacy-policy.md`
- Modify: `docs/app-store/app-store-checklist.md`

- [ ] **Step 1: Create resources**

Create Info.plist entries for display name, launch screen, photo library usage, camera usage, document camera usage note, and notification usage note. Create privacy manifest with no tracking and no collected data types. Generate a simple 1024px app icon.

- [ ] **Step 2: Create privacy policy**

State that records, raw OCR text, and reminders are stored locally; no accounts, no tracking, no third-party analytics, no backend, and no cloud AI are used in v1.

- [ ] **Step 3: Commit resources and docs**

Run:

```bash
git add SnapTableReminder/Resources docs/app-store
git commit -m "chore: add app resources and release docs"
```

Expected: commit succeeds.

## Task 7: Verification and App Store Handoff

**Files:**
- Modify: `README.md`
- Modify: `docs/testing/manual-qa.md`

- [ ] **Step 1: Run local static checks on Windows**

Run:

```bash
git status --short
rg "FIXME|ACME_CORP_MARKER" SnapTableReminder docs/app-store README.md project.yml
```

Expected: no unfinished marker text in source or release docs.

- [ ] **Step 2: Validate JSON/XML resources**

Run PowerShell JSON/XML parsing commands for `project.yml` presence, asset catalogs, `Localizable.xcstrings`, `PrivacyInfo.xcprivacy`, and `Info.plist`.

Expected: parsers do not throw.

- [ ] **Step 3: Run Mac build and tests later**

Run on macOS:

```bash
brew install xcodegen
xcodegen generate
xcodebuild test -scheme SnapTableReminder -destination 'platform=iOS Simulator,name=iPhone 15'
xcodebuild build -scheme SnapTableReminder -destination 'platform=iOS Simulator,name=iPhone 15'
```

Expected: tests and build pass.

- [ ] **Step 4: Submit later from Mac/App Store Connect**

Use Xcode archive:

```text
Product > Archive > Distribute App > App Store Connect > Upload
```

Then in App Store Connect:

```text
Create app record > set public distribution > set paid price > select specific countries/regions excluding China mainland > fill privacy > add screenshots > submit for review
```

Expected: app status becomes "Waiting for Review".

## Self-Review

Spec coverage:

- Capture/import/OCR is implemented in Tasks 4 and 5.
- Structured extraction is implemented in Task 3.
- Editable records are implemented in Tasks 2, 4, and 5.
- Local reminders are implemented in Task 4.
- CSV export is implemented in Task 4 and exposed in Task 5.
- Privacy/settings/reset are implemented in Tasks 5 and 6.
- App Store strategy is covered in Tasks 1, 6, and 7.

Completion marker scan:

- Final Apple account credentials, support URL, and hosted privacy URL remain release dependencies because they require account-holder input outside this repository.
- No code task depends on a missing type or unspecified external service.

Type consistency:

- `DocumentRecord`, `ParsedDocumentDraft`, `DocumentParser`, `DocumentRecordStore`, `CSVExporter`, `OCRServicing`, `VisionOCRService`, `ReminderScheduler`, and `AppState` are introduced before use.
- `RecordFormView` accepts either manual records or parsed drafts before `CaptureView` depends on it.
