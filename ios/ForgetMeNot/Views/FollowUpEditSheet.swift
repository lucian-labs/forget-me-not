import SwiftUI

/// Configure one follow-up chain step — title, when it's due after the previous step, and a
/// description that drives its icon. Waveloop-styled, presented from the task detail.
struct FollowUpEditSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let taskId: String
    let index: Int
    @State private var title: String
    @State private var details: String
    @State private var cadence: Double

    init(taskId: String, index: Int, fu: FollowUpDTO) {
        self.taskId = taskId
        self.index = index
        _title = State(initialValue: fu.title)
        _details = State(initialValue: fu.details ?? "")
        _cadence = State(initialValue: fu.cadenceSeconds)
    }

    private var canSave: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        ZStack {
            WL.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        Text("STEP \(index + 1)").font(WL.mono(15, .bold)).tracking(3).foregroundStyle(WL.text)
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark").font(.system(size: 15, weight: .bold)).foregroundStyle(WL.muted)
                        }
                    }

                    field("TITLE") { textField("what to do", $title) }

                    field("DUE WITHIN") {
                        Menu {
                            ForEach(CadenceOptions.all, id: \.value) { opt in
                                Button(opt.label) { cadence = opt.value }
                            }
                        } label: {
                            HStack {
                                Text(CadenceOptions.label(cadence)).font(WL.mono(13, .bold)).foregroundStyle(WL.text)
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down").font(.system(size: 11)).foregroundStyle(WL.muted)
                            }
                            .padding(12).wlPanel(fill: WL.surface, border: WL.border)
                        }
                    }

                    field("DETAILS") { textField("what is this? (drives the icon)", $details) }

                    Button { save() } label: {
                        Text("SAVE").font(WL.mono(14, .bold)).tracking(2)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .foregroundStyle(canSave ? WL.bg : WL.muted)
                            .background(canSave ? WL.accent : WL.surface)
                            .overlay(Rectangle().stroke(WL.border, lineWidth: 1))
                    }
                    .disabled(!canSave)

                    Button(role: .destructive) {
                        store.removeFollowUp(id: taskId, at: index); dismiss()
                    } label: {
                        Text("REMOVE STEP").font(WL.mono(11, .bold)).tracking(2)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .foregroundStyle(WL.red).overlay(Rectangle().stroke(WL.red.opacity(0.5), lineWidth: 1))
                    }
                }
                .padding(20)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func save() {
        store.updateFollowUp(id: taskId, at: index, title: title, cadenceSeconds: cadence, details: details)
        dismiss()
    }

    @ViewBuilder private func field<C: View>(_ label: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(WL.mono(10, .bold)).tracking(2).foregroundStyle(WL.muted)
            content()
        }
    }

    private func textField(_ placeholder: String, _ text: Binding<String>) -> some View {
        TextField(placeholder, text: text, axis: .vertical)
            .font(WL.mono(14)).foregroundStyle(WL.text).tint(WL.accent)
            .lineLimit(1...4)
            .padding(12).wlPanel(fill: WL.surface, border: WL.border)
    }
}
