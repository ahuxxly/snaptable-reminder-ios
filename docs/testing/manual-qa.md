# Manual QA Script

## Fresh Install

1. Launch the app.
2. Confirm Capture opens without a crash.
3. Confirm empty state offers pasted text and manual entry.
4. Confirm no login or network setup is required.

## Text Parsing Fallback

1. Paste: `Tuition payment notice. Total due $128.50. Deadline 2026-07-10. Contact billing@example.invalid`.
2. Tap Parse.
3. Confirm title, amount, currency, due date, email, and confidence appear.
4. Save the record.

## Chinese Notice Parsing

1. Paste: `学校缴费通知 合计：¥380.00 截止日期：2026年7月15日 电话：13800138000`.
2. Tap Parse.
3. Confirm category, amount, CNY currency, due date, and phone are detected.
4. Save the record.

## Record CRUD

1. Add a manual appointment record dated 10 days from today.
2. Edit the title and notes.
3. Confirm Records search finds the edited title.
4. Delete the record.
5. Confirm it disappears from Records and Dashboard.

## Reminders

1. Create a record with a due date 3 days from today.
2. Enable reminder.
3. Deny notification permission and confirm the app shows a non-blocking message.
4. Enable notification permission in Settings and schedule again.

## Export

1. Add two records.
2. Open Settings.
3. Export CSV.
4. Confirm the share sheet appears.
5. Confirm CSV includes title, category, amount, currency, dates, reminder state, status, notes, and raw text.

## Reset

1. Use Settings to delete all local data.
2. Relaunch the app.
3. Confirm no records remain.

## App Review Sanity

1. Confirm privacy text says data is local-only.
2. Confirm there are no claims of legal, medical, tax, financial, or investment advice.
3. Confirm all parsed fields are editable before saving.
