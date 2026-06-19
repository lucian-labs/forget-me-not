import SwiftUI

/// Settings — currently the theme picker (the 11 web themes + Waveloop). Each swatch
/// previews the palette; tapping applies it instantly app-wide.
struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ZStack {
            WL.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Text("SETTINGS").font(WL.mono(15, .bold)).tracking(3).foregroundStyle(WL.text)
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark").font(.system(size: 15, weight: .bold)).foregroundStyle(WL.muted)
                        }
                    }

                    Text("MASCOT STYLE").font(WL.mono(10, .bold)).tracking(2).foregroundStyle(WL.muted)
                    TextField("e.g. 90s claymation, neon sticker, crayon doodle", text: Binding(
                        get: { store.mascotStyle },
                        set: { store.setMascotStyle($0) }
                    ))
                    .font(WL.mono(13)).foregroundStyle(WL.text).tint(WL.accent)
                    .autocorrectionDisabled()
                    .padding(12).wlPanel(fill: WL.surface, border: WL.border)
                    Text("Woven into every generated animal. Blank = default cartoon alien.")
                        .font(WL.mono(9)).foregroundStyle(WL.muted)
                    promptEditor(text: Binding(get: { store.mascotPrompt }, set: { store.setMascotPrompt($0) }),
                                 reset: { store.resetMascotPrompt() },
                                 hint: "tokens: {animal} {task} {details} {mood} {style}")

                    Text("PROMPT STYLE").font(WL.mono(10, .bold)).tracking(2).foregroundStyle(WL.muted)
                    TextField("e.g. drill sergeant, gentle friend, pirate", text: Binding(
                        get: { store.nudgeStyle },
                        set: { store.setNudgeStyle($0) }
                    ))
                    .font(WL.mono(13)).foregroundStyle(WL.text).tint(WL.accent)
                    .autocorrectionDisabled()
                    .padding(12).wlPanel(fill: WL.surface, border: WL.border)
                    Text("The voice your nudges are written in. Blank = calm coach.")
                        .font(WL.mono(9)).foregroundStyle(WL.muted)
                    promptEditor(text: Binding(get: { store.nudgeInstructions }, set: { store.setNudgeInstructions($0) }),
                                 reset: { store.resetNudgeInstructions() }, hint: nil)

                    Text("THEME").font(WL.mono(10, .bold)).tracking(2).foregroundStyle(WL.muted)

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(Theme.all) { theme in
                            swatch(theme, selected: store.themeName == theme.name)
                                .onTapGesture { store.setTheme(theme.name) }
                        }
                    }
                }
                .padding(20)
            }
        }
        .preferredColorScheme(.dark)
    }

    /// Editable system prompt sent to the on-device models. Bound to the store so edits
    /// take effect on the next generation; RESET restores the default.
    private func promptEditor(text: Binding<String>, reset: @escaping () -> Void, hint: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("SYSTEM PROMPT").font(WL.mono(9, .bold)).tracking(1).foregroundStyle(WL.accent)
                Spacer()
                Button(action: reset) {
                    Text("RESET").font(WL.mono(9, .bold)).tracking(1).foregroundStyle(WL.muted)
                }
            }
            TextEditor(text: text)
                .font(WL.mono(11)).foregroundStyle(WL.text).tint(WL.accent)
                .scrollContentBackground(.hidden)
                .autocorrectionDisabled()
                .frame(minHeight: 96)
                .padding(8).wlPanel(fill: WL.surface, border: WL.border)
            if let hint {
                Text(hint).font(WL.mono(9)).foregroundStyle(WL.muted)
            }
        }
    }

    private func swatch(_ theme: Theme, selected: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(theme.label.uppercased())
                    .font(WL.mono(11, .bold)).tracking(1)
                    .foregroundStyle(Color(hex: theme.text))
                Spacer()
                if selected {
                    Image(systemName: "checkmark").font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(hex: theme.accent))
                }
            }
            HStack(spacing: 4) {
                ForEach([theme.accent, theme.green, theme.orange, theme.red, theme.cyan], id: \.self) { c in
                    Rectangle().fill(Color(hex: c)).frame(height: 16)
                }
            }
        }
        .padding(12)
        .background(Color(hex: theme.surface), in: RoundedRectangle(cornerRadius: theme.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: theme.radius, style: .continuous)
            .stroke(selected ? Color(hex: theme.accent) : Color(hex: theme.border), lineWidth: selected ? 2 : 1))
    }
}
