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
- EU Digital Services Act trader status is declared before distributing in EU storefronts.

Why this matters:

- SnapTable Reminder version 1 is planned as a paid upfront app.
- Apple requires the Paid Apps Agreement before selling paid apps.
- Tax and banking must be completed before Apple can process paid proceeds.
- Fastlane metadata and TestFlight upload use App Store Connect API credentials.
- A global release outside China mainland still includes the EU unless those storefronts are explicitly excluded.

Official references:

- App Store Connect workflow: https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-workflow/
- Set a price: https://developer.apple.com/help/app-store-connect/manage-app-pricing/set-a-price/
- View agreements status: https://developer.apple.com/help/app-store-connect/manage-agreements/view-agreements-status/
- Provide tax information: https://developer.apple.com/help/app-store-connect/manage-tax-information/provide-tax-information/
- Enter banking information: https://developer.apple.com/help/app-store-connect/manage-banking-information/enter-banking-information/
- Role permissions: https://developer.apple.com/help/app-store-connect/reference/account-management/role-permissions/
- App Store Connect API: https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-api/
- EU Digital Services Act trader requirements: https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/

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

## EU Digital Services Act Trader Status

Before submitting for App Review, complete the decision checklist in `docs/app-store/eu-dsa-trader.md`.

For version 1, the target availability is global outside China mainland, so EU storefronts remain included unless you intentionally defer them in App Store Connect. Apple requires trader status to be declared, and trader accounts need verified contact information for EU product pages.

Do not commit real DSA contact details, identity documents, business records, or address evidence to this repository.

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

## GitHub Actions Upload Secrets

For the `App Store Connect Upload` workflow, add these repository secrets in GitHub:

```text
APP_STORE_CONNECT_USERNAME
APPLE_DEVELOPER_TEAM_ID
APP_STORE_CONNECT_API_KEY_ID
APP_STORE_CONNECT_API_ISSUER_ID
APP_STORE_CONNECT_API_PRIVATE_KEY
```

Use the full `.p8` private key contents as `APP_STORE_CONNECT_API_PRIVATE_KEY`.
The workflow writes it to a temporary file outside the repository before running Fastlane.

The workflow can upload:

- App Store metadata.
- App Store screenshots.
- Fastlane precheck results.

It does not submit for review and does not upload the signed binary. TestFlight upload still requires Apple signing assets.

Windows helper:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/github-set-apple-secrets.ps1 -UploadOnly `
  -AppStoreConnectUsername "account-email" `
  -AppleDeveloperTeamId "team-id" `
  -AppStoreConnectApiKeyId "api-key-id" `
  -AppStoreConnectApiIssuerId "issuer-id" `
  -AppStoreConnectApiKeyPath "C:\path\outside\repo\AuthKey_KEYID.p8"
```

The helper writes GitHub repository secrets through the GitHub CLI and rejects key files stored inside this repository.
Add `-DryRun` first if you want to validate paths and field shapes without changing GitHub.

## GitHub Actions Signing Secrets

For the `TestFlight Upload` workflow, add the upload secrets above plus these signing secrets:

```text
APPLE_DISTRIBUTION_CERTIFICATE_BASE64
APPLE_DISTRIBUTION_CERTIFICATE_PASSWORD
APPLE_APP_STORE_PROFILE_BASE64
APPLE_CODESIGN_KEYCHAIN_PASSWORD
```

Use these values:

- `APPLE_DISTRIBUTION_CERTIFICATE_BASE64`: base64 text of the Apple Distribution `.p12` certificate.
- `APPLE_DISTRIBUTION_CERTIFICATE_PASSWORD`: password used when exporting the `.p12` certificate.
- `APPLE_APP_STORE_PROFILE_BASE64`: base64 text of the App Store provisioning profile for `com.snaptable.reminder`.
- `APPLE_CODESIGN_KEYCHAIN_PASSWORD`: a new random password used only for the temporary CI keychain.

The workflow installs the certificate into a temporary keychain, installs the provisioning profile, archives the app, and uploads the signed build to TestFlight.
Do not commit `.p12` or `.mobileprovision` files to this repository.

Windows helper:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/github-set-apple-secrets.ps1 -SigningOnly `
  -AppleDistributionCertificatePath "C:\path\outside\repo\AppleDistribution.p12" `
  -AppleAppStoreProfilePath "C:\path\outside\repo\SnapTable_AppStore.mobileprovision"
```

The helper prompts for the `.p12` password and a temporary CI keychain password without printing them.
Add `-DryRun` first if you want to validate paths without changing GitHub.

To configure upload, signing, and App Review contact secrets in one run, omit `-UploadOnly`, `-SigningOnly`, and `-ReviewOnly`, then provide all fields.

## GitHub Actions App Review Secrets

For the `App Review Submit` workflow, add the upload secrets above plus these review contact secrets:

```text
APP_REVIEW_FIRST_NAME
APP_REVIEW_LAST_NAME
APP_REVIEW_EMAIL
APP_REVIEW_PHONE
```

Windows helper:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/github-set-apple-secrets.ps1 -ReviewOnly `
  -AppReviewFirstName "first-name" `
  -AppReviewLastName "last-name" `
  -AppReviewEmail "review-contact@app-review.invalid"
```

The helper prompts for the review phone number without printing it.
Do not store personal review contact details in repository files or public GitHub issues.

## App Review Contact

Apple also requires reviewer contact information during final submission. Use `docs/app-store/review-contact.md` as the source checklist.

Set these only on the Mac or password manager session used for final submission:

```bash
export APP_REVIEW_FIRST_NAME="<first name>"
export APP_REVIEW_LAST_NAME="<last name>"
export APP_REVIEW_EMAIL="<review email>"
export APP_REVIEW_PHONE="<review phone>"
```

Then run:

```bash
bash scripts/mac-validate-review-contact-env.sh
```

Enter the same values in App Store Connect during final submission. Do not commit the real contact details to this repository.

## Do Not Commit

- `.p8` API key files.
- Apple account password.
- App-specific passwords.
- Signing certificates.
- Provisioning profiles.
- Banking documents.
- Tax documents.
- Identity documents.
- Personal App Review contact details.

## Evidence to Keep

- Screenshot or note that Paid Apps Agreement is Active.
- Screenshot or note that tax forms are submitted.
- Screenshot or note that banking is submitted.
- Bundle ID exists and matches `project.yml`.
- App Store Connect app record exists.
- EU DSA trader status is declared, or EU storefronts are intentionally excluded.
- API Key ID and Issuer ID are recorded outside the repository.
- `.p8` file is stored outside the repository.
