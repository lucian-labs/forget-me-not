import Foundation
import FoundationModels

/// Structured insight produced by the on-device model.
@available(iOS 26.0, *)
@Generable
struct GeneratedInsight {
    @Guide(description: "One concise sentence on how things are going")
    var summary: String
    @Guide(description: "Two or three very short observations or patterns")
    var observations: [String]
    @Guide(description: "One concrete, encouraging next step")
    var suggestion: String
}

@available(iOS 26.0, *)
struct FoundationModelsInsightService: InsightService {
    func insight(for task: TaskDTO) async -> InsightResult {
        await generate(
            instructions: PromptField.insightTaskInstructions.value,
            prompt: taskPrompt(task),
            fallback: Insight.fallback(for: task)
        )
    }

    func overview(_ tasks: [TaskDTO]) async -> InsightResult {
        await generate(
            instructions: PromptField.insightOverviewInstructions.value,
            prompt: overviewPrompt(tasks),
            fallback: Insight.fallback(overview: tasks)
        )
    }

    private func generate(instructions: String, prompt: String, fallback: InsightResult) async -> InsightResult {
        guard case .available = SystemLanguageModel.default.availability else { return fallback }
        do {
            let session = LanguageModelSession { instructions }
            let g = try await session.respond(to: prompt, generating: GeneratedInsight.self).content
            return InsightResult(summary: g.summary, observations: g.observations, suggestion: g.suggestion)
        } catch {
            return fallback
        }
    }

    private func taskPrompt(_ t: TaskDTO) -> String {
        let resets = t.actionLog.filter { $0.action == .reset }.count
        let lapses = t.actionLog.filter { $0.action == .lapsed }.count
        let pct = Int(Urgency.ratio(t) * 100)
        return """
        Loop: \(t.title).\(t.description.isEmpty ? "" : " Detail: \(t.description).") Area: \(t.domain.isEmpty ? "general" : t.domain).
        Cadence: every \(Format.duration(t.baseCadenceSeconds ?? 0)).
        Completions: \(resets). Lapses: \(lapses). Currently \(pct)% through the cycle.
        Give the analysis.
        """
    }

    private func overviewPrompt(_ tasks: [TaskDTO]) -> String {
        let lines = tasks.prefix(20).map { t in
            "- \(t.title) [\(t.domain.isEmpty ? "general" : t.domain)] \(Int(Urgency.ratio(t) * 100))% every \(Format.duration(t.baseCadenceSeconds ?? 0))"
        }.joined(separator: "\n")
        return "Here are the active loops:\n\(lines)\nGive the overall analysis."
    }
}

/// Tiny duration humanizer for prompts.
enum Format {
    static func duration(_ seconds: Double) -> String {
        let s = Int(seconds)
        if s % 86400 == 0 && s >= 86400 { let d = s / 86400; return "\(d) day\(d == 1 ? "" : "s")" }
        if s % 3600 == 0 && s >= 3600 { let h = s / 3600; return "\(h) hour\(h == 1 ? "" : "s")" }
        if s >= 60 { return "\(s / 60) min" }
        return "\(s)s"
    }
}
