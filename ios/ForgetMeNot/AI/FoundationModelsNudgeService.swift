import Foundation
import FoundationModels

/// On-device nudge generation via Apple's Foundation Models. Falls back to a static
/// prompt only if the system model reports unavailable or generation errors.
@available(iOS 26.0, *)
struct FoundationModelsNudgeService: NudgeService {
    func nudge(for task: TaskDTO, intensity: Int) async -> String {
        guard case .available = SystemLanguageModel.default.availability else {
            return StaticNudge.text(for: task, intensity: intensity)
        }
        do {
            let session = LanguageModelSession { Prompts.nudgeInstructions }
            let text = try await session.respond(to: Prompts.nudge(for: task, intensity: intensity))
                .content.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? StaticNudge.text(for: task, intensity: intensity) : text
        } catch {
            return StaticNudge.text(for: task, intensity: intensity)
        }
    }
}
