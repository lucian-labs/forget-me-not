import Foundation

/// A trend read — either for one task or across all of them.
struct InsightResult: Sendable, Equatable {
    var summary: String
    var observations: [String]
    var suggestion: String
}

protocol InsightService: Sendable {
    func insight(for task: TaskDTO) async -> InsightResult
    func overview(_ tasks: [TaskDTO]) async -> InsightResult
}

/// Non-AI fallbacks (also used as the FM degraded path). Pure computation over the data.
enum Insight {
    static func fallback(for task: TaskDTO, now: Date = Date()) -> InsightResult {
        let resets = task.actionLog.filter { $0.action == .reset }.count
        let lapses = task.actionLog.filter { $0.action == .lapsed }.count
        let pct = Int(Urgency.ratio(task, now: now) * 100)
        var obs = ["\(resets) completion\(resets == 1 ? "" : "s") logged", "\(pct)% through the current cycle"]
        if lapses > 0 { obs.append("\(lapses) lapse\(lapses == 1 ? "" : "s") — it slipped past 2× before") }
        return InsightResult(
            summary: resets == 0 ? "Fresh loop — no history yet." : "You've kept this loop going \(resets)×.",
            observations: obs,
            suggestion: pct >= 80 ? "It's due — knock it out now." : "On track; nothing needed yet."
        )
    }

    static func fallback(overview tasks: [TaskDTO], now: Date = Date()) -> InsightResult {
        let overdue = tasks.filter { Urgency.ratio($0, now: now) >= 1 }.count
        let domains = Set(tasks.map { $0.domain.isEmpty ? "—" : $0.domain }).sorted()
        return InsightResult(
            summary: "\(tasks.count) active loops, \(overdue) overdue.",
            observations: ["Domains: \(domains.joined(separator: ", "))",
                           overdue == 0 ? "Everything's within its window." : "\(overdue) need attention now."],
            suggestion: overdue > 0 ? "Start with the reddest meter." : "Keep the rhythm."
        )
    }
}

struct StaticInsightService: InsightService {
    func insight(for task: TaskDTO) async -> InsightResult { Insight.fallback(for: task) }
    func overview(_ tasks: [TaskDTO]) async -> InsightResult { Insight.fallback(overview: tasks) }
}

/// On-device Foundation Models insights when available (iOS 26 + Apple Intelligence),
/// else the computed fallback.
enum Insights {
    static func service() -> any InsightService {
        if #available(iOS 26.0, *) { return FoundationModelsInsightService() }
        return StaticInsightService()
    }
}
