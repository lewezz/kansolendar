import Foundation

public struct TimeZoneID: Hashable, Sendable {
    public let identifier: String

    public init(_ identifier: String) throws {
        guard let zone = TimeZone(identifier: identifier),
              TimeZone.knownTimeZoneIdentifiers.contains(zone.identifier) else {
            throw DomainValidationError.invalidTimeZoneIdentifier
        }
        self.identifier = zone.identifier
    }

    public func resolveFoundationTimeZone() throws -> TimeZone {
        guard let zone = TimeZone(identifier: identifier) else {
            throw DomainValidationError.invalidTimeZoneIdentifier
        }
        return zone
    }
}

public struct LocalDateTime: Hashable, Comparable, Sendable {
    public let date: CivilDate
    public let hour: Int
    public let minute: Int
    public let second: Int

    public init(date: CivilDate, hour: Int, minute: Int, second: Int = 0) throws {
        guard (0...23).contains(hour), (0...59).contains(minute), (0...59).contains(second) else {
            throw DomainValidationError.invalidTimeComponent
        }
        self.date = date
        self.hour = hour
        self.minute = minute
        self.second = second
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.date != rhs.date { return lhs.date < rhs.date }
        return (lhs.hour, lhs.minute, lhs.second) < (rhs.hour, rhs.minute, rhs.second)
    }
}

public enum RepeatedTimeChoice: String, Hashable, Sendable, Codable {
    case first
    case last
}

public protocol LocalTimeResolving: Sendable {
    func resolve(_ local: LocalDateTime, in timeZone: TimeZoneID, repeatedTime: RepeatedTimeChoice?) throws -> Instant
}

/// Foundation-backed resolver using strict matching; gaps are rejected rather than shifted.
public struct FoundationLocalTimeResolver: LocalTimeResolving {
    public init() {}

    public func resolve(_ local: LocalDateTime, in timeZoneID: TimeZoneID, repeatedTime: RepeatedTimeChoice? = nil) throws -> Instant {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try timeZoneID.resolveFoundationTimeZone()
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4

        let components = DateComponents(
            year: local.date.year,
            month: local.date.month,
            day: local.date.day,
            hour: local.hour,
            minute: local.minute,
            second: local.second
        )
        let dayStartComponents = DateComponents(year: local.date.year, month: local.date.month, day: local.date.day)
        guard let dayStart = calendar.date(from: dayStartComponents) else {
            throw DomainValidationError.nonexistentLocalTime
        }
        let searchStart = dayStart.addingTimeInterval(-1)
        let repeated: Calendar.RepeatedTimePolicy
        switch repeatedTime {
        case .first: repeated = .first
        case .last: repeated = .last
        case nil: repeated = .first
        }
        guard let result = calendar.nextDate(
            after: searchStart,
            matching: components,
            matchingPolicy: .strict,
            repeatedTimePolicy: repeated,
            direction: .forward
        ) else {
            throw DomainValidationError.nonexistentLocalTime
        }

        let actual = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: result)
        guard actual.year == local.date.year,
              actual.month == local.date.month,
              actual.day == local.date.day,
              actual.hour == local.hour,
              actual.minute == local.minute,
              actual.second == local.second else {
            throw DomainValidationError.nonexistentLocalTime
        }

        // If the caller omitted a fold choice, detect whether the wall time occurs twice.
        if repeatedTime == nil {
            let alternate = calendar.nextDate(
                after: result.addingTimeInterval(1),
                matching: components,
                matchingPolicy: .strict,
                repeatedTimePolicy: .last,
                direction: .forward
            )
            if let alternate {
                let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: alternate)
                if parts.year == local.date.year, parts.month == local.date.month, parts.day == local.date.day,
                   parts.hour == local.hour, parts.minute == local.minute, parts.second == local.second {
                    throw DomainValidationError.ambiguousLocalTime
                }
            }
        }

        let seconds = result.timeIntervalSince1970
        guard seconds.isFinite, seconds >= Double(Int64.min), seconds < Double(Int64.max) else {
            throw DomainValidationError.arithmeticOverflow
        }
        return Instant(unixSeconds: Int64(seconds.rounded(.towardZero)))
    }
}
