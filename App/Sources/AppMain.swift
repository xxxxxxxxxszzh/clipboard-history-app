import SwiftUI

@main
struct ClipboardHistoryAppMain: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = ClipboardHistoryStore()

    var body: some Scene {
        WindowGroup {
            ClipboardHistoryView()
                .environmentObject(store)
                .background(
                    WindowAccessor { window in
                        appDelegate.attach(window: window, store: store)
                    }
                )
        }
        .defaultSize(width: 1100, height: 720)
        .windowResizability(.contentSize)

        Settings {
            SettingsView()
                .environmentObject(store)
                .padding(24)
                .frame(width: 420)
        }
    }
}

private struct SettingsView: View {
    @EnvironmentObject private var store: ClipboardHistoryStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Clipboard History")
                .font(.title2.bold())
            Text("The app lives in the menu bar, stores text and images locally, and auto-cleans unpinned items once limits are reached.")
                .foregroundStyle(.secondary)
            Divider()
            Text("Hotkey: \(store.hotKeyDisplay)")
            Text("Max items: \(store.stats.maxItems)")
            Text("Max disk usage: \(store.formattedDiskLimit())")
            Text("Current disk usage: \(store.formattedDiskUsage())")
            Text("Current memory usage: \(store.formattedMemoryUsage())")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
