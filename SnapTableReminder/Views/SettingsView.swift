import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: DocumentRecordStore
    @State private var isConfirmingDelete = false
    @State private var csvExportURL: URL?
    @State private var currencyCodeText = ""

    private var isCurrencyCodeValid: Bool {
        normalizedCurrencyCode(from: currencyCodeText) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Defaults") {
                    TextField("Currency", text: $currencyCodeText)
                        .textInputAutocapitalization(.characters)
                        .onChange(of: currencyCodeText) { _, _ in
                            commitCurrencyCodeIfValid()
                        }
                        .onSubmit {
                            commitCurrencyCodeIfValid()
                        }
                    if !currencyCodeText.isEmpty, !isCurrencyCodeValid {
                        Text("Use a 3-letter currency code, such as USD, EUR, or CNY.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Stepper(
                        "Reminder lead: \(appState.defaultReminderLeadDays) day(s)",
                        value: Binding(
                            get: { appState.defaultReminderLeadDays },
                            set: { appState.setDefaultReminderLeadDays($0) }
                        ),
                        in: 0...30
                    )
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
                        .accessibilityIdentifier("SettingsPrivacySummary")
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
                currencyCodeText = appState.defaultCurrencyCode
                prepareCSVExport()
            }
            .onChange(of: store.records) { _, _ in
                prepareCSVExport()
            }
            .confirmationDialog("Delete all local data?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button("Delete All Data", role: .destructive) {
                    store.records.forEach { appState.cancelReminder(for: $0.id) }
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

    private func commitCurrencyCodeIfValid() {
        guard let normalized = normalizedCurrencyCode(from: currencyCodeText) else { return }
        currencyCodeText = normalized
        appState.setDefaultCurrencyCode(normalized)
    }

    private func normalizedCurrencyCode(from text: String) -> String? {
        let letters = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .filter(\.isLetter)
        guard letters.count == 3 else { return nil }
        return String(letters)
    }
}
