import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: DocumentRecordStore
    @State private var isConfirmingDelete = false
    @State private var csvExportURL: URL?

    var body: some View {
        NavigationStack {
            Form {
                Section("Defaults") {
                    TextField("Currency", text: $appState.defaultCurrencyCode)
                        .textInputAutocapitalization(.characters)
                    Stepper("Reminder lead: \(appState.defaultReminderLeadDays) day(s)", value: $appState.defaultReminderLeadDays, in: 0...30)
                }

                Section("Data") {
                    if let csvExportURL {
                        ShareLink(item: csvExportURL) {
                            Label("Export CSV", systemImage: "square.and.arrow.up")
                        }
                    } else {
                        Button {
                            prepareCSVExport()
                        } label: {
                            Label("Prepare CSV", systemImage: "doc.badge.plus")
                        }
                    }

                    Button(role: .destructive) {
                        isConfirmingDelete = true
                    } label: {
                        Label("Delete All Local Data", systemImage: "trash")
                    }
                }

                Section("Privacy") {
                    Text("Records, OCR text, and reminders are stored locally on this device. Version 1 has no account, tracking, backend, analytics, or cloud AI parser.")
                    Text("This app helps organize personal records and reminders. It does not provide legal, medical, tax, financial, or investment advice.")
                }

                if let message = appState.statusMessage {
                    Section("Status") {
                        Text(message)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                prepareCSVExport()
            }
            .onChange(of: store.records) { _, _ in
                prepareCSVExport()
            }
            .confirmationDialog("Delete all local data?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button("Delete All Data", role: .destructive) {
                    store.deleteAll()
                }
            }
        }
    }

    private func prepareCSVExport() {
        do {
            csvExportURL = try appState.csvExporter.writeTemporaryCSV(store.records)
        } catch {
            csvExportURL = nil
            appState.statusMessage = error.localizedDescription
        }
    }
}
