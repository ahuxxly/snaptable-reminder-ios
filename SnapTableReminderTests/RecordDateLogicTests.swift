import XCTest
@testable import SnapTableReminder

final class RecordDateLogicTests: XCTestCase {
    func testFutureDueDateWithinWindowIsUpcoming() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let dueDate = Calendar.current.date(byAdding: .day, value: 5, to: now)!
        let record = DocumentRecord.sample(dueDate: dueDate)

        XCTAssertTrue(record.isUpcoming(within: 7, from: now))
        XCTAssertFalse(record.isOverdue(from: now))
    }

    func testPastDueDateIsOverdue() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let dueDate = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        let record = DocumentRecord.sample(dueDate: dueDate)

        XCTAssertTrue(record.isOverdue(from: now))
        XCTAssertFalse(record.isUpcoming(within: 7, from: now))
    }

    func testRecordWithoutAnyDateRequiresReview() {
        let record = DocumentRecord.sample(eventDate: nil, dueDate: nil, reminderDate: nil)

        XCTAssertTrue(record.requiresReview)
        XCTAssertNil(record.displayDate)
    }

    func testDisplayDatePrefersDueDateOverEventDate() {
        let eventDate = Date(timeIntervalSince1970: 1_800_000_000)
        let dueDate = Date(timeIntervalSince1970: 1_800_086_400)
        let record = DocumentRecord.sample(eventDate: eventDate, dueDate: dueDate)

        XCTAssertEqual(record.displayDate, dueDate)
    }
}
