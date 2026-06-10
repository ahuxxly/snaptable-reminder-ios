import Foundation
import UserNotifications

protocol ReminderScheduling {
    func requestAuthorization() async -> Bool
    func scheduleReminder(for record: DocumentRecord) async throws
    func cancelReminder(for recordID: UUID)
}

enum ReminderError: LocalizedError {
    case permissionDenied
    case missingReminderDate

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Notification permission was not granted."
        case .missingReminderDate:
            return "This record has no reminder date."
        }
    }
}

struct ReminderScheduler: ReminderScheduling {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    func scheduleReminder(for record: DocumentRecord) async throws {
        guard record.reminderEnabled else {
            cancelReminder(for: record.id)
            return
        }
        guard let reminderDate = record.reminderDate else { throw ReminderError.missingReminderDate }
        guard await requestAuthorization() else { throw ReminderError.permissionDenied }

        let content = UNMutableNotificationContent()
        content.title = record.title
        content.body = reminderBody(for: record)
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: identifier(for: record.id),
            content: content,
            trigger: trigger
        )

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            center.add(request) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    func cancelReminder(for recordID: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier(for: recordID)])
    }

    private func reminderBody(for record: DocumentRecord) -> String {
        if let amount = record.amount {
            return "Review \(record.currencyCode) \(NSDecimalNumber(decimal: amount).stringValue) before the date."
        }
        return "Review this saved record before the date."
    }

    private func identifier(for recordID: UUID) -> String {
        "record-\(recordID.uuidString)"
    }
}
