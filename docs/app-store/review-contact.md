# App Review Contact

App Store Connect requires reviewer contact information during submission. Do not commit personal contact details to this repository.

## Required Contact Fields

Prepare these values in App Store Connect before final submission:

- First name.
- Last name.
- Email address.
- Phone number with country code.

Use a contact that can respond to Apple Review during the review window.

## Local Environment Check

On the Mac used for final submission, set:

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

This validates presence and basic formatting only. The actual values still need to be entered in App Store Connect during final submission.

## Do Not Commit

- Personal phone numbers.
- Personal email addresses.
- Apple account recovery information.
- Identity documents.

## Review Notes

The review note text itself is stored in:

- `docs/app-store/review-notes.md`
- `fastlane/metadata/review_information/notes.txt`

Version 1 does not require a test account.
