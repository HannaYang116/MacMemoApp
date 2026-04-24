import AppKit
import SwiftUI

struct MemoWindowTarget: Codable, Hashable {
    let memoTitle: String
}

@main
struct MacMemoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var updater = AppUpdater()

    var body: some Scene {
        WindowGroup {
            MemoWindowRootView(updater: updater)
        }
        .defaultSize(width: 900, height: 640)

        WindowGroup("Linked Memo", for: MemoWindowTarget.self) { value in
            MemoWindowRootView(
                initialSelectedMemoTitle: value.wrappedValue?.memoTitle,
                updater: updater
            )
        }
        .defaultSize(width: 900, height: 640)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    updater.checkForUpdates()
                }
                .disabled(!updater.canCheckForUpdates)
            }
        }

        Settings {
            MemoSettingsRootView(updater: updater)
        }
    }
}

private struct MemoWindowRootView: View {
    @State private var store: MemoStore
    @ObservedObject var updater: AppUpdater
    @Environment(\.scenePhase) private var scenePhase

    init(initialSelectedMemoTitle: String? = nil, updater: AppUpdater) {
        self.updater = updater
        _store = State(initialValue: MemoStore(initialSelectedMemoTitle: initialSelectedMemoTitle))
    }

    var body: some View {
        ContentView(store: store, updater: updater)
            .frame(minWidth: 720, minHeight: 520)
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase != .active {
                    store.saveAllMemos()
                }
            }
    }
}

private struct MemoSettingsRootView: View {
    @State private var store = MemoStore()
    @ObservedObject var updater: AppUpdater

    var body: some View {
        SettingsView(store: store, updater: updater)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
