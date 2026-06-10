# SnapTable Reminder Launch Runbook

This is the end-to-end launch path for a first App Store release outside China mainland.

For a short current-state view, start with `docs/app-store/current-release-status.md`.

## Phase 1: Apple Account Readiness

Use `docs/app-store/account-setup.md` for the detailed 0-basics checklist.

Complete these before expecting upload or paid sales to work:

1. Join or renew Apple Developer Program.
2. Confirm App Store Connect access with Account Holder, Admin, or App Manager role.
3. Accept the current Paid Apps Agreement.
4. Complete tax information.
5. Complete banking information.
6. Confirm the legal seller name shown on App Store product pages is acceptable.

Evidence:

- App Store Connect > Business shows Paid Apps Agreement active.
- App Store Connect > Business shows tax and banking complete.

## Phase 2: Repository Hosting

1. Push this repository to GitHub.
2. Open GitHub Actions.
3. Confirm `iOS CI` runs.
4. Enable GitHub Pages using GitHub Actions.
5. Confirm `Publish App Store Site` runs.
6. Open the public `privacy.html` and `support.html` URLs.

Evidence:

- iOS CI workflow is green.
- GitHub Pages URL opens in a browser.
- Privacy URL and Support URL are copied into App Store Connect.

## Phase 3: Mac Build Readiness

On a Mac:

```bash
brew install xcodegen
bundle install
```

Run Windows preflight before moving to Mac:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/windows-preflight.ps1
```

The required Mac verification command is:

```bash
bash scripts/mac-verify.sh
```

The broader local release readiness command is:

```bash
bash scripts/mac-release-readiness.sh
```

Alternative:

```bash
bundle exec fastlane ios verify
```

Evidence:

- XcodeGen generates `SnapTableReminder.xcodeproj`.
- Tests pass.
- Simulator build passes.
- Screenshot files are staged in `fastlane/screenshots/en-US`.

If any command fails, follow `docs/testing/ci-failure-playbook.md` and keep the failing command output.

## Phase 4: App Store Connect App Record

Use `docs/app-store/app-store-fields.json` as the single source for fields that must match the app build.

1. Create a new iOS app record.
2. Use bundle ID `com.snaptable.reminder`.
3. App name candidate: `SnapTable Reminder`.
4. Primary language: English.
5. Category: Productivity.
6. Pricing: paid upfront, start at USD 1.99 equivalent.
7. Availability: selected countries or regions, excluding China mainland in version 1.

Evidence:

- App record exists.
- Bundle ID matches `project.yml`.
- China mainland is not selected.
- Pricing follows `docs/app-store/monetization-plan.md`.

## Phase 5: Metadata and Compliance

Use these repository files:

- Machine-readable fields: `docs/app-store/app-store-fields.json`
- Metadata: `docs/app-store/metadata.md`
- Fastlane metadata files: `fastlane/metadata/`
- Privacy answers: `docs/app-store/privacy-questionnaire.md`
- Review notes: `docs/app-store/review-notes.md`
- Export compliance: `docs/app-store/export-compliance.md`
- Age rating: `docs/app-store/age-rating.md`
- Privacy URL and Support URL: hosted files from `site/`

Evidence:

- Privacy section is complete.
- Age rating is complete.
- Export compliance is complete.
- Review notes are saved.

## Phase 6: Screenshots

Preferred automated path:

```bash
bash scripts/mac-capture-screenshots.sh
```

GitHub Actions alternative:

1. Run the `App Store Screenshots` workflow.
2. Download the `app-store-screenshots` artifact for raw exports.
3. Download the `fastlane-screenshots` artifact for the Fastlane upload folder.
4. Upload the screenshots to App Store Connect.

Fastlane upload path:

```bash
bundle exec fastlane ios screenshots
```

Manual path:

1. Generate project on Mac.
2. Add launch arguments `-demoData` and `-resetDemoData` to the Run scheme.
3. Run on a 6.9 inch iPhone simulator.
4. Capture the four screenshots listed in `docs/app-store/screenshot-plan.md`.
5. Remove `-demoData` and `-resetDemoData` before final manual QA.

Evidence:

- Capture, Records, Dashboard, and Settings screenshots are uploaded.
- No real private document or personal data appears in screenshots.

## Phase 7: TestFlight Upload

Manual Xcode path:

1. Configure signing team in Xcode.
2. Product > Archive.
3. Distribute App > App Store Connect > Upload.

Fastlane path:

```bash
export APP_STORE_CONNECT_USERNAME="account-holder-email"
export APPLE_DEVELOPER_TEAM_ID="team-id"
export APP_STORE_CONNECT_API_KEY_ID="api-key-id"
export APP_STORE_CONNECT_API_ISSUER_ID="issuer-id"
export APP_STORE_CONNECT_API_KEY_PATH="/absolute/path/to/AuthKey.p8"
bundle exec fastlane ios metadata
bundle exec fastlane ios screenshots
bundle exec fastlane ios testflight
```

Evidence:

- Build appears in App Store Connect > TestFlight.
- Build processing completes.

## Phase 8: Final Submission

1. Select the processed build.
2. Confirm screenshots, metadata, privacy, age rating, pricing, and availability.
3. Confirm review notes explain local-only OCR and no advice claims.
4. Submit for review.

Evidence:

- App status becomes Waiting for Review.

## Things Not to Commit

- `.p8` App Store Connect API keys.
- Signing certificates.
- Provisioning profiles.
- Exported `.ipa` files.
- Real screenshots containing private documents.
- Banking, tax, or personal identity documents.

## Version 1 Boundaries

- No backend.
- No analytics.
- No tracking.
- No account system.
- No cloud AI parser.
- No legal, medical, tax, financial, or investment advice.
- No China mainland availability in version 1.
