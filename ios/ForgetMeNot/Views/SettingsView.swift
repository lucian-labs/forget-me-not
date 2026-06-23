import SwiftUI
import UserNotifications

/// Settings — theme picker, mascot/nudge styles, prompt lab, MCP + notification controls.
struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(IconStore.self) private var icons
    @Environment(\.dismiss) private var dismiss
    @State private var showPromptLab = false
    @State private var notifStatus: UNAuthorizationStatus = .notDetermined

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

                    Text("ICON STYLE").font(WL.mono(10, .bold)).tracking(2).foregroundStyle(WL.muted)
                    TextField("e.g. 90s claymation, neon sticker, crayon doodle", text: Binding(
                        get: { store.iconStyle },
                        set: { store.setIconStyle($0) }
                    ))
                    .font(WL.mono(13)).foregroundStyle(WL.text).tint(WL.accent)
                    .autocorrectionDisabled()
                    .padding(12).wlPanel(fill: WL.surface, border: WL.border)
                    Text("Woven into every icon. Blank = the default style below.")
                        .font(WL.mono(9)).foregroundStyle(WL.muted)

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

                    Button { showPromptLab = true } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "wand.and.stars").font(.system(size: 13, weight: .bold))
                            Text("PROMPT LAB").font(WL.mono(12, .bold)).tracking(1)
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold))
                        }
                        .foregroundStyle(WL.accent)
                        .padding(.horizontal, 12).padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .wlPanel(fill: WL.surface, border: WL.border)
                    }
                    Text("Edit every prompt + injected value the on-device models use.")
                        .font(WL.mono(9)).foregroundStyle(WL.muted)

                    Text("MCP SERVER").font(WL.mono(10, .bold)).tracking(2).foregroundStyle(WL.muted)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("http://localhost:8473")
                            .font(WL.mono(13, .bold)).foregroundStyle(WL.accent).textSelection(.enabled)
                        Text("While the app is open it serves your tasks as MCP tools (list, add, reset, complete, log, set icon, pause, delete). Add the URL to an MCP client to drive it.")
                            .font(WL.mono(9)).foregroundStyle(WL.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12).wlPanel(fill: WL.surface, border: WL.border)

                    Text("NOTIFICATIONS").font(WL.mono(10, .bold)).tracking(2).foregroundStyle(WL.muted)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(notifStatusText).font(WL.mono(11, .bold)).foregroundStyle(notifStatusColor)
                        Button {
                            Task {
                                await ReminderScheduler.sendTest(taskId: store.sortedActive.first?.id)
                                notifStatus = await ReminderScheduler.authStatus()
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "bell.badge").font(.system(size: 13, weight: .bold))
                                Text("SEND TEST (4s)").font(WL.mono(12, .bold)).tracking(1)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .foregroundStyle(WL.bg).background(WL.accent)
                        }
                        Text("Fires a reminder in 4 seconds. If nothing appears, enable it in System Settings › Notifications › Forget Me Not (banners on).")
                            .font(WL.mono(9)).foregroundStyle(WL.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12).wlPanel(fill: WL.surface, border: WL.border)

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
        .sheet(isPresented: $showPromptLab) {
            PromptLabView().environment(store).environment(icons)
        }
        .task { notifStatus = await ReminderScheduler.authStatus() }
    }

    private var notifStatusText: String {
        switch notifStatus {
        case .authorized, .provisional, .ephemeral: "Allowed"
        case .denied: "Off — enable in System Settings"
        default: "Not requested yet — tap Send Test"
        }
    }
    private var notifStatusColor: Color {
        switch notifStatus {
        case .authorized, .provisional, .ephemeral: WL.green
        case .denied: WL.red
        default: WL.muted
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
