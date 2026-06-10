import XCTest
@testable import SnapTableReminder

final class CSVExporterTests: XCTestCase {
    func testExportsStableColumnsAndEscapesFields() {
        var record = DocumentRecord.sample(
            title: "Invoice \"A\"",
            category: .bill,
            amount: Decimal(string: "128.50"),
            currencyCode: "USD",
            rawText: "line 1\nline \"2\"",
            notes: "needs, review"
        )
        record.emailAddress = "billing@example.invalid"

        let csv = CSVExporter().export([record])

        XCTAssertTrue(csv.hasPrefix("Title,Category,Amount,Currency,Event Date,Due Date,Reminder Date,Reminder Enabled,Status,Source,Phone,Email,Location,Notes,Raw Text"))
        XCTAssertTrue(csv.contains("\"Invoice \"\"A\"\"\""))
        XCTAssertTrue(csv.contains("128.5"))
        XCTAssertTrue(csv.contains("billing@example.invalid"))
        XCTAssertTrue(csv.contains("\"needs, review\""))
        XCTAssertTrue(csv.contains("\"line 1\nline \"\"2\"\"\""))
    }
}
