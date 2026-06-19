import Foundation

/// Every editable prompt + injected value the on-device models use, in one place. Each case
/// maps to a UserDefaults key with a built-in default: generation reads `.value`, the Prompt
/// Lab edits it. Blank override → the default is used.
enum PromptField: String, CaseIterable, Identifiable {
    // Icon (image)
    case iconTemplate = "fmn.iconPrompt"
    case iconDefaultStyle = "fmn.iconDefaultStyle"
    case iconSubjects = "fmn.iconSubjects"
    case moodCalm = "fmn.moodCalm"
    case moodSoon = "fmn.moodSoon"
    case moodDue = "fmn.moodDue"
    case moodOverdue = "fmn.moodOverdue"
    // Nudge (speech bubble)
    case nudgeInstructions = "fmn.nudgeInstructions"
    case nudgeTemplate = "fmn.nudgeTemplate"
    case toneCalm = "fmn.toneCalm"
    case toneOverdue = "fmn.toneOverdue"
    case toneBad = "fmn.toneBad"
    case toneFrantic = "fmn.toneFrantic"
    // Insight
    case insightTaskInstructions = "fmn.insightTaskInstructions"
    case insightOverviewInstructions = "fmn.insightOverviewInstructions"

    var id: String { rawValue }

    enum Group: String, CaseIterable { case icon = "ICON IMAGE", nudge = "NUDGE", insight = "INSIGHT" }
    var group: Group {
        switch self {
        case .iconTemplate, .iconDefaultStyle, .iconSubjects, .moodCalm, .moodSoon, .moodDue, .moodOverdue: .icon
        case .nudgeInstructions, .nudgeTemplate, .toneCalm, .toneOverdue, .toneBad, .toneFrantic: .nudge
        case .insightTaskInstructions, .insightOverviewInstructions: .insight
        }
    }

    var label: String {
        switch self {
        case .iconTemplate: "Image prompt"
        case .iconDefaultStyle: "Default style (used when Icon Style is blank)"
        case .iconSubjects: "Subjects — one per line, picked at random for {animal}"
        case .moodCalm: "Mood · on track"
        case .moodSoon: "Mood · due soon"
        case .moodDue: "Mood · overdue"
        case .moodOverdue: "Mood · way overdue"
        case .nudgeInstructions: "System instructions"
        case .nudgeTemplate: "Per-nudge prompt"
        case .toneCalm: "Tone · on track"
        case .toneOverdue: "Tone · overdue"
        case .toneBad: "Tone · badly overdue"
        case .toneFrantic: "Tone · frantic"
        case .insightTaskInstructions: "Per-loop instructions"
        case .insightOverviewInstructions: "Overview instructions"
        }
    }

    /// Tokens that get substituted with live data at generation time, if any.
    var tokens: String? {
        switch self {
        case .iconTemplate: "{style} {animal} {task} {details} {mood}"
        case .nudgeTemplate: "{task} {detail} {area} {tone} {voice}"
        default: nil
        }
    }

    var multiline: Bool {
        switch self {
        case .iconTemplate, .iconSubjects, .nudgeInstructions, .nudgeTemplate,
             .insightTaskInstructions, .insightOverviewInstructions: true
        default: false
        }
    }

    var def: String {
        switch self {
        case .iconTemplate:
            "a {style} {animal}, the icon for \"{task}\" ({details}), {mood}, friendly icon, plain solid background"
        case .iconDefaultStyle: "cute funny cartoon alien"
        case .iconSubjects:
            ["axolotl", "tardigrade", "octopus", "newt", "sloth", "platypus", "narwhal",
             "chameleon", "pangolin", "capybara", "jellyfish", "blobfish", "sea slug", "frog", "moth"]
                .joined(separator: "\n")
        case .moodCalm: "calm, happy and content"
        case .moodSoon: "a little restless and impatient"
        case .moodDue: "stressed, wide-eyed and frazzled"
        case .moodOverdue: "completely unhinged, feral and falling apart"
        case .nudgeInstructions:
            "You coach someone to start a task they keep avoiding. The block is the decision, not the doing. Reply with ONE short sentence naming the smallest concrete first physical action. No preamble, no emoji, no quotes. Match the requested urgency exactly."
        case .nudgeTemplate:
            "Task: {task}.{detail}{area} {tone}{voice} Give the nudge."
        case .toneCalm: "Tone: calm, encouraging. Max 14 words."
        case .toneOverdue: "It is overdue. Tone: urgent and direct. Max 12 words."
        case .toneBad: "Badly overdue. Tone: insistent, a little frantic. Max 9 words."
        case .toneFrantic: "Extremely overdue. Tone: FRANTIC, near ALL-CAPS, like an alarm. Max 7 words."
        case .insightTaskInstructions:
            "You analyze a single recurring habit (\"loop\"). Be specific and kind, never preachy. Summary is one sentence. Observations are 2-3 terse fragments. Suggestion is one concrete next step."
        case .insightOverviewInstructions:
            "You analyze a set of recurring habits (\"loops\") as a whole — balance across areas, what's slipping, momentum. Summary is one sentence. Observations are 2-3 terse fragments. Suggestion is one concrete next step."
        }
    }

    /// The effective text — the saved override if non-blank, otherwise the default.
    var value: String {
        guard let raw = UserDefaults.standard.string(forKey: rawValue),
              !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return def }
        return raw
    }

    func set(_ s: String) { UserDefaults.standard.set(s, forKey: rawValue) }
    func reset() { UserDefaults.standard.removeObject(forKey: rawValue) }
}
