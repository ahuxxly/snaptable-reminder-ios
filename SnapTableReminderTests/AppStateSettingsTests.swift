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

    private func makeTemporaryDefaults() -> (UserDefaults, String) {
        let suiteName = "SnapTableReminderTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }
}
