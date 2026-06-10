import Foundation

enum ParseConfidence: String, Codable, CaseIterable, Identifiable {
    case high
    case medium
    case low

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }
}

struct ParsedDocumentDraft: Equatable {
    var title: String?
    var category: DocumentCategory
    var amount: Decimal?
    var currencyCode: String?
    var eventDate: Date?
    var dueDate: Date?
    var reminderDate: Date?
    var phoneNumber: String?
    var emailAddress: String?
    var location: String?
    var rawText: String
    var confidence: ParseConfidence
    var notes: String

    var displayDate: Date? {
        dueDate ?? eventDate
    }

    func makeRecord(defaultCurrencyCode: String = "USD", sourceType: DocumentSourceType = .pastedText) -> DocumentRecord {
        let now = Date()
        let cleanedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return DocumentRecord(
            id: UUID(),
            title: cleanedTitle.isEmpty ? "Untitled Record" : cleanedTitle,
            category: category,
            amount: amount,
            currencyCode: currencyCode ?? defaultCurrencyCode,
            eventDate: eventDate,
            dueDate: dueDate,
            reminderDate: reminderDate,
            reminderEnabled: reminderDate != nil,
            status: .open,
            sourceType: sourceType,
            rawText: rawText,
            notes: notes,
            phoneNumber: phoneNumber ?? "",
            emailAddress: emailAddress ?? "",
            location: location ?? "",
            createdAt: now,
            updatedAt: now
        )
    }
}
