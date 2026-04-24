import AppKit
import Foundation
import Observation
import UniformTypeIdentifiers

@MainActor
@Observable
final class MemoStore {
    var text: String
    var lastSavedAt: Date?
    var errorMessage: String?

    private let fileManager: FileManager
    private var saveURL: URL
    private var pendingSaveTask: Task<Void, Never>?

    private static let savePathDefaultsKey = "MacMemoApp.savePath"

    init(
        fileManager: FileManager = .default,
        initialText: String? = nil,
        saveURL: URL? = nil
    ) {
        self.fileManager = fileManager
        let resolvedURL = saveURL ?? MemoStore.loadSavedURL(fileManager: fileManager)
        self.saveURL = resolvedURL

        if let initialText {
            text = initialText
            lastSavedAt = Date()
            return
        }

        do {
            text = try String(contentsOf: resolvedURL, encoding: .utf8)
            lastSavedAt = ((try? resolvedURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate)
        } catch {
            text = ""
        }
    }

    var statusMessage: String {
        if let errorMessage {
            return errorMessage
        }

        guard let lastSavedAt else {
            return "Type anything and it will be saved automatically on this Mac."
        }

        return "Last saved \(lastSavedAt.formatted(date: .abbreviated, time: .shortened))"
    }

    var saveLocation: String {
        saveURL.path
    }

    var saveLocationDisplayName: String {
        saveURL.lastPathComponent
    }

    func scheduleSave() {
        pendingSaveTask?.cancel()
        errorMessage = nil
        pendingSaveTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            self?.save()
        }
    }

    func chooseSaveLocation() {
        let panel = NSSavePanel()
        panel.title = "Choose where to save your memo"
        panel.message = "MacMemoApp will keep saving to the file you choose."
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.allowedContentTypes = [UTType.plainText]
        panel.nameFieldStringValue = saveURL.lastPathComponent
        panel.directoryURL = saveURL.deletingLastPathComponent()

        guard panel.runModal() == .OK, let selectedURL = panel.url else {
            return
        }

        changeSaveLocation(to: selectedURL)
    }

    func save() {
        do {
            pendingSaveTask?.cancel()
            try fileManager.createDirectory(
                at: saveURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try text.write(to: saveURL, atomically: true, encoding: .utf8)
            lastSavedAt = Date()
            errorMessage = nil
        } catch {
            errorMessage = "Save failed: \(error.localizedDescription)"
        }
    }

    private func changeSaveLocation(to newURL: URL) {
        saveURL = newURL
        UserDefaults.standard.set(newURL.path, forKey: Self.savePathDefaultsKey)
        save()
    }

    private static func loadSavedURL(fileManager: FileManager) -> URL {
        if let savedPath = UserDefaults.standard.string(forKey: savePathDefaultsKey), !savedPath.isEmpty {
            return URL(fileURLWithPath: savedPath)
        }

        return makeDefaultSaveURL(fileManager: fileManager)
    }

    private static func makeDefaultSaveURL(fileManager: FileManager) -> URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())

        return appSupport
            .appendingPathComponent("MacMemoApp", isDirectory: true)
            .appendingPathComponent("memo.txt")
    }
}

extension MemoStore {
    static var preview: MemoStore {
        MemoStore(
            initialText: """
            Welcome to MacMemoApp.

            This is a simple memo space for quick notes, ideas, and reminders.
            """
        )
    }
}
