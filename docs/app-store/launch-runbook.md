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
7. Complete the EU Digital Services Act trader status decision if EU storefronts will be included.

Evidence:

- App Store Connect > Business shows Paid Apps Agreement active.
- App Store Connect > Business shows tax and banking complete.
- App Store Connect > Business > Compliance shows DSA trader status declared, or EU storefronts are intentionally excluded.

## Phase 2: Repository Hosting

1. Push this repository to GitHub. Recommended Windows command:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/github-login-and-publish.ps1 -RepoName snaptable-reminder-ios -Visibility public
```

Then:

2. Open GitHub Actions.
3. Confirm `iOS CI` runs.
4. Enable GitHub Pages using GitHub Actions.
5. Confirm `Publish App Store Site` runs.
6. Run `Release Readiness` manually.
7. Open the public `privacy.html` and `support.html` URLs.

Evidence:

- iOS CI workflow is green.
- Release Readiness workflow is green.
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
8. EU storefronts: keep included only after completing `docs/app-store/eu-dsa-trader.md`.

Evidence:

- App record exists.
- Bundle ID matches `project.yml`.
- China mainland is not selected.
- EU DSA trader status decision is complete if EU storefronts are selected.
- Pricing follows `docs/app-store/monetization-plan.md`.

## Phase 5: Metadata and Compliance

Use these repository files:

- Machine-readable fields: `docs/app-store/app-store-fields.json`
- Metadata: `docs/app-store/metadata.md`
- Fastlane metadata files: `fastlane/metadata/`
- Privacy answers: `docs/app-store/privacy-questionnaire.md`
- Review notes: `docs/app-store/review-notes.md`
- App Review contact checklist: `docs/app-store/review-contact.md`
- EU DSA trader status checklist: `docs/app-store/eu-dsa-trader.md`
- Export compliance: `docs/app-store/export-compliance.md`
- Age rating: `docs/app-store/age-rating.md`
- Privacy URL and Support URL: hosted files from `site/`

Evidence:

- Privacy section is complete.
- Age rating is complete.
- Export compliance is complete.
- Review notes are saved.

GitHub Actions upload path:

1. Add the repository secrets with `scripts/github-set-apple-secrets.ps1`.
2. Run `scripts/github-run-app-store-release.ps1 -SkipTestFlight`.
3. Keep metadata, screenshots, and review check enabled unless you are intentionally rerunning only part of the upload.

Evidence:

- The workflow completes successfully.
- Metadata is visible in App Store Connect.
- Fastlane precheck has no error-level findings.

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

GitHub Actions upload path:

1. Add the repository secrets with `scripts/github-set-apple-secrets.ps1`.
2. Run `scripts/github-run-app-store-release.ps1 -SkipTestFlight -SkipMetadata -SkipReviewCheck`.
3. Confirm screenshots are visible in App Store Connect.

Fastlane upload path:

```bash
bundle exec fastlane ios screenshots
bundle exec fastlane ios review_check
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
bash scripts/mac-validate-upload-env.sh
bundle exec fastlane ios metadata
bundle exec fastlane ios screenshots
bundle exec fastlane ios review_check
bundle exec fastlane ios testflight
```

GitHub Actions TestFlight path:

1. Add the upload and signing secrets with `scripts/github-set-apple-secrets.ps1`.
2. Run `scripts/github-run-app-store-release.ps1`.
3. Wait for App Store Connect to finish processing the build.

GitHub Actions metadata and screenshot path:

1. Add the upload secrets with `scripts/github-set-apple-secrets.ps1`.
2. Run `scripts/github-run-app-store-release.ps1 -SkipTestFlight`.
3. Confirm the workflow summary says the requested upload steps ran.

Evidence:

- Build appears in App Store Connect > TestFlight.
- Build processing completes.
- Fastlane `review_check` has no unresolved error-level findings.

## Phase 8: Final Submission

1. Select or confirm the processed build in App Store Connect.
2. Confirm screenshots, metadata, privacy, age rating, pricing, and availability.
3. Confirm EU DSA trader status is declared if EU storefronts are selected.
4. Confirm review notes explain local-only OCR and no advice claims.
5. Enter App Review contact details from `docs/app-store/review-contact.md`.
6. Configure review contact secrets with:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/github-set-apple-secrets.ps1 -ReviewOnly
```

7. Submit with explicit confirmation:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/github-submit-app-review.ps1 -ConfirmSubmitForReview YES -Wait
```

8. On the Mac used for submission, run:

```bash
bash scripts/mac-validate-review-contact-env.sh
```

Manual fallback: Submit for review in App Store Connect.

Evidence:

- App status becomes Waiting for Review.

## Things Not to Commit

- `.p8` App Store Connect API keys.
- Signing certificates.
- Provisioning profiles.
- Exported `.ipa` files.
- Real screenshots containing private documents.
- Banking, tax, or personal identity documents.
- Personal App Review contact details.

## Version 1 Boundaries

- No backend.
- No analytics.
- No tracking.
- No account system.
- No cloud AI parser.
- No legal, medical, tax, financial, or investment advice.
- No China mainland availability in version 1.
