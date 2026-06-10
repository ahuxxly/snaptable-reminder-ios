import Combine
import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var defaultCurrencyCode = "USD"
    @Published var defaultReminderLeadDays = 1
    @Published var statusMessage: String?

    let parser: DocumentParser
    let csvExporter: CSVExporter
    let ocrService: OCRServicing
    let reminderScheduler: ReminderScheduling

    init(
        parser: DocumentParser = DocumentParser(),
        csvExporter: CSVExporter = CSVExporter(),
        ocrService: OCRServicing = VisionOCRService(),
        reminderScheduler: ReminderScheduling = ReminderScheduler()
    ) {
        self.parser = parser
        self.csvExporter = csvExporter
        self.ocrService = ocrService
        self.reminderScheduler = reminderScheduler
    }

    func parse(_ text: String) -> ParsedDocumentDraft {
        parser.parse(text, defaultCurrencyCode: defaultCurrencyCode)
    }

    func applyDefaultReminder(to draft: ParsedDocumentDraft) -> ParsedDocumentDraft {
        var updated = draft
        guard updated.reminderDate == nil, let displayDate = updated.displayDate else { return updated }
        updated.reminderDate = Calendar.current.date(byAdding: .day, value: -defaultReminderLeadDays, to: displayDate)
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
            } catch {
                statusMessage = "Reminder could not be scheduled."
            }
        }
    }

    func cancelReminder(for recordID: UUID) {
        reminderScheduler.cancelReminder(for: recordID)
    }
}
