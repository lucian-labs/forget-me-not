import SwiftUI

/// Create a new task — waveloop-styled form (square controls, mono uppercase labels).
/// Recurring tasks start a fresh instance immediately, mirroring web createTask.
struct CreateTaskView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var domain = ""
    @State private var details = ""
    @State private var recurring = true
    @State private var amount = 1
    @State private var unit: Unit = .hour
    @State private var prompts: [String] = []
    @State private var newPrompt = ""

    enum Unit: String, CaseIterable, Identifiable {
        case min = "MIN", hour = "HR", day = "DAY"
        var id: String { rawValue }
        var seconds: Double { switch self { case .min: 60; case .hour: 3600; case .day: 86400 } }
    }

    private var canSave: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        ZStack {
            WL.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        Text("NEW TASK").font(WL.mono(15, .bold)).tracking(3).foregroundStyle(WL.text)
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark").font(.system(size: 15, weight: .bold)).foregroundStyle(WL.muted)
                        }
                    }

                    field("TITLE") { textField("what to remember", $title) }
                    field("DOMAIN") { textField("home / work / health", $domain) }
                    field("DETAILS") { textField("optional — what is this? (flavors the mascot)", $details) }

                    field("TYPE") {
                        HStack(spacing: 8) {
                            segment("RECURRING", on: recurring) { recurring = true }
                            segment("ONE-TIME", on: !recurring) { recurring = false }
                        }
                    }

                    if recurring {
                        field("EVERY") {
                            HStack(spacing: 10) {
                                stepperButton("minus") { amount = max(1, amount - 1) }
                                Text("\(amount)").font(WL.mono(18, .bold)).foregroundStyle(WL.text)
                                    .frame(minWidth: 36)
                                stepperButton("plus") { amount += 1 }
                                Spacer(minLength: 12)
                                ForEach(Unit.allCases) { u in
                                    segment(u.rawValue, on: unit == u) { unit = u }
                                }
                            }
                        }
                    }

                    field("PROMPTS") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(prompts, id: \.self) { p in
                                HStack {
                                    Text("· \(p)").font(WL.mono(12)).foregroundStyle(WL.muted)
                                    Spacer()
                                    Button { prompts.removeAll { $0 == p } } label: {
                                        Image(systemName: "xmark").font(.system(size: 10)).foregroundStyle(WL.muted)
                                    }
                                }
                            }
                            HStack(spacing: 8) {
                                textField("add a nudge prompt", $newPrompt)
                                Button {
                                    let t = newPrompt.trimmingCharacters(in: .whitespaces)
                                    guard !t.isEmpty else { return }
                                    prompts.append(t); newPrompt = ""
                                } label: {
                                    Image(systemName: "plus").font(.system(size: 14, weight: .bold)).foregroundStyle(WL.bg)
                                        .frame(width: 40, height: 40).background(WL.accent)
                                }
                            }
                        }
                    }

                    Button {
                        store.create(makeTask()); dismiss()
                    } label: {
                        Text("CREATE").font(WL.mono(14, .bold)).tracking(2)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .foregroundStyle(canSave ? WL.bg : WL.muted)
                            .background(canSave ? WL.accent : WL.surface)
                            .overlay(Rectangle().stroke(WL.border, lineWidth: 1))
                    }
                    .disabled(!canSave)
                }
                .padding(20)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func makeTask() -> TaskDTO {
        let now = Date()
        let cadence: Double? = recurring ? Double(amount) * unit.seconds : nil
        return TaskDTO(
            id: UUID().uuidString, title: title.trimmingCharacters(in: .whitespaces),
            description: details.trimmingCharacters(in: .whitespaces),
            domain: domain.trimmingCharacters(in: .whitespaces), tags: [], status: .open, priority: .normal,
            createdAt: now, updatedAt: now, dueDate: nil, startedAt: nil, completedAt: nil, estimatedHours: nil,
            recurring: recurring, baseCadenceSeconds: cadence, cadenceMore: nil, cadenceLess: nil,
            instance: (recurring && cadence != nil) ? ReminderInstanceDTO(startedAt: now, actualCadenceSeconds: cadence!, snoozed: false) : nil,
            followUps: [], parentTaskId: nil, prompts: prompts, soundSeed: nil, actionLog: []
        )
    }

    // MARK: components

    @ViewBuilder private func field<C: View>(_ label: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(WL.mono(10, .bold)).tracking(2).foregroundStyle(WL.muted)
            content()
        }
    }

    private func textField(_ placeholder: String, _ text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .font(WL.mono(14)).foregroundStyle(WL.text).tint(WL.accent)
            .padding(12).wlPanel(fill: WL.surface, border: WL.border)
    }

    private func segment(_ label: String, on: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).font(WL.mono(11, .bold)).tracking(1)
                .padding(.horizontal, 12).padding(.vertical, 10)
                .foregroundStyle(on ? WL.bg : WL.muted)
                .background(on ? WL.accent : WL.surface)
                .overlay(Rectangle().stroke(WL.border, lineWidth: 1))
        }
    }

    private func stepperButton(_ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 13, weight: .bold)).foregroundStyle(WL.accent)
                .frame(width: 36, height: 36).overlay(Rectangle().stroke(WL.border, lineWidth: 1))
        }
    }
}
