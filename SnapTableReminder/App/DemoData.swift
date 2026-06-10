import Foundation

enum DemoData {
    static func seedIfRequested(into store: DocumentRecordStore) {
        guard ProcessInfo.processInfo.arguments.contains("-demoData") else { return }
        guard store.records.isEmpty else { return }
        store.replaceAll(sampleRecords())
    }

    private static func sampleRecords() -> [DocumentRecord] {
        let calendar = Calendar.current
        let now = Date()
        let tuitionDue = calendar.date(byAdding: .day, value: 5, to: now)
        let appointmentDate = calendar.date(byAdding: .day, value: 9, to: now)
        let warrantyDate = calendar.date(byAdding: .month, value: 2, to: now)

        var tuition = DocumentRecord.sample(
            title: "Tuition Payment Notice",
            category: .school,
            amount: Decimal(string: "128.50"),
            currencyCode: "USD",
            eventDate: nil,
            dueDate: tuitionDue,
            reminderDate: calendar.date(byAdding: .day, value: -1, to: tuitionDue ?? now),
            reminderEnabled: true,
            sourceType: .pastedText,
            rawText: "Tuition payment notice\nTotal due $128.50\nDeadline \(formatted(tuitionDue))",
            notes: "Review before the school payment deadline."
        )
        tuition.emailAddress = "billing@school.invalid"

        var appointment = DocumentRecord.sample(
            title: "Dental Appointment",
            category: .medical,
            amount: nil,
            currencyCode: "USD",
            eventDate: appointmentDate,
            dueDate: nil,
            reminderDate: calendar.date(byAdding: .day, value: -1, to: appointmentDate ?? now),
            reminderEnabled: true,
            sourceType: .photoLibrary,
            rawText: "Dental appointment at Main Clinic\nDate \(formatted(appointmentDate))",
            notes: "Bring ID card and insurance card."
        )
        appointment.phoneNumber = "13800138000"
        appointment.location = "Main Clinic"

        let warranty = DocumentRecord.sample(
            title: "Laptop Warranty",
            category: .warranty,
            amount: nil,
            currencyCode: "USD",
            eventDate: nil,
            dueDate: warrantyDate,
            reminderDate: calendar.date(byAdding: .day, value: -7, to: warrantyDate ?? now),
            reminderEnabled: true,
            sourceType: .camera,
            rawText: "Laptop warranty expires \(formatted(warrantyDate))",
            notes: "Save receipt before warranty expires."
        )

        return [tuition, appointment, warranty]
    }

    private static func formatted(_ date: Date?) -> String {
        guard let date else { return "" }
        return date.formatted(date: .numeric, time: .omitted)
    }
}
