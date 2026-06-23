import SwiftUI
import Charts

/// A dedicated data view for all loops — timeline + breakdown charts, plus the on-device
/// overview. Waveloop-styled.
struct LoopsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var overview: InsightResult?
    private let insights = Insights.service()

    var body: some View {
        ZStack {
            WL.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    section("URGENCY — WHERE EACH LOOP STANDS") { urgencyChart }
                    section("ACTIVITY — LAST 14 DAYS") { activityChart }
                    section("BY AREA") { areaChart }
                    if let overview { overviewBlock(overview) }
                }
                .padding(20)
            }
        }
        .preferredColorScheme(.dark)
        .task { overview = await insights.overview(store.sortedActive) }
    }

    private var header: some View {
        HStack {
            Text("ALL LOOPS").font(WL.mono(17, .bold)).tracking(3).foregroundStyle(WL.text)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 15, weight: .bold)).foregroundStyle(WL.muted)
            }
        }
    }

    // MARK: charts

    private var urgencyChart: some View {
        Chart(urgencyData) { item in
            BarMark(
                x: .value("Percent", item.pct),
                y: .value("Loop", item.title)
            )
            .foregroundStyle(item.color)
            .annotation(position: .trailing, alignment: .leading) {
                Text("\(Int(item.pct))%").font(WL.mono(8)).foregroundStyle(WL.muted)
            }
        }
        .chartXScale(domain: 0...200)
        .chartXAxis { axisStyle }
        .chartYAxis { axisStyle }
        .frame(height: max(120, CGFloat(urgencyData.count) * 26))
    }

    private var activityChart: some View {
        Chart(activityData, id: \.date) { item in
            BarMark(
                x: .value("Day", item.date, unit: .day),
                y: .value("Done", item.count)
            )
            .foregroundStyle(WL.accent)
        }
        .chartXAxis { axisStyle }
        .chartYAxis { axisStyle }
        .frame(height: 150)
        .overlay {
            if activityData.allSatisfy({ $0.count == 0 }) {
                Text("no completions logged yet").font(WL.mono(10)).foregroundStyle(WL.muted)
            }
        }
    }

    private var areaChart: some View {
        Chart(areaData, id: \.area) { item in
            BarMark(
                x: .value("Area", item.area),
                y: .value("Loops", item.count)
            )
            .foregroundStyle(WL.cyan)
        }
        .chartXAxis { axisStyle }
        .chartYAxis { axisStyle }
        .frame(height: 150)
    }

    private func overviewBlock(_ r: InsightResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("READ").font(WL.mono(10, .bold)).tracking(2).foregroundStyle(WL.muted)
            Text(r.summary).font(WL.mono(14, .semibold)).foregroundStyle(WL.text)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(r.observations, id: \.self) { o in
                HStack(alignment: .top, spacing: 8) {
                    Text("·").font(WL.mono(13, .bold)).foregroundStyle(WL.accent)
                    Text(o).font(WL.mono(13)).foregroundStyle(WL.muted).fixedSize(horizontal: false, vertical: true)
                }
            }
            HStack(alignment: .top, spacing: 8) {
                Text("▸").font(WL.mono(13, .bold)).foregroundStyle(WL.accent)
                Text(r.suggestion).font(WL.mono(13)).foregroundStyle(WL.cyan).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(WL.mono(10, .bold)).tracking(2).foregroundStyle(WL.muted)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .wlPanel(fill: WL.surface, border: WL.border)
    }

    private var axisStyle: some AxisContent {
        AxisMarks {
            AxisGridLine().foregroundStyle(WL.line.opacity(0.4))
            AxisTick().foregroundStyle(WL.line)
            AxisValueLabel().foregroundStyle(WL.muted).font(WL.mono(8))
        }
    }

    // MARK: data

    private struct LoopUrgency: Identifiable { let id: String; let title: String; let pct: Double; let color: Color }

    private var urgencyData: [LoopUrgency] {
        store.sortedActive.prefix(12).map { t in
            let r = Urgency.ratio(t)
            return LoopUrgency(id: t.id, title: t.title.capitalized,
                               pct: min(r, 2) * 100, color: WL.urgencyColor(Urgency.tier(for: r)))
        }
    }

    private var activityData: [(date: Date, count: Int)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var counts: [Date: Int] = [:]
        for t in store.tasks {
            for e in t.actionLog where e.action == .reset || e.action == .complete || e.action == .lapsed {
                counts[cal.startOfDay(for: e.at), default: 0] += 1
            }
        }
        return (0..<14).reversed().compactMap { offset in
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return (date: day, count: counts[day] ?? 0)
        }
    }

    private var areaData: [(area: String, count: Int)] {
        Dictionary(grouping: store.sortedActive, by: { $0.domain.isEmpty ? "—" : $0.domain.uppercased() })
            .map { (area: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
    }
}
