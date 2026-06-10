import PhotosUI
import SwiftUI
import UIKit

struct CaptureView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: DocumentRecordStore

    @State private var rawText = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var activeSheet: ActiveSheet?
    @State private var isRecognizing = false
    @State private var errorMessage: String?

    private enum ActiveSheet: Identifiable {
        case manual
        case draft(ParsedDocumentDraft)

        var id: String {
            switch self {
            case .manual: return "manual"
            case .draft: return "draft"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            Label("Import Image", systemImage: "photo")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            activeSheet = .manual
                        } label: {
                            Label("Manual", systemImage: "square.and.pencil")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }

                    if isRecognizing {
                        ProgressView("Recognizing text...")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.callout)
                            .foregroundStyle(.red)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recognized or Pasted Text")
                            .font(.headline)
                        TextEditor(text: $rawText)
                            .frame(minHeight: 220)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
                    }

                    Button {
                        parseText()
                    } label: {
                        Label("Parse and Review", systemImage: "wand.and.stars")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Text("All extraction runs on this device. Review every field before saving.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("Capture")
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem else { return }
                recognizeText(from: newItem)
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .manual:
                    RecordFormView(mode: .add(defaultCurrencyCode: appState.defaultCurrencyCode)) { record in
                        store.add(record)
                        appState.scheduleReminderIfNeeded(for: record)
                    }
                case .draft(let draft):
                    RecordFormView(mode: .addFromDraft(draft, defaultCurrencyCode: appState.defaultCurrencyCode)) { record in
                        store.add(record)
                        appState.scheduleReminderIfNeeded(for: record)
                    }
                }
            }
        }
    }

    private func parseText() {
        let parsed = appState.applyDefaultReminder(to: appState.parse(rawText))
        activeSheet = .draft(parsed)
    }

    private func recognizeText(from item: PhotosPickerItem) {
        isRecognizing = true
        errorMessage = nil

        Task {
            defer { isRecognizing = false }
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else {
                    errorMessage = "The selected image could not be opened."
                    return
                }
                rawText = try await appState.ocrService.recognizeText(in: image)
                parseText()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
