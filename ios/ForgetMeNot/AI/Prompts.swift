import Foundation

/// The exact text sent to the on-device models — shared so the UI can show it verbatim
/// (Settings styles + task description flow in here).
enum Prompts {
    /// System instructions for nudge generation.
    static let nudgeInstructions = """
    You coach someone to start a task they keep avoiding. The block is the decision, not \
    the doing. Reply with ONE short sentence naming the smallest concrete first physical \
    action. No preamble, no emoji, no quotes. Match the requested urgency exactly.
    """

    /// The per-call nudge prompt (incorporates description, urgency intensity, and the
    /// "Prompt style" voice from Settings).
    static func nudge(for task: TaskDTO, intensity: Int) -> String {
        var parts = ["Task: \(task.title)."]
        if !task.description.isEmpty { parts.append("Detail: \(task.description).") }
        if !task.domain.isEmpty { parts.append("Area: \(task.domain).") }
        let tone: String
        switch intensity {
        case 0: tone = "Tone: calm, encouraging. Max 14 words."
        case 1...2: tone = "It is overdue. Tone: urgent and direct. Max 12 words."
        case 3...5: tone = "Badly overdue. Tone: insistent, a little frantic. Max 9 words."
        default: tone = "Extremely overdue. Tone: FRANTIC, near ALL-CAPS, like an alarm. Max 7 words."
        }
        let voice = (UserDefaults.standard.string(forKey: "fmn.nudgeStyle") ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let persona = voice.isEmpty ? "" : " Write it as: \(voice)."
        return parts.joined(separator: " ") + " " + tone + persona + " Give the nudge."
    }
}
