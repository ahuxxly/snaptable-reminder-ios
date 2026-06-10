import Foundation
import XCTest
@testable import SnapTableReminder

final class ReminderDatePolicyTests: XCTestCase {
    func testUsesLeadDateWhenItIsFuture() {
        let result = ReminderDatePolicy.automaticReminderDate(
            for: makeDate(year: 2030, month: 6, day: 10),
            leadDays: 3,
            now: makeDate(year: 2030, month: 1, day: 1),
            calendar: Calendar(identifier: .gregorian)
        )

        XCTAssertDate(result, year: 2030, month: 6, day: 7)
    }

    func testFallsBackToDisplayDateWhenLeadDateIsPast() {
        let result = ReminderDatePolicy.automaticReminderDate(
            for: makeDate(year: 2030, month: 1, day: 2),
            leadDays: 3,
            now: makeDate(year: 2030, month: 1, day: 1),
            calendar: Calendar(identifier: .gregorian)
        )

        XCTAssertDate(result, year: 2030, month: 1, day: 2)
    }

    func testReturnsNilWhenDisplayDateIsPast() {
        let result = ReminderDatePolicy.automaticReminderDate(
            for: makeDate(year: 2029, month: 12, day: 31),
            leadDays: 3,
            now: makeDate(year: 2030, month: 1, day: 1),
            calendar: Calendar(identifier: .gregorian)
        )

        XCTAssertNil(result)
    }

    func testNegativeLeadDaysBehaveLikeZero() {
        let result = ReminderDatePolicy.automaticReminderDate(
            for: makeDate(year: 2030, month: 1, day: 3),
            leadDays: -2,
            now: makeDate(year: 2030, month: 1, day: 1),
            calendar: Calendar(identifier: .gregorian)
        )

        XCTAssertDate(result, year: 2030, month: 1, day: 3)
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
