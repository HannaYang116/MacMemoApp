import Combine
import Foundation
import Sparkle

@MainActor
final class AppUpdater: ObservableObject {
    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var configurationMessage: String
    @Published private(set) var installationMessage: String

    let updaterController: SPUStandardUpdaterController?

    private var observation: AnyCancellable?

    init(bundle: Bundle = .main) {
        let feedURL = bundle.object(forInfoDictionaryKey: "SUFeedURL") as? String ?? ""
        let publicKey = bundle.object(forInfoDictionaryKey: "SUPublicEDKey") as? String ?? ""
        let isConfigured =
            !feedURL.isEmpty &&
            !publicKey.isEmpty &&
            !feedURL.contains("example.com")

        if isConfigured {
            let controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
            updaterController = controller
            configurationMessage = "Sparkle updates are configured."
            installationMessage = Self.makeInstallationMessage(for: bundle)
            observation = controller.updater.publisher(for: \.canCheckForUpdates)
                .receive(on: RunLoop.main)
                .assign(to: \.canCheckForUpdates, on: self)
        } else {
            updaterController = nil
            configurationMessage = "Set your Sparkle appcast URL and public EdDSA key in Info.plist to enable automatic updates."
            installationMessage = Self.makeInstallationMessage(for: bundle)
        }
    }

    func checkForUpdates() {
        updaterController?.checkForUpdates(nil)
    }

    private static func makeInstallationMessage(for bundle: Bundle) -> String {
        let appName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "This app"
        let bundleURL = bundle.bundleURL
        let bundlePath = bundleURL.path

        if bundlePath.contains("/AppTranslocation/") {
            return "\(appName) is running from a translocated location, so macOS may block in-place updates. Move the app with Finder to any writable folder, relaunch it from there, and then try again."
        }

        if let volumeIsReadOnly = try? bundleURL.resourceValues(forKeys: [.volumeIsReadOnlyKey]).volumeIsReadOnly,
           volumeIsReadOnly == true {
            return "\(appName) is running from a read-only volume. Copy it to any writable folder, relaunch it from there, and then try again."
        }

        return "Installed at: \(bundlePath)"
    }
}
