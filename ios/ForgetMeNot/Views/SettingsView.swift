import SwiftUI
import UserNotifications

/// Settings — theme picker, mascot/nudge styles, prompt lab, MCP + notification controls.
struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(IconStore.self) private var icons
    @Environment(AlertSounder.self) private var sounder
    @Environment(\.dismiss) private var dismiss
    @State private var showPromptLab = false
    @State private var notifStatus: UNAuthorizationStatus = .notDetermined
    @State private var themeJson = ""
    @State private var themeImportFailed = false
    @State private var userThemes: [Theme] = UserThemes.load()

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ZStack {
            WL.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Text(WL.t("Settings")).font(WL.header(15, .bold)).tracking(WL.trk(3)).foregroundStyle(WL.text)
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark").font(.system(size: 15, weight: .bold)).foregroundStyle(WL.muted)
                        }
                    }

                    Text(WL.t("Icon Style")).font(WL.header(10, .bold)).tracking(WL.trk(2)).foregroundStyle(WL.muted)
                    TextField("e.g. 90s claymation, neon sticker, crayon doodle", text: Binding(
                        get: { store.iconStyle },
                        set: { store.setIconStyle($0) }
                    ))
                    .font(WL.body(13)).foregroundStyle(WL.text).tint(WL.accent)
                    .autocorrectionDisabled()
                    .padding(12).wlPanel(fill: WL.surface, border: WL.border)
                    Text("Woven into every icon. Blank = the default style below.")
                        .font(WL.body(9)).foregroundStyle(WL.muted)

                    Text(WL.t("Prompt Style")).font(WL.header(10, .bold)).tracking(WL.trk(2)).foregroundStyle(WL.muted)
                    TextField("e.g. drill sergeant, gentle friend, pirate", text: Binding(
                        get: { store.nudgeStyle },
                        set: { store.setNudgeStyle($0) }
                    ))
                    .font(WL.body(13)).foregroundStyle(WL.text).tint(WL.accent)
                    .autocorrectionDisabled()
                    .padding(12).wlPanel(fill: WL.surface, border: WL.border)
                    Text("The voice your nudges are written in. Blank = calm coach.")
                        .font(WL.body(9)).foregroundStyle(WL.muted)

                    Button { showPromptLab = true } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "wand.and.stars").font(.system(size: 13, weight: .bold))
                            Text(WL.t("Prompt Lab")).font(WL.header(12, .bold)).tracking(WL.trk(1))
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold))
                        }
                        .foregroundStyle(WL.accent)
                        .padding(.horizontal, 12).padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .wlPanel(fill: WL.surface, border: WL.border)
                    }
                    Text("Edit every prompt + injected value the on-device models use.")
                        .font(WL.body(9)).foregroundStyle(WL.muted)

                    #if DEBUG
                    // Dev-only: the local MCP server is compiled out of Release builds.
                    Text(WL.t("MCP Server")).font(WL.header(10, .bold)).tracking(WL.trk(2)).foregroundStyle(WL.muted)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("http://localhost:8473")
                            .font(WL.body(13, .bold)).foregroundStyle(WL.accent).textSelection(.enabled)
                        Text("While the app is open it serves your tasks as MCP tools (list, add, reset, complete, log, set icon, pause, delete). Add the URL to an MCP client to drive it.")
                            .font(WL.body(9)).foregroundStyle(WL.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12).wlPanel(fill: WL.surface, border: WL.border)
                    #endif

                    Text(WL.t("Notifications")).font(WL.header(10, .bold)).tracking(WL.trk(2)).foregroundStyle(WL.muted)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(notifStatusText).font(WL.body(11, .bold)).foregroundStyle(notifStatusColor)
                        Button {
                            Task {
                                await ReminderScheduler.sendTest(taskId: store.sortedActive.first?.id)
                                notifStatus = await ReminderScheduler.authStatus()
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "bell.badge").font(.system(size: 13, weight: .bold))
                                Text("SEND TEST (4s)").font(WL.body(12, .bold)).tracking(WL.trk(1))
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .foregroundStyle(WL.bg).background(WL.accent)
                        }
                        Text("Fires a reminder in 4 seconds. If nothing appears, enable it in System Settings › Notifications › Forget Me Not (banners on).")
                            .font(WL.body(9)).foregroundStyle(WL.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12).wlPanel(fill: WL.surface, border: WL.border)

                    Text(WL.t("Sound")).font(WL.header(10, .bold)).tracking(WL.trk(2)).foregroundStyle(WL.muted)
                    soundSection

                    Text(WL.t("Theme")).font(WL.header(10, .bold)).tracking(WL.trk(2)).foregroundStyle(WL.muted)

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(Theme.all + userThemes) { theme in
                            swatch(theme, selected: store.themeName == theme.name)
                                .onTapGesture { store.setTheme(theme.name) }
                                .onLongPressGesture {
                                    // Long-press removes an imported theme (built-ins stay).
                                    guard userThemes.contains(where: { $0.name == theme.name }) else { return }
                                    UserThemes.remove(theme.name)
                                    userThemes = UserThemes.load()
                                    if store.themeName == theme.name { store.setTheme("goldleaf") }
                                }
                        }
                    }

                    // Import a theme made on the web (Settings -> Theme -> Copy JSON there,
                    // paste here). Accepts the same ThemeStyle JSON the web shares.
                    HStack(spacing: 8) {
                        TextField("Paste a theme from the web...", text: $themeJson)
                            .font(WL.body(12)).foregroundStyle(WL.text).tint(WL.accent)
                            .autocorrectionDisabled()
                            .padding(10).wlPanel(fill: WL.surface, border: WL.border)
                        Button {
                            guard let theme = UserThemes.importWebJson(themeJson) else {
                                themeImportFailed = true
                                return
                            }
                            themeImportFailed = false
                            themeJson = ""
                            userThemes = UserThemes.load()
                            store.setTheme(theme.name)
                        } label: {
                            Text(WL.t("Add")).font(WL.header(11, .bold)).tracking(WL.trk(1))
                                .foregroundStyle(WL.bg)
                                .padding(.horizontal, 14).padding(.vertical, 12)
                                .background(WL.accent).wlClip()
                        }
                    }
                    if themeImportFailed {
                        Text("That didn't look like a theme — copy the JSON from the web app's theme settings.")
                            .font(WL.body(10)).foregroundStyle(WL.red)
                    }
                }
                .padding(20)
            }
        }
        .preferredColorScheme(WL.isLight ? .light : .dark)
        .sheet(isPresented: $showPromptLab) {
            PromptLabView().environment(store).environment(icons)
        }
        .task { notifStatus = await ReminderScheduler.authStatus() }
    }

    /// Web-parity sound controls (src/sounds.ts): on/off, mood (scale), energy (bpm),
    /// volume, and a variation number — plus TEST. Each task gets its own little jingle
    /// when its timer runs out; these shape how all of them sound.
    private var soundSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: Binding(get: { store.soundEnabled }, set: { store.setSoundEnabled($0) })) {
                Text(WL.t("Play a sound when time runs out")).font(WL.header(11, .bold)).tracking(WL.trk(1)).foregroundStyle(WL.text)
            }
            .tint(WL.accent)

            if store.soundEnabled {
                HStack(spacing: 8) {
                    Text(WL.t("Seed")).font(WL.header(10, .bold)).tracking(WL.trk(1)).foregroundStyle(WL.muted)
                    TextField("forgetmenot", text: Binding(
                        get: { store.soundSeed },
                        set: { store.setSoundSeed($0) }
                    ))
                    .font(WL.body(11)).foregroundStyle(WL.text).tint(WL.accent)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onSubmit { sounder.test(config: store.soundConfig) }
                    .padding(8).wlPanel(fill: WL.surface, border: WL.border)
                }
                Text("The word every tune grows from — change it and the whole soundscape changes.")
                    .font(WL.body(9)).foregroundStyle(WL.muted)
                HStack {
                    Text(WL.t("Mood")).font(WL.header(10, .bold)).tracking(WL.trk(1)).foregroundStyle(WL.muted)
                    Spacer()
                    Picker("", selection: Binding(get: { store.soundMode }, set: { store.setSoundMode($0) })) {
                        // The web's 10 YamaBruh moods — each curates scales, contour, rhythm.
                        ForEach(Array(SynthEngine.moodNames.enumerated()), id: \.offset) { i, name in
                            Text(name).tag(i)
                        }
                    }
                    .pickerStyle(.menu).tint(WL.accent)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(WL.t("Energy")).font(WL.header(10, .bold)).tracking(WL.trk(1)).foregroundStyle(WL.muted)
                        Spacer()
                        Text("\(Int(store.soundBpm)) BPM").font(WL.mono(10)).foregroundStyle(WL.muted)
                    }
                    Slider(value: Binding(get: { store.soundBpm }, set: { store.setSoundBpm($0) }), in: 60...240, step: 10)
                        .tint(WL.accent)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(WL.t("Volume")).font(WL.header(10, .bold)).tracking(WL.trk(1)).foregroundStyle(WL.muted)
                        Spacer()
                        Text("\(Int(store.soundVolume * 100))%").font(WL.mono(10)).foregroundStyle(WL.muted)
                    }
                    Slider(value: Binding(get: { store.soundVolume }, set: { store.setSoundVolume($0) }), in: 0.05...1)
                        .tint(WL.accent)
                }
                HStack {
                    Text(WL.t("Pitch")).font(WL.header(10, .bold)).tracking(WL.trk(1)).foregroundStyle(WL.muted)
                    Spacer()
                    Picker("", selection: Binding(
                        get: { store.soundOctave },
                        set: { store.setSoundOctave($0); sounder.test(config: store.soundConfig) }
                    )) {
                        Text("Two octaves down").tag(-2)
                        Text("An octave down").tag(-1)
                        Text("Normal").tag(0)
                        Text("An octave up").tag(1)
                        Text("Two octaves up").tag(2)
                    }
                    .pickerStyle(.menu).tint(WL.accent)
                }
                HStack {
                    Text(WL.t("Instrument")).font(WL.header(10, .bold)).tracking(WL.trk(1)).foregroundStyle(WL.muted)
                    Spacer()
                    Text("#\(store.soundPreset % SynthEngine.presetCount) \(WL.t(SynthEngine.presetName(store.soundPreset)))")
                        .font(WL.body(10, .bold)).foregroundStyle(WL.accent)
                }
                HStack(spacing: 10) {
                    Button {
                        store.setSoundPreset(Int.random(in: 0..<SynthEngine.presetCount))
                        sounder.test(config: store.soundConfig)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "dice").font(.system(size: 13, weight: .bold))
                            Text(WL.t("Shuffle All Sounds")).font(WL.header(11, .bold)).tracking(WL.trk(1))
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .foregroundStyle(WL.accent)
                    }
                    .wlStroke(WL.accent)
                    Button {
                        sounder.test(config: store.soundConfig)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "speaker.wave.2.fill").font(.system(size: 13, weight: .bold))
                            Text(WL.t("Test")).font(WL.header(11, .bold)).tracking(WL.trk(1))
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .foregroundStyle(WL.bg).background(WL.accent)
                    }
                }
                Text("Every task has its own little tune so you learn what's calling you. Shuffle gives everything new tunes.")
                    .font(WL.body(9)).foregroundStyle(WL.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12).wlPanel(fill: WL.surface, border: WL.border)
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
                Text(WL.t(theme.label))
                    .font(WL.body(11, .bold)).tracking(WL.trk(1))
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
