import Combine
import Foundation
import Sparkle

@MainActor
final class AppUpdater: ObservableObject {
    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var configurationMessage: String

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
            observation = controller.updater.publisher(for: \.canCheckForUpdates)
                .receive(on: RunLoop.main)
                .assign(to: \.canCheckForUpdates, on: self)
        } else {
            updaterController = nil
            configurationMessage = "Set your Sparkle appcast URL and public EdDSA key in Info.plist to enable automatic updates."
        }
    }

    func checkForUpdates() {
        updaterController?.checkForUpdates(nil)
    }
}
