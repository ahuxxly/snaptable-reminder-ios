import SwiftUI

struct RecordFormView: View {
    enum Mode {
        case add(defaultCurrencyCode: String, defaultReminderLeadDays: Int)
        case addFromDraft(ParsedDocumentDraft, defaultCurrencyCode: String, sourceType: DocumentSourceType, defaultReminderLeadDays: Int)
        case edit(DocumentRecord, defaultReminderLeadDays: Int)
    }

    @Environment(\.dismiss) private var dismiss

    let mode: Mode
    let onSave: (DocumentRecord) -> Void
    private let defaultReminderLeadDays: Int

    @State private var draft: DocumentRecord
    @State private var amountText: String
    @State private var hasEventDate: Bool
    @State private var eventDate: Date
    @State private var hasDueDate: Bool
    @State private var dueDate: Date
    @State private var hasReminderDate: Bool
    @State private var reminderDate: Date

    init(mode: Mode, onSave: @escaping (DocumentRecord) -> Void) {
        self.mode = mode
        self.onSave = onSave
        self.defaultReminderLeadDays = Self.defaultReminderLeadDays(from: mode)

        let initial = Self.makeInitialRecord(from: mode)
        _draft = State(initialValue: initial)
        _amountText = State(initialValue: initial.amount.map { NSDecimalNumber(decimal: $0).stringValue } ?? "")
        _hasEventDate = State(initialValue: initial.eventDate != nil)
        _eventDate = State(initialValue: initial.eventDate ?? Date())
        _hasDueDate = State(initialValue: initial.dueDate != nil)
        _dueDate = State(initialValue: initial.dueDate ?? Date())
        _hasReminderDate = State(initialValue: initial.reminderDate != nil)
        _reminderDate = State(initialValue: initial.reminderDate ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Record") {
                    TextField("Title", text: $draft.title)
                    Picker("Category", selection: $draft.category) {
                        ForEach(DocumentCategory.allCases) { category in
                            Text(category.displayName).tag(category)
                        }
                    }
                    Picker("Status", selection: $draft.status) {
                        ForEach(DocumentStatus.allCases) { status in
                            Text(status.displayName).tag(status)
                        }
                    }
                }

                Section("Amount") {
                    TextField("Amount", text: $amountText)
                        .keyboardType(.decimalPad)
                    TextField("Currency", text: $draft.currencyCode)
                        .textInputAutocapitalization(.characters)
                }

                Section("Dates") {
                    Toggle("Event date", isOn: $hasEventDate)
                    if hasEventDate {
                        DatePicker("Event", selection: $eventDate, displayedComponents: .date)
                    }

                    Toggle("Due date", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("Due", selection: $dueDate, displayedComponents: .date)
                    }

                    Toggle("Reminder", isOn: $draft.reminderEnabled)
                    if draft.reminderEnabled {
                        Toggle("Custom reminder date", isOn: $hasReminderDate)
                        if hasReminderDate {
                            DatePicker("Reminder", selection: $reminderDate, displayedComponents: [.date, .hourAndMinute])
                            if !ReminderDatePolicy.isSchedulable(reminderDate) {
                                Text("Choose a future reminder time.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        } else if !hasEventDate && !hasDueDate {
                            Text("Add an event or due date, or choose a custom reminder date.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else if automaticReminderDate() == nil {
                            Text("Choose a future event or due date, or turn reminders off.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Contact") {
                    TextField("Phone", text: $draft.phoneNumber)
                        .keyboardType(.phonePad)
                    TextField("Email", text: $draft.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    TextField("Location", text: $draft.location)
                }

                Section("Notes") {
                    TextEditor(text: $draft.notes)
                        .frame(minHeight: 88)
                }

                if !draft.rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Section("Recognized Text") {
                        TextEditor(text: $draft.rawText)
                            .font(.footnote.monospaced())
                            .frame(minHeight: 140)
                    }
                }
            }
            .navigationTitle(navigationTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(makeSavedRecord())
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private var navigationTitle: String {
        switch mode {
        case .edit(_, _):
            return "Edit Record"
        case .add(_, _), .addFromDraft(_, _, _, _):
            return "Add Record"
        }
    }

    private var isValid: Bool {
        !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !draft.currencyCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        reminderSelectionIsValid &&
        (amountText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || Decimal(string: amountText) != nil)
    }

    private var reminderSelectionIsValid: Bool {
        guard draft.reminderEnabled else { return true }
        if hasReminderDate {
            return ReminderDatePolicy.isSchedulable(reminderDate)
        }
        return automaticReminderDate() != nil
    }

    private func makeSavedRecord() -> DocumentRecord {
        var saved = draft
        saved.amount = amountText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : Decimal(string: amountText)
        saved.currencyCode = saved.currencyCode.uppercased()
        saved.eventDate = hasEventDate ? eventDate : nil
        saved.dueDate = hasDueDate ? dueDate : nil
        if saved.reminderEnabled {
            saved.reminderDate = hasReminderDate ? reminderDate : automaticReminderDate()
        } else {
            saved.reminderDate = nil
        }
        saved.updatedAt = Date()
        return saved
    }

    private func automaticReminderDate(now: Date = Date(), calendar: Calendar = .current) -> Date? {
        let displayDate = hasDueDate ? dueDate : (hasEventDate ? eventDate : nil)
        guard let displayDate else { return nil }
        return ReminderDatePolicy.automaticReminderDate(
            for: displayDate,
            leadDays: defaultReminderLeadDays,
            now: now,
            calendar: calendar
        )
    }

    private static func makeInitialRecord(from mode: Mode) -> DocumentRecord {
        switch mode {
        case .edit(let record, _):
            return record
        case .add(let defaultCurrencyCode, _):
            var record = DocumentRecord.sample(
                title: "",
                category: .other,
                amount: nil,
                currencyCode: defaultCurrencyCode,
                eventDate: nil,
                dueDate: nil,
                reminderDate: nil,
                reminderEnabled: false,
                sourceType: .manual,
                rawText: "",
                notes: ""
            )
            record.id = UUID()
            record.createdAt = Date()
            record.updatedAt = Date()
            return record
        case .addFromDraft(let draft, let defaultCurrencyCode, let sourceType, _):
            return draft.makeRecord(defaultCurrencyCode: defaultCurrencyCode, sourceType: sourceType)
        }
    }

    private static func defaultReminderLeadDays(from mode: Mode) -> Int {
        switch mode {
        case .add(_, let defaultReminderLeadDays):
            return defaultReminderLeadDays
        case .addFromDraft(_, _, _, let defaultReminderLeadDays):
            return defaultReminderLeadDays
        case .edit(_, let defaultReminderLeadDays):
            return defaultReminderLeadDays
        }
    }
}
