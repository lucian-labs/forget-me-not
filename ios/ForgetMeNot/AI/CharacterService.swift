import Foundation
import CoreGraphics

/// Generates a task's mascot — a cartoon alien animal whose mood reflects how overdue
/// the task is. Swappable: today it's on-device Image Playground; later a model trained
/// on Elijah's own drawings can drop in behind this protocol.
protocol CharacterService: Sendable {
    var available: Bool { get }
    func generate(prompt: String) async -> CGImage?
}

struct UnavailableCharacterService: CharacterService {
    var available: Bool { false }
    func generate(prompt: String) async -> CGImage? { nil }
}

enum Characters {
    /// Weird little creatures → "cartoon alien animals" read well.
    static let animals = [
        "axolotl", "tardigrade", "octopus", "newt", "sloth", "platypus", "narwhal",
        "chameleon", "pangolin", "capybara", "jellyfish", "blobfish", "sea slug", "frog", "moth",
    ]

    static func randomAnimal() -> String { animals.randomElement() ?? "axolotl" }

    /// The "state of mind if you don't do it for too long."
    static func mood(for tier: UrgencyTier) -> String {
        switch tier {
        case .calm: "calm, happy and content"
        case .soon: "a little restless and impatient"
        case .due: "stressed, wide-eyed and frazzled"
        case .overdue: "completely unhinged, feral and falling apart"
        }
    }

    /// Custom style string from Settings (woven into every mascot prompt).
    static var style: String {
        (UserDefaults.standard.string(forKey: "fmn.mascotStyle") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    static let defaultStyle = "cute funny cartoon alien"

    /// The editable scaffold every mascot prompt is built from. Edit it in Settings to play
    /// with the art style; tokens are filled per task at generation time:
    /// {style} (Mascot Style), {animal}, {task}, {details}, {mood} (calmer/feral by overdue).
    static let defaultPromptTemplate =
        "a {style} {animal}, the mascot for \"{task}\" ({details}), {mood}, friendly character, plain solid background"

    /// The current template — the Settings override if set, otherwise the default.
    static var promptTemplate: String {
        let o = UserDefaults.standard.string(forKey: "fmn.mascotPrompt")?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (o?.isEmpty == false) ? o! : defaultPromptTemplate
    }

    static func prompt(animal: String, task: TaskDTO) -> String {
        let mood = mood(for: Urgency.tier(for: Urgency.ratio(task)))
        let look = style.isEmpty ? defaultStyle : style
        let details = task.description.trimmingCharacters(in: .whitespacesAndNewlines)
        return promptTemplate
            .replacingOccurrences(of: "{style}", with: look)
            .replacingOccurrences(of: "{animal}", with: animal)
            .replacingOccurrences(of: "{task}", with: task.title)
            .replacingOccurrences(of: "{details}", with: details)
            .replacingOccurrences(of: "{mood}", with: mood)
            .replacingOccurrences(of: " ()", with: "")   // details was empty
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    static func service() -> any CharacterService {
        if #available(iOS 26.0, *) { return ImagePlaygroundCharacterService() }
        return UnavailableCharacterService()
    }
}
