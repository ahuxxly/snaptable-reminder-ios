# App Store Screenshot Plan

Use this plan after the app builds on a Mac. The app includes a screenshot data mode triggered by the launch argument `-demoData`.

## Prepare Demo Data

In Xcode:

1. Open the generated project.
2. Edit the active scheme.
3. Go to Run > Arguments.
4. Add launch argument `-demoData`.
5. Run the app on a 6.7 inch iPhone simulator.

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
