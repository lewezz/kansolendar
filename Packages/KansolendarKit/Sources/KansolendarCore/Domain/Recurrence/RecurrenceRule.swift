import Foundation

public enum RecurrenceFrequency: String, Hashable, Sendable, Codable {
    case daily, weekly, monthly, yearly
}

public enum RecurrenceWeekday: Int, CaseIterable, Hashable, Sendable, Codable, Comparable {
    case monday = 1, tuesday, wednesday, thursday, friday, saturday, sunday

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

public enum RecurrenceEnd: Hashable, Sendable {
    case never
    case count(Int)
    case untilCivilDate(CivilDate)
    case untilInstant(Instant)
}

public struct RecurrenceRule: Hashable, Sendable {
    public let frequency: RecurrenceFrequency
    public let interval: Int
    public let weekdays: [RecurrenceWeekday]
    public let end: RecurrenceEnd

    public init(
        frequency: RecurrenceFrequency,
        interval: Int = 1,
        weekdays: [RecurrenceWeekday] = [],
        end: RecurrenceEnd = .never
    ) throws {
        guard (1...999).contains(interval), Set(weekdays).count == weekdays.count else {
            throw DomainValidationError.invalidRecurrence
        }
        guard frequency == .weekly || weekdays.isEmpty else {
            throw DomainValidationError.invalidRecurrence
        }
        if case let .count(count) = end, !(1...100_000).contains(count) {
            throw DomainValidationError.invalidRecurrence
        }
        self.frequency = frequency
        self.interval = interval
        self.weekdays = weekdays.sorted()
        self.end = end
    }
}

public struct RecurringSeries: Hashable, Sendable {
    public let event: Event
    public let rule: RecurrenceRule
    public let cancellations: Set<EventOccurrenceKey>

    public init(event: Event, rule: RecurrenceRule, cancellations: Set<EventOccurrenceKey> = []) throws {
        let anchor = Self.anchor(of: event.time)
        guard !cancellations.contains(where: { $0.eventID != event.id || !$0.originalStart.matches(kindOf: anchor) }) else {
            throw DomainValidationError.invalidRecurrence
        }
        if Self.isAllDay(event.time) {
            if case .untilInstant = rule.end { throw DomainValidationError.invalidRecurrence }
        } else if case .untilCivilDate = rule.end {
            throw DomainValidationError.invalidRecurrence
        }
        if rule.frequency == .weekly {
            let startWeekday = try Self.isoWeekday(of: anchor)
            let weekdays = rule.weekdays.map(\.rawValue)
            guard weekdays.isEmpty || weekdays.contains(startWeekday) else {
                throw DomainValidationError.invalidRecurrence
            }
        }
        if case let .zoned(time) = event.time, time.repeatedTime == .last {
            throw DomainValidationError.invalidRecurrence
        }
        self.event = event
        self.rule = rule
        self.cancellations = cancellations
    }

    private static func isAllDay(_ time: EventTime) -> Bool {
        if case .allDay = time { return true }
        return false
    }

    private static func anchor(of time: EventTime) -> EventStart {
        switch time {
        case let .allDay(value): .civil(value.range.start)
        case let .utc(value): .instant(value.start)
        case let .zoned(value): .zoned(value.localStart, value.timeZone)
        }
    }

    private static func isoWeekday(of start: EventStart) throws -> Int {
        switch start {
        case let .civil(date): date.isoWeekday
        case let .instant(instant): try UTCComponents.date(from: instant).isoWeekday
        case let .zoned(local, _): local.date.isoWeekday
        }
    }
}

private struct UTCComponents {
    let date: CivilDate
    let hour: Int
    let minute: Int
    let second: Int

    init(_ local: LocalDateTime) {
        date = local.date
        hour = local.hour
        minute = local.minute
        second = local.second
    }

    static func date(from instant: Instant) throws -> CivilDate {
        var day = instant.unixSeconds / 86_400
        if instant.unixSeconds % 86_400 < 0 { day -= 1 }
        return try CivilDate(daysSinceUnixEpoch: day)
    }
}
