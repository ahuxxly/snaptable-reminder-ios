import Foundation

enum DocumentCategory: String, Codable, CaseIterable, Identifiable {
    case notice
    case bill
    case appointment
    case warranty
    case contract
    case receipt
    case travel
    case school
    case medical
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .notice: return "Notice"
        case .bill: return "Bill"
        case .appointment: return "Appointment"
        case .warranty: return "Warranty"
        case .contract: return "Contract"
        case .receipt: return "Receipt"
        case .travel: return "Travel"
        case .school: return "School"
        case .medical: return "Medical"
        case .other: return "Other"
        }
    }
}

enum DocumentStatus: String, Codable, CaseIterable, Identifiable {
    case open
    case done
    case archived

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .open: return "Open"
        case .done: return "Done"
        case .archived: return "Archived"
        }
    }
}

enum DocumentSourceType: String, Codable, CaseIterable, Identifiable {
    case camera
    case photoLibrary
    case fileImport
    case pastedText
    case manual

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .camera: return "Camera"
        case .photoLibrary: return "Photo"
        case .fileImport: return "File"
        case .pastedText: return "Pasted Text"
        case .manual: return "Manual"
        }
    }
}

struct DocumentRecord: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var category: DocumentCategory
    var amount: Decimal?
    var currencyCode: String
    var eventDate: Date?
    var dueDate: Date?
    var reminderDate: Date?
    var reminderEnabled: Bool
    var status: DocumentStatus
    var sourceType: DocumentSourceType
    var rawText: String
    var notes: String
    var phoneNumber: String
    var emailAddress: String
    var location: String
    var createdAt: Date
    var updatedAt: Date

    var displayDate: Date? {
        dueDate ?? eventDate
    }

    var requiresReview: Bool {
        displayDate == nil
    }

    func isUpcoming(within days: Int = 7, from now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard status == .open, let displayDate else { return false }
        let start = calendar.startOfDay(for: now)
        let end = calendar.startOfDay(for: displayDate)
        guard let delta = calendar.dateComponents([.day], from: start, to: end).day else { return false }
        return delta >= 0 && delta <= days
    }

    func isOverdue(from now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard status == .open, let displayDate else { return false }
        return calendar.startOfDay(for: displayDate) < calendar.startOfDay(for: now)
    }
}

extension DocumentRecord {
    static func sample(
        title: String = "Payment Notice",
        category: DocumentCategory = .bill,
        amount: Decimal? = Decimal(128.50),
        currencyCode: String = "USD",
        eventDate: Date? = nil,
        dueDate: Date? = Date(timeIntervalSince1970: 1_800_000_000),
        reminderDate: Date? = Date(timeIntervalSince1970: 1_799_913_600),
        reminderEnabled: Bool = true,
        status: DocumentStatus = .open,
        sourceType: DocumentSourceType = .pastedText,
        rawText: String = "Payment notice total $128.50 due 2027-01-15",
        notes: String = ""
    ) -> DocumentRecord {
        DocumentRecord(
            id: UUID(),
            title: title,
            category: category,
            amount: amount,
            currencyCode: currencyCode,
            eventDate: eventDate,
            dueDate: dueDate,
            reminderDate: reminderDate,
            reminderEnabled: reminderEnabled,
            status: status,
            sourceType: sourceType,
            rawText: rawText,
            notes: notes,
            phoneNumber: "",
            emailAddress: "",
            location: "",
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )
    }
}
