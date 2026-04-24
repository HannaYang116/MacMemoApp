import SwiftUI

struct SettingsView: View {
    @Bindable var store: MemoStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Text("Settings")
                    .font(.title2.bold())
                    .foregroundStyle(store.theme.tint)

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(store.theme.tint)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Theme")
                    .font(.headline)

                HStack(spacing: 12) {
                    ForEach(MemoTheme.allCases) { theme in
                        Button(theme.label) {
                            store.setTheme(theme)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(theme.tint)
                        .opacity(store.theme == theme ? 1 : 0.72)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Line")
                    .font(.headline)

                HStack(spacing: 12) {
                    ForEach(MemoLineStyle.allCases) { lineStyle in
                        Button(lineStyle.label) {
                            store.setLineStyle(lineStyle)
                        }
                        .buttonStyle(.bordered)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(store.lineStyle == lineStyle ? store.theme.accent : .clear)
                        )
                    }
                }
            }

            Text("Your theme and line style are applied to the whole memo app immediately.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(24)
        .frame(minWidth: 420, minHeight: 240, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [store.theme.background, store.theme.secondaryBackground],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}
