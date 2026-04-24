import SwiftUI

struct ContentView: View {
    @Bindable var store: MemoStore

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Memo")
                    .font(.system(size: 30, weight: .bold))

                Text(store.statusMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            TextEditor(text: $store.text)
                .font(.system(size: 16))
                .padding(14)
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
        }
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
    }
}

#Preview {
    ContentView(store: MemoStore.preview)
}
