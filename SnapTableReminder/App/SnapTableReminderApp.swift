import SwiftUI

@main
struct SnapTableReminderApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var store = DocumentRecordStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(store)
        }
    }
}

private struct RootView: View {
    var body: some View {
        TabView {
            CaptureView()
                .tabItem {
                    Label("Capture", systemImage: "viewfinder")
                }

            RecordsView()
                .tabItem {
                    Label("Records", systemImage: "tablecells")
                }

            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}
