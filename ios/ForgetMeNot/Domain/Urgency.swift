import Foundation

enum UrgencyTier: Equatable { case calm, soon, due, overdue }

enum Urgency {
    /// Fraction of the current cycle elapsed (0 = fresh, >=1 = overdue).
    static func ratio(_ t: TaskDTO, now: Date = Date()) -> Double {
        if t.recurring, let inst = t.instance, inst.actualCadenceSeconds > 0 {
            return now.timeIntervalSince(inst.startedAt) / inst.actualCadenceSeconds
        }
        if let due = t.dueDate, let start = t.startedAt {
            let total = due.timeIntervalSince(start)
            guard total > 0 else { return 1 }
            return now.timeIntervalSince(start) / total
        }
        return 0
    }

    static func remainingSeconds(_ t: TaskDTO, now: Date = Date()) -> Double {
        if t.recurring, let inst = t.instance {
            return inst.startedAt.addingTimeInterval(inst.actualCadenceSeconds).timeIntervalSince(now)
        }
        if let due = t.dueDate { return due.timeIntervalSince(now) }
        return .infinity
    }

    static func tier(for ratio: Double) -> UrgencyTier {
        // Web parity (getUrgencyColor): green <0.75, orange <0.95, red >=0.95; overdue >=1.0.
        switch ratio {
        case ..<0.75: .calm
        case ..<0.95: .soon
        case ..<1.0: .due
        default: .overdue
        }
    }
}
