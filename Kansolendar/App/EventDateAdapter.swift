import Foundation
import KansolendarCore

/// Converts Foundation dates at the editor boundary; domain event types remain UI-independent.
enum EventDateAdapter {
    static func startDate(for event: Event) -> Date {
        switch event.time {
        case let .allDay(value):
            return foundationDate(value.range.start) ?? .distantPast
        case let .utc(value):
            return Date(timeIntervalSince1970: TimeInterval(value.start.unixSeconds))
        case let .zoned(value):
            return Date(timeIntervalSince1970: TimeInterval(value.resolvedStart.unixSeconds))
        }
    }

    static func endDate(for event: Event) -> Date {
        switch event.time {
        case let .allDay(value):
            // Preserve the exclusive end date; multi-day events must not gain or lose a day.
            return foundationDate(value.range.endExclusive) ?? startDate(for: event)
        case let .utc(value):
            return Date(timeIntervalSince1970: TimeInterval(value.endExclusive.unixSeconds))
        case let .zoned(value):
            return Date(timeIntervalSince1970: TimeInterval(value.endExclusive.unixSeconds))
        }
    }

    static func isAllDay(_ event: Event) -> Bool {
        if case .allDay = event.time { return true }
        return false
    }

    static func eventTime(start: Date, end: Date, isAllDay: Bool) throws -> EventTime {
        guard end > start else { throw DomainValidationError.invalidRange }
        if isAllDay {
            let calendar = Calendar.autoupdatingCurrent
            let startParts = calendar.dateComponents([.year, .month, .day], from: start)
            let endParts = calendar.dateComponents([.year, .month, .day], from: end)
            return .allDay(try AllDayEventTime(
                start: civilDate(from: startParts),
                endExclusive: civilDate(from: endParts)
            ))
        }
        let foundationZone = TimeZone.autoupdatingCurrent
        let zoneID = try TimeZoneID(
            TimeZone.knownTimeZoneIdentifiers.contains(foundationZone.identifier)
                ? foundationZone.identifier
                : "UTC"
        )
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = foundationZone
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: start)
        guard let hour = parts.hour, let minute = parts.minute else {
            throw DomainValidationError.invalidCivilDate
        }
        let duration = Int64(end.timeIntervalSince(start).rounded(.towardZero))
        let localStart = try LocalDateTime(
            date: civilDate(from: parts),
            hour: hour,
            minute: minute,
            second: parts.second ?? 0
        )
        return .zoned(try ZonedEventTime(
            localStart: localStart,
            timeZone: zoneID,
            repeatedTime: .first, // Preserve the editor's policy for repeated DST wall times.
            durationSeconds: duration,
            resolver: FoundationLocalTimeResolver()
        ))
    }

    private static func foundationDate(_ date: CivilDate) -> Date? {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.year = date.year
        components.month = date.month
        components.day = date.day
        return components.date
    }

    private static func civilDate(from components: DateComponents) throws -> CivilDate {
        guard let year = components.year, let month = components.month, let day = components.day else {
            throw DomainValidationError.invalidCivilDate
        }
        return try CivilDate(year: year, month: month, day: day)
    }
}
