# Version 1 Monetization Plan

This plan keeps the app small enough to ship quickly while still giving it a real chance to recover AI tooling costs.

## Revenue Model

Use paid upfront pricing for version 1.

Do not add subscriptions, in-app purchases, accounts, trials, server OCR, or cloud AI parsing in the first release. Those features add StoreKit, support, compliance, and backend work before the product has demand evidence.

Recommended first release:

- Model: Paid app
- Starting price: USD 1.99 equivalent
- Backup price: USD 2.99 equivalent after early validation
- Distribution method: Public App Store
- Availability: all available countries and regions except China mainland for version 1

Why:

- No backend cost per user.
- No cloud AI cost per document.
- No account or billing support surface.
- Simpler privacy answers.
- Clear user promise: pay once for a local utility.

## Break-Even Formula

Use actual App Store Connect financial reports for final math because taxes, proceeds, and currency conversions vary by country or region.

Planning formula:

```text
required_monthly_paid_downloads = monthly_ai_tooling_cost / net_proceeds_per_paid_download
```

Example planning table:

| Monthly AI tooling cost | Net proceeds per download | Paid downloads needed |
| --- | ---: | ---: |
| USD 20 | USD 1.20 | 17 |
| USD 50 | USD 1.20 | 42 |
| USD 100 | USD 1.20 | 84 |
| USD 20 | USD 1.80 | 12 |
| USD 50 | USD 1.80 | 28 |
| USD 100 | USD 1.80 | 56 |

Treat this table as planning math only. Replace the net proceeds value with the actual number from App Store Connect after the first sales report.

## Pricing Setup in App Store Connect

Apple path:

1. Open App Store Connect.
2. Select the app.
3. Open Monetization > Pricing and Availability.
4. In Price Schedule, choose Add Pricing.
5. Set the base country or region.
6. Pick the paid price.
7. Keep the first release simple: one current price, no scheduled price experiments.

Official reference:

- Apple Set a price: https://developer.apple.com/help/app-store-connect/manage-app-pricing/set-a-price/

## Availability Setup

Apple path:

1. Open App Store Connect.
2. Select the app.
3. Open Pricing and Availability.
4. Under App Distribution Methods, use Public.
5. Under App Availability, choose selected countries and regions.
6. Exclude China mainland in version 1.
7. If another country or region shows a tax or compliance warning, do not delay the whole release. Fix that market after the first launch unless it is strategically essential.

Official references:

- Apple Set distribution methods: https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/set-distribution-methods/
- Apple Manage availability: https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/manage-availability-for-your-app-on-the-app-store/
- Apple app status notes for China mainland ICP and Brazil tax states: https://developer.apple.com/help/app-store-connect/reference/app-information/app-and-submission-statuses/

## China Mainland Version 1 Decision

Exclude China mainland from the first release.

Reason:

- Apple documents that Chinese law can require additional app documentation and that MIIT may require a valid ICP Filing Number for some apps.
- Version 1 is a fast validation release. The goal is to get a paid utility live and gather demand evidence before taking on local compliance work.

Official reference:

- Apple App information, Availability in China mainland: https://developer.apple.com/help/app-store-connect/reference/app-information/app-information/

## Launch Measurement

Use only App Store Connect data in version 1:

- Product page views
- App units
- Proceeds
- Refund signals
- Ratings and reviews
- Support requests

Do not add third-party analytics for version 1. The current privacy promise is stronger and easier to review without it.

## First 30 Days

Day 0:

- Launch at USD 1.99 equivalent.
- Use the listing copy in `docs/app-store/metadata.md`.
- Monitor review status and support messages.

Days 1-7:

- Fix crash, OCR, export, or reminder bugs only.
- Do not add broad new features until the app is stable.

Days 8-30:

- If paid downloads are happening and reviews/support are calm, test USD 2.99 equivalent.
- If there are no paid downloads, improve screenshots, subtitle, and keywords before adding features.
- If refunds mention accuracy, tighten the listing promise and add better example screenshots.

## Support and Refund Positioning

Support response posture:

- Help users with OCR expectations, CSV export, reminders, and deleting data.
- Do not promise perfect extraction.
- Remind users that every parsed field should be reviewed before acting.

Refund posture:

- Purchase and refund handling is managed through Apple's App Store purchase flow.
- Keep support focused on product help and bug reports.

## Version 2 Monetization Options

Consider only after version 1 has demand:

- Paid app price increase.
- Separate pro version for batch import.
- Optional tip jar.
- Subscription only if adding ongoing cloud services or cross-device sync.

Avoid adding cloud AI parsing until the app already earns enough to cover variable API cost.
