import AppKit
import Foundation
import Observation

struct MemoItem: Identifiable, Equatable {
    let id: UUID
    var title: String
    var text: String
    var fileName: String
    var lastSavedAt: Date?
}

@MainActor
@Observable
final class MemoStore {
    var memos: [MemoItem]
    var selectedMemoID: MemoItem.ID?
    var lastSavedAt: Date?
    var errorMessage: String?

    private let fileManager: FileManager
    private var saveDirectoryURL: URL
    private var pendingSaveTask: Task<Void, Never>?

    private static let saveDirectoryDefaultsKey = "MacMemoApp.saveDirectoryPath"
    private static let legacySavePathDefaultsKey = "MacMemoApp.savePath"

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let initialDirectoryURL = Self.loadSavedDirectoryURL(fileManager: fileManager)
        saveDirectoryURL = initialDirectoryURL

        let loadedMemos = Self.loadMemos(from: initialDirectoryURL, fileManager: fileManager)
        if loadedMemos.isEmpty {
            let initialMemo = Self.makeInitialMemo(in: initialDirectoryURL, fileManager: fileManager)
            memos = [initialMemo]
            selectedMemoID = initialMemo.id
            lastSavedAt = initialMemo.lastSavedAt
        } else {
            memos = loadedMemos
            selectedMemoID = loadedMemos.first?.id
            lastSavedAt = loadedMemos.first?.lastSavedAt
        }
    }

    var statusMessage: String {
        if let errorMessage {
            return errorMessage
        }

        guard let lastSavedAt else {
            return "Changes are saved automatically in your chosen memo folder."
        }

        return "Last saved \(lastSavedAt.formatted(date: .abbreviated, time: .shortened))"
    }

    var saveLocation: String {
        saveDirectoryURL.path
    }

    var saveLocationDisplayName: String {
        saveDirectoryURL.lastPathComponent
    }

    var selectedMemoTitle: String {
        get { selectedMemo?.title ?? "" }
        set { updateSelectedMemoTitle(newValue) }
    }

    var selectedMemoText: String {
        get { selectedMemo?.text ?? "" }
        set { updateSelectedMemoText(newValue) }
    }

    var selectedMemoFileName: String {
        selectedMemo?.fileName ?? ""
    }

    var hasSelection: Bool {
        selectedMemo != nil
    }

    func selectMemo(id: MemoItem.ID?) {
        selectedMemoID = id
        lastSavedAt = selectedMemo?.lastSavedAt
        errorMessage = nil
    }

    func addMemo() {
        let title = nextDefaultMemoTitle()
        let fileName = makeUniqueFileName(from: title, excluding: nil)
        let memo = MemoItem(
            id: UUID(),
            title: title,
            text: "",
            fileName: fileName,
            lastSavedAt: nil
        )
        memos.append(memo)
        selectMemo(id: memo.id)
        saveSelectedMemo()
    }

    func chooseSaveLocation() {
        let panel = NSOpenPanel()
        panel.title = "Choose where to store your memos"
        panel.message = "MacMemoApp will save each memo as a text file in the folder you choose."
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = saveDirectoryURL

        guard panel.runModal() == .OK, let selectedURL = panel.url else {
            return
        }

        changeSaveDirectory(to: selectedURL)
    }

    func scheduleSaveSelected() {
        pendingSaveTask?.cancel()
        errorMessage = nil
        pendingSaveTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            self?.saveSelectedMemo()
        }
    }

    func saveSelectedMemo() {
        guard let index = selectedMemoIndex else { return }
        do {
            pendingSaveTask?.cancel()
            try ensureSaveDirectoryExists()
            let saveDate = Date()
            let memo = memos[index]
            let fileURL = fileURL(for: memo.fileName)
            try memo.text.write(to: fileURL, atomically: true, encoding: .utf8)
            memos[index].lastSavedAt = saveDate
            lastSavedAt = saveDate
            errorMessage = nil
        } catch {
            errorMessage = "Save failed: \(error.localizedDescription)"
        }
    }

    func saveAllMemos() {
        for memo in memos {
            saveMemo(id: memo.id)
        }
    }

    private var selectedMemo: MemoItem? {
        guard let selectedMemoIndex else { return nil }
        return memos[selectedMemoIndex]
    }

    private var selectedMemoIndex: Int? {
        guard let selectedMemoID else { return nil }
        return memos.firstIndex { $0.id == selectedMemoID }
    }

    private func updateSelectedMemoTitle(_ newValue: String) {
        guard let index = selectedMemoIndex else { return }

        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTitle = trimmed.isEmpty ? fallbackTitle(for: memos[index].id) : trimmed
        let oldFileName = memos[index].fileName
        let newFileName = makeUniqueFileName(from: resolvedTitle, excluding: memos[index].id)

        do {
            try ensureSaveDirectoryExists()
            let oldURL = fileURL(for: oldFileName)
            let newURL = fileURL(for: newFileName)

            if oldFileName != newFileName, fileManager.fileExists(atPath: oldURL.path) {
                if fileManager.fileExists(atPath: newURL.path) {
                    try fileManager.removeItem(at: newURL)
                }
                try fileManager.moveItem(at: oldURL, to: newURL)
            }

            memos[index].title = resolvedTitle
            memos[index].fileName = newFileName
            errorMessage = nil
            saveSelectedMemo()
        } catch {
            errorMessage = "Rename failed: \(error.localizedDescription)"
        }
    }

    private func updateSelectedMemoText(_ newValue: String) {
        guard let index = selectedMemoIndex else { return }
        memos[index].text = newValue
        scheduleSaveSelected()
    }

    private func saveMemo(id: MemoItem.ID) {
        guard let index = memos.firstIndex(where: { $0.id == id }) else { return }
        do {
            try ensureSaveDirectoryExists()
            let saveDate = Date()
            let memo = memos[index]
            try memo.text.write(to: fileURL(for: memo.fileName), atomically: true, encoding: .utf8)
            memos[index].lastSavedAt = saveDate
            if id == selectedMemoID {
                lastSavedAt = saveDate
            }
            errorMessage = nil
        } catch {
            errorMessage = "Save failed: \(error.localizedDescription)"
        }
    }

    private func ensureSaveDirectoryExists() throws {
        try fileManager.createDirectory(at: saveDirectoryURL, withIntermediateDirectories: true)
    }

    private func changeSaveDirectory(to newURL: URL) {
        do {
            saveDirectoryURL = newURL
            UserDefaults.standard.set(newURL.path, forKey: Self.saveDirectoryDefaultsKey)
            try ensureSaveDirectoryExists()
            saveAllMemos()
            errorMessage = nil
        } catch {
            errorMessage = "Folder change failed: \(error.localizedDescription)"
        }
    }

    private func fileURL(for fileName: String) -> URL {
        saveDirectoryURL.appendingPathComponent(fileName, isDirectory: false)
    }

    private func nextDefaultMemoTitle() -> String {
        var index = 1
        let existing = Set(memos.map { $0.title.lowercased() })

        while existing.contains("memo\(index)") {
            index += 1
        }

        return "memo\(index)"
    }

    private func fallbackTitle(for memoID: MemoItem.ID) -> String {
        if let memo = memos.first(where: { $0.id == memoID }), !memo.title.isEmpty {
            return memo.title
        }
        return nextDefaultMemoTitle()
    }

    private func makeUniqueFileName(from rawTitle: String, excluding memoID: MemoItem.ID?) -> String {
        let baseName = sanitizeFileStem(rawTitle)
        let excludedFileName = memos.first(where: { $0.id == memoID })?.fileName
        var candidate = "\(baseName).txt"
        var suffix = 2

        while memos.contains(where: { $0.fileName == candidate && $0.fileName != excludedFileName }) {
            candidate = "\(baseName)-\(suffix).txt"
            suffix += 1
        }

        return candidate
    }

    private func sanitizeFileStem(_ rawTitle: String) -> String {
        let trimmed = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = trimmed.isEmpty ? "memo" : trimmed
        let invalidCharacters = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let cleanedScalars = fallback.unicodeScalars.map { invalidCharacters.contains($0) ? "-" : Character($0) }
        let cleaned = String(cleanedScalars).trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "memo" : cleaned
    }

    private static func loadSavedDirectoryURL(fileManager: FileManager) -> URL {
        if let savedPath = UserDefaults.standard.string(forKey: saveDirectoryDefaultsKey), !savedPath.isEmpty {
            return URL(fileURLWithPath: savedPath, isDirectory: true)
        }

        if let legacyFilePath = UserDefaults.standard.string(forKey: legacySavePathDefaultsKey), !legacyFilePath.isEmpty {
            return URL(fileURLWithPath: legacyFilePath).deletingLastPathComponent()
        }

        return makeDefaultDirectoryURL(fileManager: fileManager)
    }

    private static func loadMemos(from directoryURL: URL, fileManager: FileManager) -> [MemoItem] {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return urls
            .filter { $0.pathExtension.lowercased() == "txt" }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .map { url in
                let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
                let modifiedAt = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                let title = url.deletingPathExtension().lastPathComponent
                return MemoItem(
                    id: UUID(),
                    title: title,
                    text: text,
                    fileName: url.lastPathComponent,
                    lastSavedAt: modifiedAt
                )
            }
    }

    private static func makeInitialMemo(in directoryURL: URL, fileManager: FileManager) -> MemoItem {
        let legacyFileURL = directoryURL.appendingPathComponent("memo.txt")
        let legacyText = (try? String(contentsOf: legacyFileURL, encoding: .utf8)) ?? ""
        let legacyDate = (try? legacyFileURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate

        return MemoItem(
            id: UUID(),
            title: "memo1",
            text: legacyText,
            fileName: "memo1.txt",
            lastSavedAt: legacyDate
        )
    }

    private static func makeDefaultDirectoryURL(fileManager: FileManager) -> URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())

        return appSupport
            .appendingPathComponent("MacMemoApp", isDirectory: true)
            .appendingPathComponent("Memos", isDirectory: true)
    }
}

extension MemoStore {
    static var preview: MemoStore {
        let store = MemoStore()
        store.memos = [
            MemoItem(
                id: UUID(),
                title: "memo1",
                text: "Welcome to MacMemoApp.\n\nYou can now create more than one memo.",
                fileName: "memo1.txt",
                lastSavedAt: Date()
            ),
            MemoItem(
                id: UUID(),
                title: "Ideas",
                text: "1. Add search\n2. Add folders\n3. Add tags",
                fileName: "Ideas.txt",
                lastSavedAt: Date()
            )
        ]
        store.selectedMemoID = store.memos.first?.id
        store.lastSavedAt = Date()
        return store
    }
}
