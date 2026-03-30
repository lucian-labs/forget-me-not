import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(TaskStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var appName = ""
    @State private var newCategory = ""
    @State private var showClearConfirm = false
    @State private var showExportShare = false
    @State private var exportData: Data?
    @State private var showImportPicker = false
    @State private var showHeaderFontPicker = false
    @State private var showBodyFontPicker = false
    @State private var showTransferQR = false
    @State private var transferImage: UIImage?
    @State private var transferURL: String?
    @State private var transferError: String?
    @State private var importMessage: String?
    @State private var soundSeed = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                appNameCard
                categoriesCard
                themeCard
                soundCard
                syncCard
                dataCard
            }
            .padding()
        }
        .background(store.theme.bg.ignoresSafeArea())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        .onAppear {
            appName = store.settings.appName
            soundSeed = store.settings.soundSeed
        }
        .confirmationDialog("Delete all tasks and settings?", isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button("Delete Everything", role: .destructive) {
                store.clearAll()
                appName = ""
            }
        }
        .fileImporter(isPresented: $showImportPicker, allowedContentTypes: [.json]) { result in
            if case .success(let url) = result {
                importFile(url)
            }
        }
    }

    // MARK: - App Name

    private var appNameCard: some View {
        settingsCard {
            cardTitle("App Name")
            TextField("forget me not", text: $appName)
                .textFieldStyle(.roundedBorder)
                .onChange(of: appName) { _, val in
                    store.updateSettings { $0.appName = val }
                }
            Text("Give the app your own name. Leave blank for default.")
                .font(.system(size: 11))
                .foregroundStyle(store.theme.dim)
        }
    }

    // MARK: - Categories

    private var categoriesCard: some View {
        settingsCard {
            cardTitle("Categories")

            FlowTags(items: store.settings.domains) { domain in
                HStack(spacing: 4) {
                    Text(domain).font(.caption)
                    Button {
                        store.updateSettings { $0.domains.removeAll { $0 == domain } }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(store.theme.dim)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(store.theme.accent.opacity(0.1))
                .clipShape(Capsule())
            }

            TextField("Add category...", text: $newCategory)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))
                .onSubmit {
                    let val = newCategory.trimmingCharacters(in: .whitespaces).lowercased()
                    guard !val.isEmpty, !store.settings.domains.contains(val) else { return }
                    store.updateSettings { $0.domains.append(val) }
                    newCategory = ""
                }
        }
    }

    // MARK: - Theme

    private var themeCard: some View {
        settingsCard {
            cardTitle("Theme")

            HStack {
                Text("Style").font(.caption).foregroundStyle(store.theme.dim)
                Spacer()
                Picker("", selection: Binding(
                    get: { store.settings.themePreset },
                    set: { val in
                        store.updateSettings {
                            $0.themePreset = val
                            $0.customColors = [:]
                            $0.customBorderRadius = nil
                            $0.customFontSize = nil
                            $0.customHeaderFont = nil
                            $0.customBodyFont = nil
                        }
                    }
                )) {
                    ForEach(AppTheme.all) { theme in
                        Text(theme.label).tag(theme.name)
                    }
                }
                .pickerStyle(.menu)
            }

            DisclosureGroup("Customize") {
                VStack(spacing: 12) {
                    colorPicker("Accent", key: "accent")
                    colorPicker("Background", key: "bg")
                    colorPicker("Cards", key: "surface")
                    colorPicker("Text", key: "text")
                    colorPicker("On track", key: "green")
                    colorPicker("Warning", key: "orange")
                    colorPicker("Overdue", key: "red")

                    HStack {
                        Text("Corners").font(.caption).foregroundStyle(store.theme.dim)
                        Slider(
                            value: Binding(
                                get: { store.settings.customBorderRadius ?? Double(currentBase.borderRadius) },
                                set: { newVal in store.updateSettings { $0.customBorderRadius = newVal } }
                            ),
                            in: 0...24, step: 1
                        )
                        Text("\(Int(store.theme.borderRadius))px")
                            .font(.system(size: 11))
                            .foregroundStyle(store.theme.dim)
                            .frame(width: 32)
                    }

                    HStack {
                        Text("Text size").font(.caption).foregroundStyle(store.theme.dim)
                        Slider(
                            value: Binding(
                                get: { store.settings.customFontSize ?? Double(currentBase.fontSize) },
                                set: { newVal in store.updateSettings { $0.customFontSize = newVal } }
                            ),
                            in: 11...20, step: 1
                        )
                        Text("\(Int(store.theme.fontSize))pt")
                            .font(.system(size: 11))
                            .foregroundStyle(store.theme.dim)
                            .frame(width: 32)
                    }

                    // Font pickers
                    fontPickerRow(
                        label: "Title font",
                        current: store.theme.headerFont,
                        action: { showHeaderFontPicker = true }
                    )

                    fontPickerRow(
                        label: "Body font",
                        current: store.theme.bodyFont,
                        action: { showBodyFontPicker = true }
                    )
                }
                .padding(.top, 4)
            }
            .tint(store.theme.dim)
            .sheet(isPresented: $showHeaderFontPicker) {
                NavigationStack {
                    FontPickerView(
                        title: "Title Font",
                        selection: Binding(
                            get: { store.settings.customHeaderFont },
                            set: { val in store.updateSettings { $0.customHeaderFont = val } }
                        ),
                        defaultFont: currentBase.headerFont
                    )
                }
                .environment(store)
                .preferredColorScheme(store.theme.isDark ? .dark : .light)
            }
            .sheet(isPresented: $showBodyFontPicker) {
                NavigationStack {
                    FontPickerView(
                        title: "Body Font",
                        selection: Binding(
                            get: { store.settings.customBodyFont },
                            set: { val in store.updateSettings { $0.customBodyFont = val } }
                        ),
                        defaultFont: currentBase.bodyFont
                    )
                }
                .environment(store)
                .preferredColorScheme(store.theme.isDark ? .dark : .light)
            }
        }
    }

    // MARK: - Sound

    private var soundCard: some View {
        settingsCard {
            cardTitle("Sound")

            HStack(spacing: 12) {
                Toggle("", isOn: Binding(
                    get: { store.settings.soundEnabled },
                    set: { val in store.updateSettings { $0.soundEnabled = val } }
                ))
                .labelsHidden()

                Picker("", selection: Binding(
                    get: { store.settings.soundPreset },
                    set: { val in store.updateSettings { $0.soundPreset = val } }
                )) {
                    ForEach(soundPresets, id: \.value) { Text($0.label).tag($0.value) }
                }
                .pickerStyle(.menu)
                .labelsHidden()

                Button {
                    SoundManager.shared.playTest(settings: store.settings)
                } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 14))
                }
                .buttonStyle(.bordered)
            }

            DisclosureGroup("Fine-tune") {
                VStack(spacing: 12) {
                    HStack {
                        Text("Seed").font(.caption).foregroundStyle(store.theme.dim)
                        TextField("forgetmenot", text: $soundSeed)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 13))
                            .onSubmit {
                                store.updateSettings { $0.soundSeed = soundSeed.isEmpty ? "forgetmenot" : soundSeed }
                            }
                    }

                    HStack {
                        Text("BPM").font(.caption).foregroundStyle(store.theme.dim)
                        Slider(
                            value: Binding(
                                get: { Double(store.settings.soundBpm) },
                                set: { newVal in store.updateSettings { $0.soundBpm = Int(newVal) } }
                            ),
                            in: 60...240, step: 10
                        )
                        Text("\(store.settings.soundBpm)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(store.theme.dim)
                            .frame(width: 32)
                    }

                    HStack {
                        Text("Volume").font(.caption).foregroundStyle(store.theme.dim)
                        Slider(
                            value: Binding(
                                get: { store.settings.soundVolume },
                                set: { newVal in store.updateSettings { $0.soundVolume = newVal } }
                            ),
                            in: 0...1
                        )
                        Text("\(Int(store.settings.soundVolume * 100))%")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(store.theme.dim)
                            .frame(width: 32)
                    }
                }
                .padding(.top, 4)
            }
            .tint(store.theme.dim)
        }
    }

    // MARK: - Sync

    private var syncCard: some View {
        settingsCard {
            cardTitle("Sync")
            Text("Coming soon \u{2014} sync your tasks across devices.")
                .font(.system(size: 13))
                .foregroundStyle(store.theme.dim)
        }
    }

    // MARK: - Data

    private var dataCard: some View {
        settingsCard {
            cardTitle("Data")

            // Transfer section
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    if let result = TransferManager.generateTransferQR(store: store) {
                        transferImage = result.image
                        transferURL = result.url
                        transferError = nil
                        showTransferQR = true
                    } else {
                        let kb = TransferManager.exportSizeKB(store: store)
                        transferError = "Data is \(kb)KB — too large for QR (max ~4KB). Use Export instead."
                        transferImage = nil
                        showTransferQR = true
                    }
                } label: {
                    Label("Transfer to device", systemImage: "qrcode")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    if let result = TransferManager.importFromClipboard(into: store) {
                        switch result {
                        case .success(let count):
                            importMessage = "Imported \(count) tasks from clipboard."
                            appName = store.settings.appName
                            soundSeed = store.settings.soundSeed
                        case .failure(let err):
                            importMessage = err.localizedDescription
                        }
                    } else {
                        importMessage = "No transfer link or JSON found on clipboard."
                    }
                } label: {
                    Label("Import from clipboard", systemImage: "doc.on.clipboard")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                if let msg = importMessage {
                    Text(msg)
                        .font(.system(size: 11))
                        .foregroundStyle(store.theme.dim)
                }

                Text("Generate a QR code to move all your data to another device, or paste a transfer link from the web app.")
                    .font(.system(size: 11))
                    .foregroundStyle(store.theme.dim)
            }
            .padding(.bottom, 8)
            .sheet(isPresented: $showTransferQR) {
                TransferQRSheet(
                    image: transferImage,
                    url: transferURL,
                    error: transferError
                )
                .environment(store)
                .preferredColorScheme(store.theme.isDark ? .dark : .light)
            }

            HStack(spacing: 12) {
                Button("Export") {
                    exportData = store.exportJSON()
                    if exportData != nil { showExportShare = true }
                }
                .buttonStyle(.bordered)

                Button("Import") {
                    showImportPicker = true
                }
                .buttonStyle(.bordered)

                Button("Clear All", role: .destructive) {
                    showClearConfirm = true
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .sheet(isPresented: $showExportShare) {
            if let data = exportData {
                ShareSheet(data: data)
            }
        }
    }

    // MARK: - Helpers

    private var currentBase: AppTheme {
        AppTheme.all.first { $0.name == store.settings.themePreset } ?? .midnight
    }

    private func settingsCard<C: View>(@ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(store.theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: store.theme.borderRadius))
        .overlay(
            RoundedRectangle(cornerRadius: store.theme.borderRadius)
                .stroke(store.theme.border, lineWidth: 1)
        )
    }

    private func cardTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.5)
            .foregroundStyle(store.theme.dim)
    }

    private func fontPickerRow(label: String, current: String, action: @escaping () -> Void) -> some View {
        HStack {
            Text(label).font(.caption).foregroundStyle(store.theme.dim)
            Spacer()
            Button(action: action) {
                HStack(spacing: 4) {
                    Text(current)
                        .font(.custom(current, size: 13))
                        .foregroundStyle(store.theme.text)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10))
                        .foregroundStyle(store.theme.dim)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func colorPicker(_ label: String, key: String) -> some View {
        let base = currentBase
        let hexColors = base.colors
        let defaultHex: String = {
            switch key {
            case "bg": return hexColors.bg
            case "surface": return hexColors.surface
            case "text": return hexColors.text
            case "accent": return hexColors.accent
            case "green": return hexColors.green
            case "orange": return hexColors.orange
            case "red": return hexColors.red
            default: return "#888888"
            }
        }()

        return HStack {
            Text(label).font(.caption).foregroundStyle(store.theme.dim)
            Spacer()
            ColorPicker("", selection: Binding(
                get: { Color(hex: store.settings.customColors[key] ?? defaultHex) },
                set: { newColor in
                    if let hex = newColor.toHex() {
                        store.updateSettings { $0.customColors[key] = hex }
                    }
                }
            ))
            .labelsHidden()
        }
    }

    private func importFile(_ url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        guard let data = try? Data(contentsOf: url) else { return }
        try? store.importJSON(data)
        appName = store.settings.appName
    }

    private let soundPresets: [(label: String, value: Int)] = [
        ("Crystal", 88), ("Hand Bell", 90), ("Chimes", 91),
        ("Music Box", 59), ("Vibraphone", 17), ("Raindrop", 77),
        ("Piano", 0), ("Flute", 30), ("Bell", 92), ("Whistle", 74),
    ]
}

// MARK: - Flow Tags

struct FlowTags<Item: Hashable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 6)], spacing: 6) {
            ForEach(items, id: \.self) { item in
                content(item)
            }
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let data: Data

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let dateStr = ISO8601DateFormatter().string(from: Date()).prefix(10)
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("forget-me-not-\(dateStr).json")
        try? data.write(to: tempURL)
        return UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Color to hex

extension Color {
    func toHex() -> String? {
        guard let components = UIColor(self).cgColor.components else { return nil }
        let r = Int((components[0] * 255).rounded())
        let g = Int(((components.count > 1 ? components[1] : components[0]) * 255).rounded())
        let b = Int(((components.count > 2 ? components[2] : components[0]) * 255).rounded())
        return String(format: "#%02x%02x%02x", r, g, b)
    }
}

// MARK: - Transfer QR Sheet

struct TransferQRSheet: View {
    let image: UIImage?
    let url: String?
    let error: String?
    @Environment(TaskStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let error {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundStyle(store.theme.orange)
                    Text("Too much data for QR")
                        .font(.headline)
                        .foregroundStyle(store.theme.text)
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundStyle(store.theme.dim)
                        .multilineTextAlignment(.center)
                } else if let image {
                    Text("Scan to transfer")
                        .font(.headline)
                        .foregroundStyle(store.theme.accent)
                    Text("Scan this QR code on your other device to import all tasks and settings.")
                        .font(.system(size: 13))
                        .foregroundStyle(store.theme.dim)
                        .multilineTextAlignment(.center)

                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 240, height: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    if let url {
                        Button {
                            UIPasteboard.general.string = url
                            copied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                        } label: {
                            Text(copied ? "Copied!" : "Copy link instead")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(store.theme.bg)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
