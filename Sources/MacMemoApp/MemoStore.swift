import Foundation
import Observation

@Observable
final class MemoStore {
    var text: String
    var lastSavedAt: Date?
    var errorMessage: String?

    private let saveURL: URL
    private var pendingSaveTask: Task<Void, Never>?

    init(
        fileManager: FileManager = .default,
        initialText: String? = nil,
        saveURL: URL? = nil
    ) {
        let resolvedURL = saveURL ?? MemoStore.makeSaveURL(fileManager: fileManager)
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

    func scheduleSave() {
        pendingSaveTask?.cancel()
        pendingSaveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            await self?.save()
        }
    }

    @MainActor
    func save() {
        do {
            try FileManager.default.createDirectory(
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

    private static func makeSaveURL(fileManager: FileManager) -> URL {
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
