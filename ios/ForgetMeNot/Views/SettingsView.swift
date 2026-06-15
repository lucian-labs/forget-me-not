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
        .background(Color(hex: theme.surface))
        .overlay(Rectangle().stroke(selected ? Color(hex: theme.accent) : Color(hex: theme.border),
                                    lineWidth: selected ? 2 : 1))
    }
}
