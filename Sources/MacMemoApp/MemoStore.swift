import AppKit
import Foundation
import Observation
import SwiftUI

struct MemoItem: Identifiable, Equatable {
    let id: UUID
    var title: String
    var text: String
    var fileName: String
    var createdAt: Date
    var lastSavedAt: Date?
}

enum MemoSortOption: String, CaseIterable, Identifiable {
    case newestFirst
    case oldestFirst
    case titleAscending
    case titleDescending

    var id: String { rawValue }

    var label: String {
        switch self {
        case .newestFirst:
            return "Latest"
        case .oldestFirst:
            return "Oldest"
        case .titleAscending:
            return "Name A-Z"
        case .titleDescending:
            return "Name Z-A"
        }
    }
}

enum MemoTheme: String, CaseIterable, Identifiable {
    case pink
    case blue
    case yellow

    var id: String { rawValue }

    var label: String {
        rawValue.capitalized
    }

    var tint: Color {
        switch self {
        case .pink:
            return Color(red: 0.84, green: 0.39, blue: 0.61)
        case .blue:
            return Color(red: 0.34, green: 0.55, blue: 0.90)
        case .yellow:
            return Color(red: 0.88, green: 0.71, blue: 0.24)
        }
    }

    var accent: Color {
        switch self {
        case .pink:
            return Color(red: 0.98, green: 0.90, blue: 0.94)
        case .blue:
            return Color(red: 0.91, green: 0.95, blue: 0.99)
        case .yellow:
            return Color(red: 0.99, green: 0.96, blue: 0.86)
        }
    }

    var background: Color {
        switch self {
        case .pink:
            return Color(red: 0.99, green: 0.96, blue: 0.97)
        case .blue:
            return Color(red: 0.95, green: 0.98, blue: 1.00)
        case .yellow:
            return Color(red: 1.00, green: 0.99, blue: 0.92)
        }
    }

    var secondaryBackground: Color {
        switch self {
        case .pink:
            return Color(red: 0.96, green: 0.89, blue: 0.92)
        case .blue:
            return Color(red: 0.87, green: 0.93, blue: 0.99)
        case .yellow:
            return Color(red: 0.97, green: 0.93, blue: 0.79)
        }
    }
}

enum MemoLineStyle: String, CaseIterable, Identifiable {
    case none
    case regular
    case thin

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none:
            return "No line"
        case .regular:
            return "Basic line"
        case .thin:
            return "Thin line"
        }
    }
}

@MainActor
@Observable
final class MemoStore {
    var memos: [MemoItem]
    var selectedMemoID: MemoItem.ID?
    var lastSavedAt: Date?
    var errorMessage: String?
    var searchText: String
    var sortOption: MemoSortOption
    var theme: MemoTheme
    var lineStyle: MemoLineStyle

    private let fileManager: FileManager
    private var saveDirectoryURL: URL
    private var pendingSaveTask: Task<Void, Never>?

    private static let saveDirectoryDefaultsKey = "MacMemoApp.saveDirectoryPath"
    private static let legacySavePathDefaultsKey = "MacMemoApp.savePath"
    private static let themeDefaultsKey = "MacMemoApp.theme"
    private static let lineStyleDefaultsKey = "MacMemoApp.lineStyle"

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let initialDirectoryURL = Self.loadSavedDirectoryURL(fileManager: fileManager)
        saveDirectoryURL = initialDirectoryURL
        searchText = ""
        sortOption = .newestFirst
        theme = Self.loadTheme()
        lineStyle = Self.loadLineStyle()

        let loadedMemos = Self.loadMemos(from: initialDirectoryURL, fileManager: fileManager)
        if loadedMemos.isEmpty {
            let initialMemo = Self.makeInitialMemo(in: initialDirectoryURL, fileManager: fileManager)
            memos = [initialMemo]
            selectedMemoID = initialMemo.id
            lastSavedAt = initialMemo.lastSavedAt
        } else {
            memos = loadedMemos
            selectedMemoID = Self.initialSelectedMemoID(from: loadedMemos, sortOption: sortOption)
            lastSavedAt = selectedMemo?.lastSavedAt
        }
    }

    var filteredSortedMemos: [MemoItem] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = trimmed.isEmpty
            ? memos
            : memos.filter { $0.title.localizedCaseInsensitiveContains(trimmed) }

        switch sortOption {
        case .newestFirst:
            return filtered.sorted {
                if $0.createdAt == $1.createdAt {
                    return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                }
                return $0.createdAt > $1.createdAt
            }
        case .oldestFirst:
            return filtered.sorted {
                if $0.createdAt == $1.createdAt {
                    return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                }
                return $0.createdAt < $1.createdAt
            }
        case .titleAscending:
            return filtered.sorted {
                let comparison = $0.title.localizedCaseInsensitiveCompare($1.title)
                if comparison == .orderedSame {
                    return $0.createdAt > $1.createdAt
                }
                return comparison == .orderedAscending
            }
        case .titleDescending:
            return filtered.sorted {
                let comparison = $0.title.localizedCaseInsensitiveCompare($1.title)
                if comparison == .orderedSame {
                    return $0.createdAt > $1.createdAt
                }
                return comparison == .orderedDescending
            }
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
        let now = Date()
        let memo = MemoItem(
            id: UUID(),
            title: title,
            text: "",
            fileName: fileName,
            createdAt: now,
            lastSavedAt: nil
        )
        memos.append(memo)
        selectMemo(id: memo.id)
        saveSelectedMemo()
    }

    func deleteMemo(id: MemoItem.ID) {
        guard let index = memos.firstIndex(where: { $0.id == id }) else { return }

        do {
            let memo = memos[index]
            let fileURL = fileURL(for: memo.fileName)
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }

            memos.remove(at: index)

            if memos.isEmpty {
                addMemo()
            } else if selectedMemoID == id {
                let nextIndex = min(index, memos.count - 1)
                selectMemo(id: memos[nextIndex].id)
            }

            errorMessage = nil
        } catch {
            errorMessage = "Delete failed: \(error.localizedDescription)"
        }
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

    func setTheme(_ theme: MemoTheme) {
        self.theme = theme
        UserDefaults.standard.set(theme.rawValue, forKey: Self.themeDefaultsKey)
    }

    func setLineStyle(_ lineStyle: MemoLineStyle) {
        self.lineStyle = lineStyle
        UserDefaults.standard.set(lineStyle.rawValue, forKey: Self.lineStyleDefaultsKey)
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

    private static func initialSelectedMemoID(from memos: [MemoItem], sortOption: MemoSortOption) -> MemoItem.ID? {
        switch sortOption {
        case .newestFirst:
            return memos.max(by: { $0.createdAt < $1.createdAt })?.id
        case .oldestFirst:
            return memos.min(by: { $0.createdAt < $1.createdAt })?.id
        case .titleAscending:
            return memos.sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }.first?.id
        case .titleDescending:
            return memos.sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedDescending
            }.first?.id
        }
    }

    private static func loadTheme() -> MemoTheme {
        let rawValue = UserDefaults.standard.string(forKey: themeDefaultsKey) ?? MemoTheme.pink.rawValue
        return MemoTheme(rawValue: rawValue) ?? .pink
    }

    private static func loadLineStyle() -> MemoLineStyle {
        let rawValue = UserDefaults.standard.string(forKey: lineStyleDefaultsKey) ?? MemoLineStyle.none.rawValue
        return MemoLineStyle(rawValue: rawValue) ?? .none
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
            includingPropertiesForKeys: [.contentModificationDateKey, .creationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return urls
            .filter { $0.pathExtension.lowercased() == "txt" }
            .map { url in
                let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
                let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .creationDateKey])
                let createdAt = values?.creationDate ?? values?.contentModificationDate ?? Date()
                let modifiedAt = values?.contentModificationDate
                let title = url.deletingPathExtension().lastPathComponent
                return MemoItem(
                    id: UUID(),
                    title: title,
                    text: text,
                    fileName: url.lastPathComponent,
                    createdAt: createdAt,
                    lastSavedAt: modifiedAt
                )
            }
    }

    private static func makeInitialMemo(in directoryURL: URL, fileManager: FileManager) -> MemoItem {
        let legacyFileURL = directoryURL.appendingPathComponent("memo.txt")
        let legacyText = (try? String(contentsOf: legacyFileURL, encoding: .utf8)) ?? ""
        let values = try? legacyFileURL.resourceValues(forKeys: [.contentModificationDateKey, .creationDateKey])
        let createdAt = values?.creationDate ?? values?.contentModificationDate ?? Date()
        let legacyDate = values?.contentModificationDate

        return MemoItem(
            id: UUID(),
            title: "memo1",
            text: legacyText,
            fileName: "memo1.txt",
            createdAt: createdAt,
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
        let now = Date()
        store.memos = [
            MemoItem(
                id: UUID(),
                title: "memo2",
                text: "Blue theme with named sorting would look nice here.",
                fileName: "memo2.txt",
                createdAt: now.addingTimeInterval(-600),
                lastSavedAt: now.addingTimeInterval(-300)
            ),
            MemoItem(
                id: UUID(),
                title: "memo1",
                text: "Welcome to MacMemoApp.\n\nYou can now create more than one memo.",
                fileName: "memo1.txt",
                createdAt: now.addingTimeInterval(-1200),
                lastSavedAt: now.addingTimeInterval(-900)
            )
        ]
        store.selectedMemoID = store.memos.first?.id
        store.lastSavedAt = now
        store.searchText = ""
        store.sortOption = .newestFirst
        store.theme = .pink
        store.lineStyle = .regular
        return store
    }
}
