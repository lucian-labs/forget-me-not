import SwiftUI

/// Presents an on-device generated nudge for a task — a concrete first action to
/// get unstuck. Regenerate for a fresh angle.
struct NudgeSheet: View {
    let task: TaskDTO
    @Environment(\.dismiss) private var dismiss

    @State private var nudge: String?
    @State private var loading = true
    private let service = Nudges.service()

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "sparkles")
                .font(.largeTitle)
                .foregroundStyle(.tint)
            Text(task.title)
                .font(.headline)
                .foregroundStyle(.secondary)

            if loading {
                ProgressView().controlSize(.large)
            } else {
                Text(nudge ?? "")
                    .font(.title2.weight(.medium))
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }

            Spacer()

            Button {
                Task { await generate() }
            } label: {
                Label("Another nudge", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(loading)

            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
        }
        .padding(28)
        .task { await generate() }
    }

    @MainActor
    private func generate() async {
        withAnimation { loading = true }
        let result = await service.nudge(for: task)
        withAnimation { nudge = result; loading = false }
    }
}
