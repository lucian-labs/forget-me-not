import SwiftUI

/// Waveloop-styled insight sheet. Loads an InsightResult on appear (per-task or global)
/// and renders it: summary, observations, suggestion.
struct InsightView: View {
    let title: String
    let load: () async -> InsightResult

    @Environment(\.dismiss) private var dismiss
    @State private var result: InsightResult?

    var body: some View {
        ZStack {
            WL.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 18) {
                Text(title.uppercased())
                    .font(WL.mono(12, .bold)).tracking(2).foregroundStyle(WL.muted)

                if let r = result {
                    Text(r.summary)
                        .font(WL.mono(17, .semibold)).foregroundStyle(WL.text)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(r.observations, id: \.self) { o in
                            HStack(alignment: .top, spacing: 8) {
                                Text("·").font(WL.mono(13, .bold)).foregroundStyle(WL.accent)
                                Text(o).font(WL.mono(13)).foregroundStyle(WL.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    HStack(alignment: .top, spacing: 8) {
                        Text("▸").font(WL.mono(13, .bold)).foregroundStyle(WL.accent)
                        Text(r.suggestion).font(WL.mono(13)).foregroundStyle(WL.cyan)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                } else {
                    Spacer()
                    HStack { Spacer(); ProgressView().tint(WL.accent); Spacer() }
                    Spacer()
                }

                Button { dismiss() } label: {
                    Text("CLOSE").font(WL.mono(13, .bold)).tracking(2)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                }
                .background(WL.surface)
                .overlay(Rectangle().stroke(WL.border, lineWidth: 1))
                .foregroundStyle(WL.text)
            }
            .padding(22)
        }
        .preferredColorScheme(.dark)
        .task { result = await load() }
    }
}
