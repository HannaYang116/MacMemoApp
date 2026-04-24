import AppKit
import SwiftUI

struct ContentView: View {
    @Bindable var store: MemoStore
    @FocusState private var isEditorFocused: Bool
    @State private var copiedSavePath = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Memo")
                        .font(.system(size: 30, weight: .bold))

                    Text(store.statusMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 10) {
                    Button("Choose save location") {
                        store.chooseSaveLocation()
                    }

                    Button(copiedSavePath ? "Path copied" : "Copy save path") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(store.saveLocation, forType: .string)
                        copiedSavePath = true
                        Task { @MainActor in
                            try? await Task.sleep(for: .seconds(1.2))
                            copiedSavePath = false
                        }
                    }

                    Button("Save now") {
                        store.save()
                    }
                    .keyboardShortcut("s", modifiers: [.command])
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Saving to \(store.saveLocationDisplayName)")
                    .font(.subheadline.weight(.medium))

                Text(store.saveLocation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(2)
            }

            TextEditor(text: $store.text)
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
                .onChange(of: store.text) {
                    store.scheduleSave()
                }
                .focused($isEditorFocused)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(24)
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
            isEditorFocused = true
        }
        .onDisappear {
            store.save()
        }
    }
}

#Preview {
    ContentView(store: MemoStore.preview)
}
