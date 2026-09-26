import Foundation

/// A proleptic Gregorian civil date. It has no time zone or time of day.
public struct CivilDate: Hashable, Comparable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) throws {
        guard (1...9999).contains(year), (1...12).contains(month) else {
            throw DomainValidationError.invalidCivilDate
        }
        let daysInMonth: Int
        switch month {
        case 2:
            daysInMonth = Self.isLeapYear(year) ? 29 : 28
        case 4, 6, 9, 11:
            daysInMonth = 30
        default:
            daysInMonth = 31
        }
        guard (1...daysInMonth).contains(day) else {
            throw DomainValidationError.invalidCivilDate
        }
        self.year = year
        self.month = month
        self.day = day
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    public static func isLeapYear(_ year: Int) -> Bool {
        year.isMultiple(of: 4) && (!year.isMultiple(of: 100) || year.isMultiple(of: 400))
    }

    /// Days since 1970-01-01. The range is small enough to fit safely in Int64.
    public var daysSinceUnixEpoch: Int64 {
        let adjustedYear = year - (month <= 2 ? 1 : 0)
        let era = adjustedYear / 400
        let yearOfEra = adjustedYear - era * 400
        let adjustedMonth = month + (month > 2 ? -3 : 9)
        let dayOfYear = (153 * adjustedMonth + 2) / 5 + day - 1
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        return Int64(era * 146_097 + dayOfEra - 719_468)
    }

    public init(daysSinceUnixEpoch days: Int64) throws {
        // Bound before converting to Int or multiplying the Gregorian era.
        guard (-719_162...2_932_896).contains(days) else {
            throw DomainValidationError.invalidCivilDate
        }
        let shifted = days.addingReportingOverflow(719_468)
        guard !shifted.overflow else { throw DomainValidationError.invalidCivilDate }
        let era = shifted.partialValue >= 0
            ? shifted.partialValue / 146_097
            : (shifted.partialValue - 146_096) / 146_097
        let dayOfEra = Int(shifted.partialValue - era * 146_097)
        let yearOfEra = (dayOfEra - dayOfEra / 1_460 + dayOfEra / 36_524 - dayOfEra / 146_096) / 365
        var year = Int(era) * 400 + yearOfEra
        let dayOfYear = dayOfEra - (365 * yearOfEra + yearOfEra / 4 - yearOfEra / 100)
        let monthPrime = (5 * dayOfYear + 2) / 153
        let day = dayOfYear - (153 * monthPrime + 2) / 5 + 1
        let month = monthPrime + (monthPrime < 10 ? 3 : -9)
        year += month <= 2 ? 1 : 0
        try self.init(year: year, month: month, day: day)
    }

    public func adding(days: Int) throws -> Self {
        let sum = daysSinceUnixEpoch.addingReportingOverflow(Int64(days))
        guard !sum.overflow else { throw DomainValidationError.invalidCivilDate }
        return try Self(daysSinceUnixEpoch: sum.partialValue)
    }

    public var isoWeekday: Int {
        let weekday = (daysSinceUnixEpoch + 3) % 7
        return Int((weekday + 7) % 7) + 1 // Monday = 1, Sunday = 7
    }

    public func addingMonths(_ months: Int, preservingDay: Bool = true) throws -> Self? {
        let total = (year - 1).multipliedReportingOverflow(by: 12)
        guard !total.overflow else { throw DomainValidationError.arithmeticOverflow }
        let base = total.partialValue.addingReportingOverflow(month - 1)
        guard !base.overflow else { throw DomainValidationError.arithmeticOverflow }
        let target = base.partialValue.addingReportingOverflow(months)
        guard !target.overflow else { throw DomainValidationError.arithmeticOverflow }
        guard (0..<(9999 * 12)).contains(target.partialValue) else { return nil }
        let targetYear = target.partialValue / 12 + 1
        let targetMonth = target.partialValue % 12 + 1
        let daysInTarget = Self.isLeapYear(targetYear) && targetMonth == 2
            ? 29
            : ([4, 6, 9, 11].contains(targetMonth) ? 30 : (targetMonth == 2 ? 28 : 31))
        guard day <= daysInTarget else { return nil }
        return try Self(year: targetYear, month: targetMonth, day: preservingDay ? day : min(day, daysInTarget))
    }
}

public struct CivilDateRange: Hashable, Sendable {
    public let start: CivilDate
    public let endExclusive: CivilDate

    public init(start: CivilDate, endExclusive: CivilDate) throws {
        guard start < endExclusive else { throw DomainValidationError.invalidRange }
        self.start = start
        self.endExclusive = endExclusive
    }

    public func overlaps(_ other: Self) -> Bool {
        start < other.endExclusive && endExclusive > other.start
    }

    public func contains(_ date: CivilDate) -> Bool {
        start <= date && date < endExclusive
    }

    public var dayCount: Int64 { endExclusive.daysSinceUnixEpoch - start.daysSinceUnixEpoch }
}
