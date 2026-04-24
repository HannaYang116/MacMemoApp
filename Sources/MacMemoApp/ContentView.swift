import AppKit
import SwiftUI

struct ContentView: View {
    @Bindable var store: MemoStore
    @FocusState private var focusedField: Field?
    @State private var copiedSavePath = false

    private enum Field: Hashable {
        case title
        case body
    }

    var body: some View {
        HSplitView {
            sidebar
                .frame(minWidth: 220, idealWidth: 250, maxWidth: 300)

            editor
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(nsColor: .underPageBackgroundColor)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .task {
            focusedField = .body
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Memos")
                    .font(.title2.bold())

                Spacer()

                Button {
                    store.addMemo()
                    focusedField = .title
                } label: {
                    Label("New Memo", systemImage: "plus")
                }
            }

            List(selection: Binding(get: { store.selectedMemoID }, set: { store.selectMemo(id: $0) })) {
                ForEach(store.memos) { memo in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(memo.title)
                            .font(.headline)
                            .lineLimit(1)

                        Text(memoPreview(memo.text))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .padding(.vertical, 6)
                    .tag(memo.id)
                }
            }
            .listStyle(.sidebar)

            VStack(alignment: .leading, spacing: 4) {
                Text("Memo folder")
                    .font(.subheadline.weight(.medium))

                Text(store.saveLocation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(3)
            }
        }
        .padding(18)
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("MacMemoApp")
                        .font(.system(size: 30, weight: .bold))

                    Text(store.statusMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 10) {
                    Button("Choose memo folder") {
                        store.chooseSaveLocation()
                    }

                    Button(copiedSavePath ? "Path copied" : "Copy folder path") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(store.saveLocation, forType: .string)
                        copiedSavePath = true
                        Task { @MainActor in
                            try? await Task.sleep(for: .seconds(1.2))
                            copiedSavePath = false
                        }
                    }

                    Button("Save now") {
                        store.saveSelectedMemo()
                    }
                    .keyboardShortcut("s", modifiers: [.command])
                }
            }

            if store.hasSelection {
                TextField("Memo title", text: $store.selectedMemoTitle)
                    .textFieldStyle(.roundedBorder)
                    .font(.title3.weight(.semibold))
                    .focused($focusedField, equals: .title)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Saved as \(store.selectedMemoFileName)")
                        .font(.subheadline.weight(.medium))

                    Text(store.saveLocation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                TextEditor(text: $store.selectedMemoText)
                    .font(.system(size: 16))
                    .padding(14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .scrollContentBackground(.hidden)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(nsColor: .textBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                    .focused($focusedField, equals: .body)
            } else {
                ContentUnavailableView(
                    "No Memo Selected",
                    systemImage: "note.text",
                    description: Text("Create a memo from the sidebar to start writing.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onDisappear {
            store.saveAllMemos()
        }
    }

    private func memoPreview(_ text: String) -> String {
        let collapsed = text
            .split(whereSeparator: \.isNewline)
            .prefix(2)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return collapsed.isEmpty ? "Empty memo" : collapsed
    }
}

#Preview {
    ContentView(store: MemoStore.preview)
}
