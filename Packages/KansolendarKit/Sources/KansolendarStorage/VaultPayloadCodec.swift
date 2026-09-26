import Foundation
import KansolendarCore

internal enum VaultPayloadCodecError: Error, Equatable, Sendable {
    case unsupportedVersion(Int)
    case invalidPayload
    case timeZoneRulesChanged
}

public struct VaultEvent: Sendable, Equatable {
    public let event: Event
    public let recurrence: RecurrenceRule?
    public let cancellations: Set<EventOccurrenceKey>

    public init(event: Event, recurrence: RecurrenceRule?, cancellations: Set<EventOccurrenceKey> = []) {
        self.event = event
        self.recurrence = recurrence
        self.cancellations = cancellations
    }
}

/// Encodes versioned domain payloads before the caller encrypts them. These bytes
/// must never be persisted or logged outside an authenticated envelope.
internal enum VaultPayloadCodec {
    private static let currentVersion = 1
    private static let maximumPayloadSize = 131_072

    static func encode(_ calendar: LocalCalendar) throws -> Data {
        try encode(CalendarPayload(
            version: currentVersion,
            name: calendar.name,
            color: calendar.color.rawValue,
            sortOrder: calendar.sortOrder,
            defaultTimeZoneID: calendar.defaultTimeZone.identifier
        ))
    }

    static func decodeCalendar(_ data: Data, id: UUID) throws -> LocalCalendar {
        let payload = try decode(CalendarPayload.self, from: data)
        guard payload.version == currentVersion else {
            throw VaultPayloadCodecError.unsupportedVersion(payload.version)
        }
        guard let color = CalendarColor(rawValue: payload.color) else {
            throw VaultPayloadCodecError.invalidPayload
        }
        do {
            return try LocalCalendar(
                id: id,
                name: payload.name,
                color: color,
                sortOrder: payload.sortOrder,
                defaultTimeZone: TimeZoneID(payload.defaultTimeZoneID)
            )
        } catch {
            throw VaultPayloadCodecError.invalidPayload
        }
    }

    static func encode(_ event: Event, recurrence: RecurrenceRule? = nil) throws -> Data {
        try encode(EventPayload(
            version: currentVersion,
            uid: event.uid,
            title: event.title,
            notes: event.notes,
            location: event.location,
            time: StoredEventTime(event.time),
            revision: event.revision,
            recurrence: recurrence.map(StoredRecurrence.init)
        ))
    }

    static func encode(_ cancellation: EventCancellation) throws -> Data {
        try encode(CancellationPayload(version: currentVersion, originalStart: StoredEventStart(cancellation.key.originalStart)))
    }

    static func decodeCancellation(_ data: Data, eventID: UUID) throws -> EventCancellation {
        let payload = try decode(CancellationPayload.self, from: data)
        guard payload.version == currentVersion else {
            throw VaultPayloadCodecError.unsupportedVersion(payload.version)
        }
        return EventCancellation(key: EventOccurrenceKey(
            eventID: eventID,
            originalStart: try payload.originalStart.domainValue()
        ))
    }

    static func decodeEvent(
        _ data: Data,
        id: UUID,
        calendarID: UUID,
        cancellations: Set<EventOccurrenceKey> = []
    ) throws -> VaultEvent {
        let payload = try decode(EventPayload.self, from: data)
        guard payload.version == currentVersion else {
            throw VaultPayloadCodecError.unsupportedVersion(payload.version)
        }
        let time: EventTime
        do {
            time = try payload.time.domainValue()
        } catch let error as VaultPayloadCodecError {
            throw error
        } catch {
            throw VaultPayloadCodecError.invalidPayload
        }
        let recurrence = try payload.recurrence?.domainValue()
        do {
            let event = try Event(
                id: id,
                calendarID: calendarID,
                uid: payload.uid,
                title: payload.title,
                notes: payload.notes,
                location: payload.location,
                time: time,
                revision: payload.revision
            )
            if let recurrence {
                _ = try RecurringSeries(event: event, rule: recurrence, cancellations: cancellations)
            } else if !cancellations.isEmpty {
                throw VaultPayloadCodecError.invalidPayload
            }
            return VaultEvent(event: event, recurrence: recurrence, cancellations: cancellations)
        } catch {
            throw VaultPayloadCodecError.invalidPayload
        }
    }

    private static func encode<Value: Encodable>(_ value: Value) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data: Data
        do {
            data = try encoder.encode(value)
        } catch {
            throw VaultPayloadCodecError.invalidPayload
        }
        guard data.count <= maximumPayloadSize else { throw VaultPayloadCodecError.invalidPayload }
        return data
    }

    private static func decode<Value: Decodable>(_ type: Value.Type, from data: Data) throws -> Value {
        guard data.count <= maximumPayloadSize else { throw VaultPayloadCodecError.invalidPayload }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw VaultPayloadCodecError.invalidPayload
        }
    }
}

private struct CancellationPayload: Codable, Sendable {
    let version: Int
    let originalStart: StoredEventStart
}

private struct StoredEventStart: Codable, Sendable {
    let kind: String
    let civilDate: StoredDate?
    let unixSeconds: Int64?
    let localDateTime: StoredLocalDateTime?
    let timeZoneID: String?

    init(_ value: EventStart) {
        switch value {
        case let .civil(date):
            kind = "civil"
            civilDate = StoredDate(date)
            unixSeconds = nil
            localDateTime = nil
            timeZoneID = nil
        case let .instant(instant):
            kind = "instant"
            civilDate = nil
            unixSeconds = instant.unixSeconds
            localDateTime = nil
            timeZoneID = nil
        case let .zoned(local, zone):
            kind = "zoned"
            civilDate = nil
            unixSeconds = nil
            localDateTime = StoredLocalDateTime(local)
            timeZoneID = zone.identifier
        }
    }

    func domainValue() throws -> EventStart {
        switch kind {
        case "civil":
            guard let civilDate, unixSeconds == nil, localDateTime == nil, timeZoneID == nil else {
                throw VaultPayloadCodecError.invalidPayload
            }
            return .civil(try civilDate.domainValue())
        case "instant":
            guard let unixSeconds, civilDate == nil, localDateTime == nil, timeZoneID == nil else {
                throw VaultPayloadCodecError.invalidPayload
            }
            return .instant(Instant(unixSeconds: unixSeconds))
        case "zoned":
            guard let localDateTime, let timeZoneID,
                  civilDate == nil, unixSeconds == nil else {
                throw VaultPayloadCodecError.invalidPayload
            }
            return .zoned(try localDateTime.domainValue(), try TimeZoneID(timeZoneID))
        default:
            throw VaultPayloadCodecError.invalidPayload
        }
    }
}

private struct CalendarPayload: Codable, Sendable {
    let version: Int
    let name: String
    let color: String
    let sortOrder: Int
    let defaultTimeZoneID: String
}

private struct EventPayload: Codable, Sendable {
    let version: Int
    let uid: String
    let title: String
    let notes: String?
    let location: String?
    let time: StoredEventTime
    let revision: UInt64
    let recurrence: StoredRecurrence?
}

private struct StoredDate: Codable, Sendable {
    let year: Int
    let month: Int
    let day: Int

    init(_ value: CivilDate) {
        year = value.year
        month = value.month
        day = value.day
    }

    func domainValue() throws -> CivilDate {
        try CivilDate(year: year, month: month, day: day)
    }
}

private struct StoredLocalDateTime: Codable, Sendable {
    let date: StoredDate
    let hour: Int
    let minute: Int
    let second: Int

    init(_ value: LocalDateTime) {
        date = StoredDate(value.date)
        hour = value.hour
        minute = value.minute
        second = value.second
    }

    func domainValue() throws -> LocalDateTime {
        try LocalDateTime(date: date.domainValue(), hour: hour, minute: minute, second: second)
    }
}

private struct StoredEventTime: Codable, Sendable {
    let kind: String
    let startUnixSeconds: Int64?
    let durationSeconds: Int64?
    let startDate: StoredDate?
    let endDateExclusive: StoredDate?
    let localStart: StoredLocalDateTime?
    let timeZoneID: String?
    let resolvedStartUnixSeconds: Int64?
    let repeatedTime: String?

    init(_ value: EventTime) {
        switch value {
        case let .allDay(value):
            kind = "allDay"
            startUnixSeconds = nil
            durationSeconds = nil
            startDate = StoredDate(value.range.start)
            endDateExclusive = StoredDate(value.range.endExclusive)
            localStart = nil
            timeZoneID = nil
            resolvedStartUnixSeconds = nil
            repeatedTime = nil
        case let .utc(value):
            kind = "utc"
            startUnixSeconds = value.start.unixSeconds
            durationSeconds = value.durationSeconds
            startDate = nil
            endDateExclusive = nil
            localStart = nil
            timeZoneID = nil
            resolvedStartUnixSeconds = nil
            repeatedTime = nil
        case let .zoned(value):
            kind = "zoned"
            startUnixSeconds = nil
            durationSeconds = value.durationSeconds
            startDate = nil
            endDateExclusive = nil
            localStart = StoredLocalDateTime(value.localStart)
            timeZoneID = value.timeZone.identifier
            resolvedStartUnixSeconds = value.resolvedStart.unixSeconds
            repeatedTime = value.repeatedTime.rawValue
        }
    }

    func domainValue() throws -> EventTime {
        switch kind {
        case "allDay":
            guard let startDate, let endDateExclusive,
                  startUnixSeconds == nil, durationSeconds == nil, localStart == nil,
                  timeZoneID == nil, resolvedStartUnixSeconds == nil, repeatedTime == nil else {
                throw VaultPayloadCodecError.invalidPayload
            }
            return .allDay(try AllDayEventTime(
                start: startDate.domainValue(),
                endExclusive: endDateExclusive.domainValue()
            ))
        case "utc":
            guard let startUnixSeconds, let durationSeconds,
                  startDate == nil, endDateExclusive == nil, localStart == nil,
                  timeZoneID == nil, resolvedStartUnixSeconds == nil, repeatedTime == nil else {
                throw VaultPayloadCodecError.invalidPayload
            }
            return .utc(try TimedEventTime(start: Instant(unixSeconds: startUnixSeconds), durationSeconds: durationSeconds))
        case "zoned":
            guard let durationSeconds, let localStart, let timeZoneID,
                  let resolvedStartUnixSeconds, let repeatedTime,
                  let choice = RepeatedTimeChoice(rawValue: repeatedTime),
                  startUnixSeconds == nil, startDate == nil, endDateExclusive == nil else {
                throw VaultPayloadCodecError.invalidPayload
            }
            let timeZone = try TimeZoneID(timeZoneID)
            let value = try ZonedEventTime(
                localStart: localStart.domainValue(),
                timeZone: timeZone,
                repeatedTime: choice,
                durationSeconds: durationSeconds,
                resolver: FoundationLocalTimeResolver()
            )
            guard value.resolvedStart.unixSeconds == resolvedStartUnixSeconds else {
                throw VaultPayloadCodecError.timeZoneRulesChanged
            }
            return .zoned(value)
        default:
            throw VaultPayloadCodecError.invalidPayload
        }
    }
}

private struct StoredRecurrence: Codable, Sendable {
    let frequency: String
    let interval: Int
    let weekdays: [Int]
    let endKind: String
    let count: Int?
    let untilCivilDate: StoredDate?
    let untilUnixSeconds: Int64?

    init(_ value: RecurrenceRule) {
        frequency = value.frequency.rawValue
        interval = value.interval
        weekdays = value.weekdays.map(\.rawValue)
        switch value.end {
        case .never:
            endKind = "never"
            count = nil
            untilCivilDate = nil
            untilUnixSeconds = nil
        case let .count(value):
            endKind = "count"
            count = value
            untilCivilDate = nil
            untilUnixSeconds = nil
        case let .untilCivilDate(value):
            endKind = "untilCivilDate"
            count = nil
            untilCivilDate = StoredDate(value)
            untilUnixSeconds = nil
        case let .untilInstant(value):
            endKind = "untilInstant"
            count = nil
            untilCivilDate = nil
            untilUnixSeconds = value.unixSeconds
        }
    }

    func domainValue() throws -> RecurrenceRule {
        guard let frequency = RecurrenceFrequency(rawValue: frequency) else {
            throw VaultPayloadCodecError.invalidPayload
        }
        let days = try weekdays.map { rawValue -> RecurrenceWeekday in
            guard let weekday = RecurrenceWeekday(rawValue: rawValue) else {
                throw VaultPayloadCodecError.invalidPayload
            }
            return weekday
        }
        let end: RecurrenceEnd
        switch endKind {
        case "never":
            guard count == nil, untilCivilDate == nil, untilUnixSeconds == nil else {
                throw VaultPayloadCodecError.invalidPayload
            }
            end = .never
        case "count":
            guard let count, untilCivilDate == nil, untilUnixSeconds == nil else {
                throw VaultPayloadCodecError.invalidPayload
            }
            end = .count(count)
        case "untilCivilDate":
            guard let untilCivilDate, count == nil, untilUnixSeconds == nil else {
                throw VaultPayloadCodecError.invalidPayload
            }
            end = .untilCivilDate(try untilCivilDate.domainValue())
        case "untilInstant":
            guard let untilUnixSeconds, count == nil, untilCivilDate == nil else {
                throw VaultPayloadCodecError.invalidPayload
            }
            end = .untilInstant(Instant(unixSeconds: untilUnixSeconds))
        default:
            throw VaultPayloadCodecError.invalidPayload
        }
        do {
            return try RecurrenceRule(frequency: frequency, interval: interval, weekdays: days, end: end)
        } catch {
            throw VaultPayloadCodecError.invalidPayload
        }
    }
}
