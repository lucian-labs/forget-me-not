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

    /// Card meta text, web parity ("2h 13m left" / "1h 4m over"): compact, uppercase-ready.
    /// nil when the task has no clock (paused / no due date).
    static func clockLabel(_ t: TaskDTO, now: Date = Date()) -> String? {
        let r = remainingSeconds(t, now: now)
        guard r.isFinite else { return nil }
        let text = compactDuration(abs(r))
        return r >= 0 ? "\(text) LEFT" : "\(text) OVER"
    }

    static func compactDuration(_ seconds: Double) -> String {
        let s = max(0, Int(seconds))
        if s >= 86_400 { return "\(s / 86_400)D \((s % 86_400) / 3_600)H" }
        if s >= 3_600 { return "\(s / 3_600)H \((s % 3_600) / 60)M" }
        if s >= 60 { return "\(s / 60)M" }
        return "\(s)S"
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
