import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: DocumentRecordStore

    private var openRecords: [DocumentRecord] {
        store.records.filter { $0.status == .open }
    }

    private var upcomingRecords: [DocumentRecord] {
        openRecords
            .filter { $0.isUpcoming(within: 7) }
            .sorted { ($0.displayDate ?? .distantFuture) < ($1.displayDate ?? .distantFuture) }
    }

    private var overdueRecords: [DocumentRecord] {
        openRecords.filter { $0.isOverdue() }
    }

    private var currentMonthAmount: Decimal {
        let calendar = Calendar.current
        let now = Date()
        return store.records.reduce(Decimal(0)) { total, record in
            guard let date = record.displayDate,
                  let amount = record.amount,
                  calendar.isDate(date, equalTo: now, toGranularity: .month),
                  calendar.isDate(date, equalTo: now, toGranularity: .year) else {
                return total
            }
            return total + amount
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        MetricTile(title: "Saved Records", value: "\(store.records.count)", systemImage: "tray.full")
                        MetricTile(title: "Next 7 Days", value: "\(upcomingRecords.count)", systemImage: "calendar.badge.clock")
                        MetricTile(title: "Overdue", value: "\(overdueRecords.count)", systemImage: "exclamationmark.triangle")
                        MetricTile(title: "This Month", value: NSDecimalNumber(decimal: currentMonthAmount).stringValue, systemImage: "sum")
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                }

                Section("Upcoming") {
                    if upcomingRecords.isEmpty {
                        ContentUnavailableView("No upcoming reminders", systemImage: "bell")
                    } else {
                        ForEach(upcomingRecords) { record in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(record.title)
                                    .font(.headline)
                                Text(record.displayDate?.formatted(date: .abbreviated, time: .omitted) ?? "No date")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Needs Review") {
                    let reviewRecords = store.records.filter(\.requiresReview)
                    if reviewRecords.isEmpty {
                        Text("All saved records have a date.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(reviewRecords.prefix(5)) { record in
                            Text(record.title)
                        }
                    }
                }
            }
            .navigationTitle("Dashboard")
        }
    }
}
