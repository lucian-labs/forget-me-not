import SwiftUI

/// Every prompt + injected value the on-device models use, laid bare and editable. Edits
/// save immediately and apply to the next generation; blanking a field restores its
/// default. "Regenerate icons" wipes the cached images so prompt changes show at once.
struct PromptLabView: View {
    @Environment(AppStore.self) private var store
    @Environment(IconStore.self) private var icons
    @Environment(\.dismiss) private var dismiss
    @State private var drafts: [String: String] = [:]

    var body: some View {
        ZStack {
            WL.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    ForEach(PromptField.Group.allCases, id: \.self) { group in
                        groupSection(group)
                    }
                    Text("Edits apply to the next generation. Blank a field to fall back to its default.")
                        .font(WL.mono(9)).foregroundStyle(WL.muted)
                }
                .padding(20)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { for f in PromptField.allCases where drafts[f.id] == nil { drafts[f.id] = f.value } }
    }

    private var header: some View {
        HStack {
            Text("PROMPT LAB").font(WL.mono(15, .bold)).tracking(3).foregroundStyle(WL.text)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 15, weight: .bold)).foregroundStyle(WL.muted)
            }
        }
    }

    @ViewBuilder
    private func groupSection(_ group: PromptField.Group) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(group.rawValue).font(WL.mono(11, .bold)).tracking(2).foregroundStyle(WL.accent)
            ForEach(PromptField.allCases.filter { $0.group == group }) { field in
                fieldEditor(field)
            }
            if group == .icon && icons.available {
                Button { icons.regenerateAll(for: store.sortedActive) } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 12, weight: .bold))
                        Text("REGENERATE ICONS NOW").font(WL.mono(11, .bold)).tracking(1)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .foregroundStyle(WL.bg).background(WL.accent)
                }
            }
        }
    }

    @ViewBuilder
    private func fieldEditor(_ field: PromptField) -> some View {
        let binding = Binding(get: { drafts[field.id] ?? field.value },
                              set: { drafts[field.id] = $0; field.set($0) })
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(field.label.uppercased()).font(WL.mono(9, .bold)).tracking(1).foregroundStyle(WL.muted)
                Spacer()
                Button { field.reset(); drafts[field.id] = field.value } label: {
                    Text("RESET").font(WL.mono(9, .bold)).tracking(1).foregroundStyle(WL.muted)
                }
            }
            if field.multiline {
                TextEditor(text: binding)
                    .font(WL.mono(11)).foregroundStyle(WL.text).tint(WL.accent)
                    .scrollContentBackground(.hidden).autocorrectionDisabled()
                    .frame(minHeight: field == .iconSubjects ? 132 : 80)
                    .padding(8).wlPanel(fill: WL.surface, border: WL.border)
            } else {
                TextField("", text: binding, axis: .vertical)
                    .font(WL.mono(11)).foregroundStyle(WL.text).tint(WL.accent)
                    .autocorrectionDisabled()
                    .padding(10).wlPanel(fill: WL.surface, border: WL.border)
            }
            if let tokens = field.tokens {
                Text("tokens: \(tokens)").font(WL.mono(9)).foregroundStyle(WL.muted)
            }
        }
    }
}
