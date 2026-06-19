import Foundation

/// The exact text sent to the on-device models — shared so the UI can show it verbatim
/// (Settings styles + task description flow in here).
enum Prompts {
    /// The current nudge system instructions (editable in the Prompt Lab).
    static var nudgeInstructions: String { PromptField.nudgeInstructions.value }

    /// Tone string for a given urgency intensity (each tier editable in the Prompt Lab).
    static func tone(for intensity: Int) -> String {
        switch intensity {
        case 0: PromptField.toneCalm.value
        case 1...2: PromptField.toneOverdue.value
        case 3...5: PromptField.toneBad.value
        default: PromptField.toneFrantic.value
        }
    }

    /// The per-call nudge prompt, built from the editable template. Tokens: {task} {detail}
    /// {area} {tone} {voice} — detail/area/voice expand to "" when empty.
    static func nudge(for task: TaskDTO, intensity: Int) -> String {
        let detail = task.description.isEmpty ? "" : " Detail: \(task.description)."
        let area = task.domain.isEmpty ? "" : " Area: \(task.domain)."
        let voice = (UserDefaults.standard.string(forKey: "fmn.nudgeStyle") ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let persona = voice.isEmpty ? "" : " Write it as: \(voice)."
        return PromptField.nudgeTemplate.value
            .replacingOccurrences(of: "{task}", with: task.title)
            .replacingOccurrences(of: "{detail}", with: detail)
            .replacingOccurrences(of: "{area}", with: area)
            .replacingOccurrences(of: "{tone}", with: tone(for: intensity))
            .replacingOccurrences(of: "{voice}", with: persona)
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespaces)
    }
}
