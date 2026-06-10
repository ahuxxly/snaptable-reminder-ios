import Foundation

enum ReminderDatePolicy {
    static func automaticReminderDate(
        for displayDate: Date,
        leadDays: Int,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Date? {
        let safeLeadDays = max(0, leadDays)
        let candidate = calendar.date(byAdding: .day, value: -safeLeadDays, to: displayDate)
        if let candidate, isSchedulable(candidate, now: now) {
            return candidate
        }
        return isSchedulable(displayDate, now: now) ? displayDate : nil
    }

    static func isSchedulable(_ date: Date, now: Date = Date()) -> Bool {
        date >= now
    }
}
