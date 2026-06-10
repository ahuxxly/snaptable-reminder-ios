import XCTest
@testable import SnapTableReminder

final class DemoDataTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryDirectory)
        temporaryDirectory = nil
    }

    func testDemoDataDoesNotReplaceExistingRecordsByDefault() {
        let store = makeStore()
        store.replaceAll([DocumentRecord.sample(title: "Existing Record")])

        DemoData.seedIfRequested(into: store, arguments: ["-demoData"])

        XCTAssertEqual(store.records.map(\.title), ["Existing Record"])
    }

    func testResetDemoDataReplacesExistingRecordsForStableScreenshots() {
        let store = makeStore()
        store.replaceAll([DocumentRecord.sample(title: "Existing Record")])

        DemoData.seedIfRequested(into: store, arguments: ["-demoData", "-resetDemoData"])

        XCTAssertEqual(store.records.count, 3)
        XCTAssertEqual(store.records.first?.title, "Tuition Payment Notice")
        XCTAssertFalse(store.records.contains { $0.title == "Existing Record" })
    }

    private func makeStore() -> DocumentRecordStore {
        DocumentRecordStore(storeURL: temporaryDirectory.appendingPathComponent("records.json"))
    }
}
