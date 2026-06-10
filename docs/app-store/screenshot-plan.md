# App Store Screenshot Plan

Use this plan after the app builds on a Mac. Apple currently accepts 6.9 inch iPhone screenshots for the primary iPhone screenshot set. The app includes a screenshot data mode triggered by the launch argument `-demoData`.

Official reference:

- https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/

## Automated Capture

Run on a Mac:

```bash
bash scripts/mac-capture-screenshots.sh
```

The script generates the Xcode project, runs `SnapTableReminderUITests`, and exports XCTest screenshot attachments to `build/app-store-screenshots`.

GitHub Actions path:

1. Push the repository to GitHub.
2. Open Actions.
3. Run `App Store Screenshots`.
4. Download the `app-store-screenshots` artifact.
5. Upload the exported screenshots to App Store Connect.

Preferred simulators:

- iPhone 17 Pro Max
- iPhone Air
- iPhone 16 Pro Max
- iPhone 16 Plus
- iPhone 15 Pro Max
- iPhone 15 Plus
- iPhone 14 Pro Max

If the preferred simulator is not installed, install one in Xcode or set:

```bash
export SCREENSHOT_SIMULATOR_ID="simulator-uuid"
```

## Prepare Demo Data

Manual Xcode path:

1. Open the generated project.
2. Edit the active scheme.
3. Go to Run > Arguments.
4. Add launch argument `-demoData`.
5. Run the app on a 6.9 inch iPhone simulator.

The app seeds three local records only when the store is empty.

## Required Screens

Capture:

- Show the Scan, Import Image, Manual, text editor, and Parse and Review button.
- Caption idea: "Turn screenshots into editable records."

Records:

- Show seeded records with dates and categories.
- Caption idea: "Keep notices, bills, and appointments searchable."

Dashboard:

- Show Saved Records, Next 7 Days, Overdue, This Month, and upcoming items.
- Caption idea: "See what needs attention next."

Settings:

- Show CSV export and local-only privacy text.
- Caption idea: "Export CSV. Keep data local."

## After Screenshots

Remove the `-demoData` launch argument before manual QA or App Review testing.

## Notes

- Use light mode for the first release screenshots.
- Use English screenshots first; add Simplified Chinese later if localization is expanded beyond starter strings.
- Do not show private real documents or personal data.
