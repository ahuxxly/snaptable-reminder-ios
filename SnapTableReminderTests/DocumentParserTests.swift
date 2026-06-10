import XCTest
@testable import SnapTableReminder

final class DocumentParserTests: XCTestCase {
    func testParsesEnglishBillText() {
        let text = """
        Tuition payment notice
        Total due $128.50
        Deadline 2026-07-10
        Contact billing@example.invalid
        """

        let result = DocumentParser().parse(text)

        XCTAssertEqual(result.title, "Tuition payment notice")
        XCTAssertEqual(result.category, .school)
        XCTAssertEqual(result.amount, Decimal(string: "128.50"))
        XCTAssertEqual(result.currencyCode, "USD")
        XCTAssertEqual(result.emailAddress, "billing@example.invalid")
        XCTAssertEqual(result.confidence, .high)
        XCTAssertDate(result.dueDate, year: 2026, month: 7, day: 10)
    }

    func testParsesChinesePaymentNotice() {
        let text = "学校缴费通知 合计：¥380.00 截止日期：2026年7月15日 电话：13800138000"

        let result = DocumentParser().parse(text)

        XCTAssertEqual(result.category, .school)
        XCTAssertEqual(result.amount, Decimal(380))
        XCTAssertEqual(result.currencyCode, "CNY")
        XCTAssertEqual(result.phoneNumber, "13800138000")
        XCTAssertEqual(result.confidence, .high)
        XCTAssertDate(result.dueDate, year: 2026, month: 7, day: 15)
    }

    func testParsesAppointmentContact() {
        let text = "Dental appointment on 07/18/2026 at Main Clinic. Phone 13800138000 email care@example.invalid"

        let result = DocumentParser().parse(text)

        XCTAssertEqual(result.category, .medical)
        XCTAssertEqual(result.phoneNumber, "13800138000")
        XCTAssertEqual(result.emailAddress, "care@example.invalid")
        XCTAssertEqual(result.confidence, .high)
        XCTAssertDate(result.eventDate, year: 2026, month: 7, day: 18)
    }

    func testSparseTextReturnsLowConfidence() {
        let result = DocumentParser().parse("thanks for your purchase")

        XCTAssertEqual(result.confidence, .low)
        XCTAssertNil(result.amount)
        XCTAssertNil(result.dueDate)
        XCTAssertNil(result.eventDate)
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
