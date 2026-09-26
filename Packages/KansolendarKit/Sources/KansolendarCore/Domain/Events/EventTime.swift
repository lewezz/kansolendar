import Foundation

public struct AllDayEventTime: Hashable, Sendable {
    public let range: CivilDateRange

    public init(start: CivilDate, endExclusive: CivilDate) throws {
        self.range = try CivilDateRange(start: start, endExclusive: endExclusive)
    }

    public var durationInDays: Int64 { range.dayCount }
}

public struct TimedEventTime: Hashable, Sendable {
    public let start: Instant
    public let endExclusive: Instant
    public let durationSeconds: Int64

    public init(start: Instant, durationSeconds: Int64) throws {
        guard durationSeconds > 0 else { throw DomainValidationError.invalidDuration }
        let endExclusive = try start.adding(seconds: durationSeconds)
        self.start = start
        self.endExclusive = endExclusive
        self.durationSeconds = durationSeconds
    }

    public var range: InstantRange {
        // The constructor guarantees a positive duration and representable end.
        InstantRange(uncheckedStart: start, endExclusive: endExclusive)
    }
}

public struct ZonedEventTime: Hashable, Sendable {
    public let localStart: LocalDateTime
    public let timeZone: TimeZoneID
    public let resolvedStart: Instant
    public let endExclusive: Instant
    public let repeatedTime: RepeatedTimeChoice
    public let durationSeconds: Int64

    public init(
        localStart: LocalDateTime,
        timeZone: TimeZoneID,
        repeatedTime: RepeatedTimeChoice,
        durationSeconds: Int64,
        resolver: some LocalTimeResolving
    ) throws {
        guard durationSeconds > 0 else { throw DomainValidationError.invalidDuration }
        let resolvedStart = try resolver.resolve(localStart, in: timeZone, repeatedTime: repeatedTime)
        let endExclusive = try resolvedStart.adding(seconds: durationSeconds)
        self.localStart = localStart
        self.timeZone = timeZone
        self.resolvedStart = resolvedStart
        self.endExclusive = endExclusive
        self.repeatedTime = repeatedTime
        self.durationSeconds = durationSeconds
    }

    public var instantRange: InstantRange {
        InstantRange(uncheckedStart: resolvedStart, endExclusive: endExclusive)
    }
}

public enum EventTime: Hashable, Sendable {
    case allDay(AllDayEventTime)
    case utc(TimedEventTime)
    case zoned(ZonedEventTime)

    public var durationSeconds: Int64? {
        switch self {
        case .allDay: nil
        case let .utc(value): value.durationSeconds
        case let .zoned(value): value.durationSeconds
        }
    }
}

public enum EventTimeRange: Hashable, Sendable {
    case civil(CivilDateRange)
    case instant(InstantRange)
}

public enum EventStart: Hashable, Sendable {
    case civil(CivilDate)
    case instant(Instant)
    case zoned(LocalDateTime, TimeZoneID)
}

extension EventStart {
    func matches(kindOf anchor: Self) -> Bool {
        switch (self, anchor) {
        case (.civil, .civil), (.instant, .instant): true
        case let (.zoned(_, zone), .zoned(_, anchorZone)): zone == anchorZone
        default: false
        }
    }
}

public struct EventOccurrenceKey: Hashable, Sendable {
    public let eventID: UUID
    public let originalStart: EventStart

    public init(eventID: UUID, originalStart: EventStart) {
        self.eventID = eventID
        self.originalStart = originalStart
    }
}

public struct EventCancellation: Hashable, Sendable {
    public let key: EventOccurrenceKey

    public init(key: EventOccurrenceKey) {
        self.key = key
    }
}
