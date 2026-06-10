# EU Digital Services Act Trader Status

SnapTable Reminder version 1 is planned as a paid upfront app distributed globally outside China mainland. That availability plan includes the European Union unless EU countries are explicitly removed in App Store Connect.

Apple requires every developer to declare trader status. If the app is distributed on the App Store in the EU and the developer qualifies as a trader, Apple verifies and displays trader contact information on the App Store product page.

This document is operational release guidance, not legal advice. If there is uncertainty about trader status, consult a legal advisor before submission.

## Version 1 Decision Point

Before App Review submission, choose one path:

1. Include EU storefronts in version 1.
   - Complete the Digital Services Act trader status flow in App Store Connect.
   - If the account is a trader account, provide and verify the required public contact information.
   - Keep EU countries selected in Pricing and Availability.

2. Defer EU storefronts for version 1.
   - Exclude EU countries in Pricing and Availability.
   - Record the choice in the launch evidence.
   - Re-add EU only after DSA status is complete.

The current product plan favors path 1 because the requested launch is global outside China mainland.

## Why This Matters

SnapTable Reminder is planned as a paid app intended to recover development and AI tooling costs. Apple lists revenue generation, commercial practices, VAT registration, and acting in a business or professional capacity as factors in trader self-assessment.

Do not assume "individual developer" means "not a trader." Apple says trader status is a self-assessment and Apple cannot determine it for you.

## App Store Connect Steps

Required role: Account Holder or Admin.

Account-level DSA flow:

1. Open App Store Connect.
2. Open Business.
3. On Agreements, scroll to Compliance.
4. Next to Digital Services Act, complete the compliance requirements.
5. Choose trader or not trader status.
6. If trader, verify the required contact details and any requested documentation.

App-specific flow:

1. Open Apps.
2. Select SnapTable Reminder.
3. Open App Information.
4. Scroll to App Store Regulations and Permits.
5. Under Digital Services Act, confirm the app-specific trader status.

## Information to Prepare

For organizations:

- Phone number for product-page display.
- Email address for product-page display.
- D-U-N-S address is used by Apple for the displayed address.

For individual developers who are traders:

- Address or P.O. Box for product-page display.
- Phone number for product-page display.
- Email address for product-page display.

For all traders:

- Payment account details in App Store Connect.
- Certification that offered products or services comply with applicable EU law.
- Email and phone verification.
- Business or legal records if Apple requests documentation.

## Evidence to Keep

Do not commit real contact details or documents. Store the evidence in a private password manager or private release folder outside this repository.

Keep private evidence for:

- Account-level DSA status completed.
- App-specific DSA status confirmed for SnapTable Reminder.
- Whether EU storefronts are included or deferred.
- Contact information verification completed if the account is a trader account.

## Official References

- Apple DSA trader requirements: https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/
- Apple notice that apps without trader status are removed from the EU App Store: https://developer.apple.com/news/?id=einwn76m
