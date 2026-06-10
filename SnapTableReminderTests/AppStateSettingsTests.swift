import Foundation
import XCTest
@testable import SnapTableReminder

@MainActor
final class AppStateSettingsTests: XCTestCase {
    func testPersistsDefaultSettingsAcrossInstances() {
        let (defaults, suiteName) = makeTemporaryDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let first = AppState(userDefaults: defaults)
        first.setDefaultCurrencyCode(" eur ")
        first.setDefaultReminderLeadDays(9)

        let restored = AppState(userDefaults: defaults)

        XCTAssertEqual(restored.defaultCurrencyCode, "EUR")
        XCTAssertEqual(restored.defaultReminderLeadDays, 9)
    }

    func testSanitizesAndClampsDefaultSettings() {
        let (defaults, suiteName) = makeTemporaryDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let state = AppState(userDefaults: defaults)

        XCTAssertTrue(state.setDefaultCurrencyCode(" eur "))
        XCTAssertEqual(state.defaultCurrencyCode, "EUR")

        XCTAssertFalse(state.setDefaultCurrencyCode("usdollars"))
        XCTAssertEqual(state.defaultCurrencyCode, "EUR")

        XCTAssertFalse(state.setDefaultCurrencyCode(""))
        XCTAssertEqual(state.defaultCurrencyCode, "EUR")

        state.setDefaultReminderLeadDays(99)
        XCTAssertEqual(state.defaultReminderLeadDays, 30)

        state.setDefaultReminderLeadDays(-4)
        XCTAssertEqual(state.defaultReminderLeadDays, 0)
    }

    func testParserUsesPersistedDefaultCurrency() {
        let (defaults, suiteName) = makeTemporaryDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let state = AppState(userDefaults: defaults)
        state.setDefaultCurrencyCode("eur")

        let result = state.parse("Membership renewal amount 9.99 due 2026-08-01")

        XCTAssertEqual(result.currencyCode, "EUR")
    }

    func testDefaultReminderLeadDaysAppliesToDraft() {
        let (defaults, suiteName) = makeTemporaryDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let state = AppState(userDefaults: defaults)
        state.setDefaultReminderLeadDays(3)
        let dueDate = makeDate(year: 2030, month: 6, day: 10)
        let staleReminderDate = makeDate(year: 2030, month: 6, day: 9)
        let draft = makeDraft(dueDate: dueDate, reminderDate: staleReminderDate)

        let updated = state.applyDefaultReminder(
            to: draft,
            now: makeDate(year: 2030, month: 1, day: 1),
            calendar: Calendar(identifier: .gregorian)
        )

        XCTAssertDate(updated.reminderDate, year: 2030, month: 6, day: 7)
    }

    func testDefaultReminderFallsBackWhenLeadDateWouldBePast() {
        let (defaults, suiteName) = makeTemporaryDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let state = AppState(userDefaults: defaults)
        state.setDefaultReminderLeadDays(3)
        let dueDate = makeDate(year: 2030, month: 1, day: 2)
        let draft = makeDraft(dueDate: dueDate, reminderDate: nil)

        let updated = state.applyDefaultReminder(
            to: draft,
            now: makeDate(year: 2030, month: 1, day: 1),
            calendar: Calendar(identifier: .gregorian)
        )

        XCTAssertDate(updated.reminderDate, year: 2030, month: 1, day: 2)
    }

    private func makeTemporaryDefaults() -> (UserDefaults, String) {
        let suiteName = "SnapTableReminderTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }

    private func makeDraft(dueDate: Date, reminderDate: Date?) -> ParsedDocumentDraft {
        ParsedDocumentDraft(
            title: "Payment Notice",
            category: .bill,
            amount: nil,
            currencyCode: nil,
            eventDate: nil,
            dueDate: dueDate,
            reminderDate: reminderDate,
            phoneNumber: nil,
            emailAddress: nil,
            location: nil,
            rawText: "Payment notice",
            confidence: .medium,
            notes: ""
        )
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.year = year
        components.month = month
        components.day = day
        return components.date!
    }

    private func XCTAssertDate(
        _ date: Date?,
        year: Int,
        month: Int,
        day: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let components = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: date ?? Date.distantPast)
        XCTAssertEqual(components.year, year, file: file, line: line)
        XCTAssertEqual(components.month, month, file: file, line: line)
        XCTAssertEqual(components.day, day, file: file, line: line)
    }
}
