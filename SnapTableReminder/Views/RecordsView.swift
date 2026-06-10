import SwiftUI

struct RecordsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: DocumentRecordStore

    @State private var searchText = ""
    @State private var selectedCategory: DocumentCategory?
    @State private var sortMode: SortMode = .date
    @State private var isAdding = false

    private enum SortMode: String, CaseIterable, Identifiable {
        case date = "Date"
        case amount = "Amount"
        case title = "Title"

        var id: String { rawValue }
    }

    private var filteredRecords: [DocumentRecord] {
        var items = store.records
        if let selectedCategory {
            items = items.filter { $0.category == selectedCategory }
        }
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            items = items.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.rawText.localizedCaseInsensitiveContains(searchText) ||
                $0.notes.localizedCaseInsensitiveContains(searchText)
            }
        }

        switch sortMode {
        case .date:
            return items.sorted { ($0.displayDate ?? .distantFuture) < ($1.displayDate ?? .distantFuture) }
        case .amount:
            return items.sorted { ($0.amount ?? 0) > ($1.amount ?? 0) }
        case .title:
            return items.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if filteredRecords.isEmpty {
                    ContentUnavailableView(
                        "No records yet",
                        systemImage: "tablecells",
                        description: Text("Import a screenshot, paste text, or add a record manually.")
                    )
                } else {
                    ForEach(filteredRecords) { record in
                        NavigationLink {
                            RecordFormView(mode: .edit(record)) { updated in
                                store.update(updated)
                                appState.scheduleReminderIfNeeded(for: updated)
                            }
                        } label: {
                            RecordRow(record: record)
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            let record = filteredRecords[index]
                            appState.cancelReminder(for: record.id)
                            store.delete(record)
                        }
                    }
                }
            }
            .searchable(text: $searchText)
            .navigationTitle("Records")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("All Categories") { selectedCategory = nil }
                        ForEach(DocumentCategory.allCases) { category in
                            Button(category.displayName) { selectedCategory = category }
                        }
                    } label: {
                        Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Sort", selection: $sortMode) {
                            ForEach(SortMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                    } label: {
                        Label("Sort", systemImage: "arrow.up.arrow.down")
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isAdding = true
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isAdding) {
                RecordFormView(mode: .add(defaultCurrencyCode: appState.defaultCurrencyCode)) { record in
                    store.add(record)
                    appState.scheduleReminderIfNeeded(for: record)
                }
            }
        }
    }
}

private struct RecordRow: View {
    let record: DocumentRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(record.title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                if let amount = record.amount {
                    Text("\(record.currencyCode) \(NSDecimalNumber(decimal: amount).stringValue)")
                        .font(.subheadline.weight(.semibold))
                }
            }

            HStack(spacing: 8) {
                Label(record.category.displayName, systemImage: "tag")
                if let displayDate = record.displayDate {
                    Label(displayDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                }
                if record.requiresReview {
                    Label("Review", systemImage: "exclamationmark.triangle")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        .padding(.vertical, 4)
    }
}
