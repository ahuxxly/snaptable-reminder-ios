import Foundation

struct CSVExporter {
    private let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter
    }()

    func export(_ records: [DocumentRecord]) -> String {
        let header = [
            "Title",
            "Category",
            "Amount",
            "Currency",
            "Event Date",
            "Due Date",
            "Reminder Date",
            "Reminder Enabled",
            "Status",
            "Source",
            "Phone",
            "Email",
            "Location",
            "Notes",
            "Raw Text"
        ]

        let rows = records.map { record in
            [
                record.title,
                record.category.displayName,
                decimalString(record.amount),
                record.currencyCode,
                dateString(record.eventDate),
                dateString(record.dueDate),
                dateString(record.reminderDate),
                record.reminderEnabled ? "true" : "false",
                record.status.displayName,
                record.sourceType.displayName,
                record.phoneNumber,
                record.emailAddress,
                record.location,
                record.notes,
                record.rawText
            ]
        }

        return ([header] + rows)
            .map { row in row.map(escape).joined(separator: ",") }
            .joined(separator: "\n")
    }

    func writeTemporaryCSV(_ records: [DocumentRecord], fileName: String = "snaptable-records.csv") throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        guard let data = export(records).data(using: .utf8) else {
            throw CSVExportError.encodingFailed
        }
        try data.write(to: url, options: [.atomic])
        return url
    }

    private func decimalString(_ decimal: Decimal?) -> String {
        guard let decimal else { return "" }
        return NSDecimalNumber(decimal: decimal).stringValue
    }

    private func dateString(_ date: Date?) -> String {
        guard let date else { return "" }
        return dateFormatter.string(from: date)
    }

    private func escape(_ field: String) -> String {
        let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
        if escaped.contains(",") || escaped.contains("\"") || escaped.contains("\n") {
            return "\"\(escaped)\""
        }
        return escaped
    }
}

enum CSVExportError: LocalizedError {
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "The CSV file could not be encoded."
        }
    }
}
