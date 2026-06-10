import Combine
import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var defaultCurrencyCode: String
    @Published private(set) var defaultReminderLeadDays: Int
    @Published var statusMessage: String?

    let parser: DocumentParser
    let csvExporter: CSVExporter
    let ocrService: OCRServicing
    let reminderScheduler: ReminderScheduling

    private let userDefaults: UserDefaults

    init(
        parser: DocumentParser = DocumentParser(),
        csvExporter: CSVExporter = CSVExporter(),
        ocrService: OCRServicing = VisionOCRService(),
        reminderScheduler: ReminderScheduling = ReminderScheduler(),
        userDefaults: UserDefaults = .standard
    ) {
        self.userDefaults = userDefaults
        let savedCurrencyCode = userDefaults.string(forKey: SettingsKey.defaultCurrencyCode) ?? "USD"
        _defaultCurrencyCode = Published(initialValue: Self.sanitizedCurrencyCode(savedCurrencyCode))

        let savedLeadDays = userDefaults.object(forKey: SettingsKey.defaultReminderLeadDays) == nil
            ? 1
            : userDefaults.integer(forKey: SettingsKey.defaultReminderLeadDays)
        _defaultReminderLeadDays = Published(initialValue: Self.clampedReminderLeadDays(savedLeadDays))

        self.parser = parser
        self.csvExporter = csvExporter
        self.ocrService = ocrService
        self.reminderScheduler = reminderScheduler
    }

    @discardableResult
    func setDefaultCurrencyCode(_ code: String) -> Bool {
        guard let normalized = Self.normalizedCurrencyCode(code) else { return false }
        defaultCurrencyCode = normalized
        userDefaults.set(normalized, forKey: SettingsKey.defaultCurrencyCode)
        return true
    }

    func setDefaultReminderLeadDays(_ days: Int) {
        let clamped = Self.clampedReminderLeadDays(days)
        defaultReminderLeadDays = clamped
        userDefaults.set(clamped, forKey: SettingsKey.defaultReminderLeadDays)
    }

    func parse(_ text: String) -> ParsedDocumentDraft {
        parser.parse(text, defaultCurrencyCode: defaultCurrencyCode)
    }

    func applyDefaultReminder(
        to draft: ParsedDocumentDraft,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> ParsedDocumentDraft {
        var updated = draft
        guard let displayDate = updated.displayDate else { return updated }
        updated.reminderDate = defaultReminderDate(for: displayDate, now: now, calendar: calendar)
        return updated
    }

    func scheduleReminderIfNeeded(for record: DocumentRecord) {
        Task {
            do {
                try await reminderScheduler.scheduleReminder(for: record)
                statusMessage = "Reminder scheduled."
            } catch ReminderError.permissionDenied {
                statusMessage = "Notifications are off. You can enable them in Settings."
            } catch ReminderError.missingReminderDate {
                statusMessage = "No reminder date was set."
            } catch ReminderError.reminderDateInPast {
                statusMessage = "Reminder date has already passed."
            } catch {
                statusMessage = "Reminder could not be scheduled."
            }
        }
    }

    func cancelReminder(for recordID: UUID) {
        reminderScheduler.cancelReminder(for: recordID)
    }

    private static func sanitizedCurrencyCode(_ code: String) -> String {
        normalizedCurrencyCode(code) ?? "USD"
    }

    private static func normalizedCurrencyCode(_ code: String) -> String? {
        let letters = code
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .filter(\.isLetter)
        guard letters.count == 3 else { return nil }
        return String(letters)
    }

    private static func clampedReminderLeadDays(_ days: Int) -> Int {
        min(max(days, 0), 30)
    }

    private func defaultReminderDate(for displayDate: Date, now: Date, calendar: Calendar) -> Date? {
        ReminderDatePolicy.automaticReminderDate(
            for: displayDate,
            leadDays: defaultReminderLeadDays,
            now: now,
            calendar: calendar
        )
    }

    private enum SettingsKey {
        static let defaultCurrencyCode = "settings.defaultCurrencyCode"
        static let defaultReminderLeadDays = "settings.defaultReminderLeadDays"
    }
}
