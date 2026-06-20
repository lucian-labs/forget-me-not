import Foundation

enum TaskMapper {
    static func entity(from d: TaskDTO) -> TaskEntity {
        let e = TaskEntity(id: d.id, title: d.title)
        e.taskDescription = d.description
        e.domain = d.domain
        e.tags = d.tags
        e.statusRaw = d.status.rawValue
        e.priorityRaw = d.priority.rawValue
        e.createdAt = d.createdAt
        e.updatedAt = d.updatedAt
        e.dueDate = d.dueDate
        e.startedAt = d.startedAt
        e.completedAt = d.completedAt
        e.estimatedHours = d.estimatedHours
        e.recurring = d.recurring
        e.baseCadenceSeconds = d.baseCadenceSeconds
        e.cadenceMore = d.cadenceMore
        e.cadenceLess = d.cadenceLess
        e.instanceStartedAt = d.instance?.startedAt
        e.instanceActualCadenceSeconds = d.instance?.actualCadenceSeconds
        e.instanceSnoozed = d.instance?.snoozed ?? false
        e.followUps = d.followUps
        e.parentTaskId = d.parentTaskId
        e.prompts = d.prompts
        e.soundSeed = d.soundSeed
        e.actionLog = d.actionLog
        e.iconImageData = d.iconImageData
        e.iconSymbol = d.iconSymbol
        return e
    }

    static func dto(from e: TaskEntity) -> TaskDTO {
        let instance: ReminderInstanceDTO? = {
            guard let s = e.instanceStartedAt, let c = e.instanceActualCadenceSeconds else { return nil }
            return ReminderInstanceDTO(startedAt: s, actualCadenceSeconds: c, snoozed: e.instanceSnoozed)
        }()
        return TaskDTO(
            id: e.id, title: e.title, description: e.taskDescription, domain: e.domain,
            tags: e.tags,
            status: TaskStatus(rawValue: e.statusRaw) ?? .open,
            priority: TaskPriority(rawValue: e.priorityRaw) ?? .normal,
            createdAt: e.createdAt, updatedAt: e.updatedAt,
            dueDate: e.dueDate, startedAt: e.startedAt, completedAt: e.completedAt,
            estimatedHours: e.estimatedHours, recurring: e.recurring,
            baseCadenceSeconds: e.baseCadenceSeconds, cadenceMore: e.cadenceMore, cadenceLess: e.cadenceLess,
            instance: instance, followUps: e.followUps, parentTaskId: e.parentTaskId,
            prompts: e.prompts, soundSeed: e.soundSeed, actionLog: e.actionLog,
            iconSymbol: e.iconSymbol, iconImageData: e.iconImageData
        )
    }

    /// Apply DTO fields onto an existing entity (for updates).
    static func apply(_ d: TaskDTO, to e: TaskEntity) {
        let fresh = entity(from: d)
        e.title = fresh.title; e.taskDescription = fresh.taskDescription; e.domain = fresh.domain
        e.tags = fresh.tags; e.statusRaw = fresh.statusRaw; e.priorityRaw = fresh.priorityRaw
        e.createdAt = fresh.createdAt; e.updatedAt = fresh.updatedAt
        e.dueDate = fresh.dueDate; e.startedAt = fresh.startedAt; e.completedAt = fresh.completedAt
        e.estimatedHours = fresh.estimatedHours; e.recurring = fresh.recurring
        e.baseCadenceSeconds = fresh.baseCadenceSeconds; e.cadenceMore = fresh.cadenceMore; e.cadenceLess = fresh.cadenceLess
        e.instanceStartedAt = fresh.instanceStartedAt; e.instanceActualCadenceSeconds = fresh.instanceActualCadenceSeconds; e.instanceSnoozed = fresh.instanceSnoozed
        e.followUps = fresh.followUps; e.parentTaskId = fresh.parentTaskId
        e.prompts = fresh.prompts; e.soundSeed = fresh.soundSeed; e.actionLog = fresh.actionLog
        e.iconImageData = fresh.iconImageData; e.iconSymbol = fresh.iconSymbol
    }
}
