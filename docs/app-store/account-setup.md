# App Store Account Setup

Use this checklist before attempting paid App Store upload, TestFlight upload, or Fastlane metadata upload.

## Required Account State

- Apple Developer Program membership is active.
- App Store Connect access is available.
- The Account Holder is reachable for legal and billing steps.
- Paid Apps Agreement is accepted in App Store Connect Business.
- Tax information is submitted.
- Banking information is submitted.
- App Store Connect API access is available.
- Bundle ID `com.snaptable.reminder` is available to this Apple Developer team.

Why this matters:

- SnapTable Reminder version 1 is planned as a paid upfront app.
- Apple requires the Paid Apps Agreement before selling paid apps.
- Tax and banking must be completed before Apple can process paid proceeds.
- Fastlane metadata and TestFlight upload use App Store Connect API credentials.

Official references:

- App Store Connect workflow: https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-workflow/
- Set a price: https://developer.apple.com/help/app-store-connect/manage-app-pricing/set-a-price/
- View agreements status: https://developer.apple.com/help/app-store-connect/manage-agreements/view-agreements-status/
- Provide tax information: https://developer.apple.com/help/app-store-connect/manage-tax-information/provide-tax-information/
- Enter banking information: https://developer.apple.com/help/app-store-connect/manage-banking-information/enter-banking-information/
- Role permissions: https://developer.apple.com/help/app-store-connect/reference/account-management/role-permissions/
- App Store Connect API: https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-api/

## Role Notes

- Account Holder can sign legal agreements, renew membership, and request App Store Connect API access.
- Account Holder or Admin can generate team API keys.
- Account Holder, Admin, App Manager, or Developer can upload builds, depending on the account configuration.
- Account Holder, Admin, or Finance can manage banking information.

If you are using an individual developer account, you are usually the Account Holder.

## Create the Bundle ID

In Apple Developer:

1. Open Certificates, Identifiers & Profiles.
2. Create an App ID for iOS.
3. Use bundle ID `com.snaptable.reminder`.
4. Enable only the capabilities the app uses in version 1.

Version 1 capabilities should stay small:

- Camera usage through iOS permission.
- Photo library user-selected import.
- Local notifications.

Do not add iCloud, Sign in with Apple, App Groups, HealthKit, payments, or push notifications for version 1 unless the app code is intentionally changed to use them.

## Create the App Store Connect App Record

In App Store Connect:

1. Open Apps.
2. Create a new app.
3. Platform: iOS.
4. Name: `SnapTable Reminder`.
5. Primary language: `English (U.S.)`.
6. Bundle ID: `com.snaptable.reminder`.
7. SKU: `SNAPTABLE-REMINDER-IOS-V1`.
8. User Access: full access for the account holder.

Use `docs/app-store/app-store-fields.json` as the field source.

## Generate App Store Connect API Key

In App Store Connect:

1. Open Users and Access.
2. Open Integrations.
3. If API access is not enabled, the Account Holder requests access.
4. Open Team Keys.
5. Generate an API key.
6. Use a clear internal name such as `SnapTable Reminder Fastlane`.
7. Give the key enough access for app metadata and build upload.
8. Download the `.p8` key file immediately.
9. Record the Key ID and Issuer ID.

Apple only lets you download the private key once. Store it outside this repository.

## Mac Environment Variables

Set these only on the Mac or CI secret store that performs upload:

```bash
export APP_STORE_CONNECT_USERNAME="account-email"
export APPLE_DEVELOPER_TEAM_ID="team-id"
export APP_STORE_CONNECT_API_KEY_ID="key-id"
export APP_STORE_CONNECT_API_ISSUER_ID="issuer-id"
export APP_STORE_CONNECT_API_KEY_PATH="/absolute/path/to/AuthKey.p8"
```

Then run:

```bash
bash scripts/mac-validate-upload-env.sh
bundle exec fastlane ios metadata
bundle exec fastlane ios screenshots
bundle exec fastlane ios review_check
bundle exec fastlane ios testflight
```

## Do Not Commit

- `.p8` API key files.
- Apple account password.
- App-specific passwords.
- Signing certificates.
- Provisioning profiles.
- Banking documents.
- Tax documents.
- Identity documents.

## Evidence to Keep

- Screenshot or note that Paid Apps Agreement is Active.
- Screenshot or note that tax forms are submitted.
- Screenshot or note that banking is submitted.
- Bundle ID exists and matches `project.yml`.
- App Store Connect app record exists.
- API Key ID and Issuer ID are recorded outside the repository.
- `.p8` file is stored outside the repository.
