import SwiftUI

struct ContentView: View {
    @Bindable var store: MemoStore
    @FocusState private var focusedField: Field?
    @State private var showingSettings = false
    @State private var hoveredMemoID: MemoItem.ID?

    private enum Field: Hashable {
        case title
        case body
    }

    var body: some View {
        HSplitView {
            sidebar
                .frame(minWidth: 250, idealWidth: 280, maxWidth: 340)

            editor
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundGradient)
        .sheet(isPresented: $showingSettings) {
            SettingsView(store: store)
        }
        .task {
            focusedField = .body
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Memos")
                    .font(.title2.bold())
                    .foregroundStyle(store.theme.tint)

                Spacer()

                Button {
                    store.addMemo()
                    focusedField = .title
                } label: {
                    Label("New Memo", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(store.theme.tint)
            }

            TextField("Search titles", text: $store.searchText)
                .textFieldStyle(.roundedBorder)

            Menu {
                Picker("Sort", selection: $store.sortOption) {
                    ForEach(MemoSortOption.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
            } label: {
                Label("Sort: \(store.sortOption.label)", systemImage: "arrow.up.arrow.down")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .menuStyle(.borderlessButton)
            .buttonStyle(.bordered)

            List(selection: Binding(get: { store.selectedMemoID }, set: { store.selectMemo(id: $0) })) {
                ForEach(store.filteredSortedMemos) { memo in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(memo.title)
                                .font(.headline)
                                .lineLimit(1)

                            Spacer()

                            if hoveredMemoID == memo.id || store.selectedMemoID == memo.id {
                                Button(role: .destructive) {
                                    store.deleteMemo(id: memo.id)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.caption)
                                }
                                .buttonStyle(.plain)
                            }

                            Text(memo.createdAt.formatted(date: .numeric, time: .omitted))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Text(memoPreview(memo.text))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .padding(.vertical, 6)
                    .tag(memo.id)
                    .onHover { isHovering in
                        hoveredMemoID = isHovering ? memo.id : (hoveredMemoID == memo.id ? nil : hoveredMemoID)
                    }
                    .contextMenu {
                        Button("Delete", role: .destructive) {
                            store.deleteMemo(id: memo.id)
                        }
                    }
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(store.selectedMemoID == memo.id ? store.theme.accent.opacity(0.85) : .clear)
                            .padding(.vertical, 2)
                    )
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            VStack(alignment: .leading, spacing: 4) {
                Text("Memo folder")
                    .font(.subheadline.weight(.medium))

                Text(store.saveLocation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(3)
            }

            HStack {
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .foregroundStyle(store.theme.tint)

                Spacer()
            }
            .padding(.top, 4)
        }
        .padding(18)
        .background(store.theme.background.opacity(0.75))
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("MacMemoApp")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(store.theme.tint)

                    Text(store.statusMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 10) {
                    Button("Path") {
                        store.chooseSaveLocation()
                    }
                    .buttonStyle(.bordered)

                    Button("Save now") {
                        store.saveSelectedMemo()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(store.theme.tint)
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
                    .padding(.horizontal, 16)
                    .padding(.vertical, 18)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .scrollContentBackground(.hidden)
                    .background {
                        MemoEditorBackground(theme: store.theme, lineStyle: store.lineStyle)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(store.theme.tint.opacity(0.18), lineWidth: 1.2)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
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
        .background(store.theme.background.opacity(0.45))
        .onDisappear {
            store.saveAllMemos()
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [store.theme.background, store.theme.secondaryBackground],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
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

private struct MemoEditorBackground: View {
    let theme: MemoTheme
    let lineStyle: MemoLineStyle

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.white.opacity(0.78))

                if lineStyle != .none {
                    Path { path in
                        let spacing: CGFloat = lineStyle == .regular ? 28 : 22
                        let inset: CGFloat = 16
                        var y: CGFloat = inset + spacing

                        while y < geometry.size.height - inset {
                            path.move(to: CGPoint(x: inset, y: y))
                            path.addLine(to: CGPoint(x: geometry.size.width - inset, y: y))
                            y += spacing
                        }
                    }
                    .stroke(
                        theme.tint.opacity(lineStyle == .regular ? 0.22 : 0.12),
                        lineWidth: lineStyle == .regular ? 1.2 : 0.7
                    )
                }
            }
        }
    }
}

#Preview {
    ContentView(store: MemoStore.preview)
}
