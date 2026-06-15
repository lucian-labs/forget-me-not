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

    static func prompt(animal: String, task: TaskDTO) -> String {
        let mood = mood(for: Urgency.tier(for: Urgency.ratio(task)))
        return "a cute funny cartoon alien \(animal), the mascot for \"\(task.title)\", \(mood), friendly character, plain solid background"
    }

    static func service() -> any CharacterService {
        if #available(iOS 26.0, *) { return ImagePlaygroundCharacterService() }
        return UnavailableCharacterService()
    }
}
