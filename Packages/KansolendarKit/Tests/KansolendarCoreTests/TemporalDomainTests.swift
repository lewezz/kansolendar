import Foundation
import KansolendarCore
import Testing

@Suite("Temporal domain values")
struct TemporalDomainTests {
    @Test("validates Gregorian leap days and round trips epoch-day values")
    func gregorianDates() throws {
        let leapDay = try CivilDate(year: 2000, month: 2, day: 29)
        #expect(throws: DomainValidationError.invalidCivilDate) {
            try CivilDate(year: 1900, month: 2, day: 29)
        }
        #expect(throws: DomainValidationError.invalidCivilDate) {
            try CivilDate(year: 2026, month: 2, day: 30)
        }
        #expect(try CivilDate(daysSinceUnixEpoch: leapDay.daysSinceUnixEpoch) == leapDay)
        #expect(try CivilDate(year: 1969, month: 12, day: 31).daysSinceUnixEpoch == -1)
        #expect(throws: DomainValidationError.invalidCivilDate) {
            try CivilDate(daysSinceUnixEpoch: Int64.max)
        }
        let minimum = try CivilDate(year: 1, month: 1, day: 1)
        let maximum = try CivilDate(year: 9999, month: 12, day: 31)
        #expect(try CivilDate(daysSinceUnixEpoch: minimum.daysSinceUnixEpoch) == minimum)
        #expect(try CivilDate(daysSinceUnixEpoch: maximum.daysSinceUnixEpoch) == maximum)
    }

    @Test("uses ISO weekdays and checked date arithmetic")
    func weekdayAndArithmetic() throws {
        let epoch = try CivilDate(year: 1970, month: 1, day: 1)
        #expect(epoch.isoWeekday == 4)
        #expect(try epoch.adding(days: -1) == CivilDate(year: 1969, month: 12, day: 31))
        #expect(throws: DomainValidationError.invalidCivilDate) {
            try CivilDate(year: 9999, month: 12, day: 31).adding(days: 1)
        }
    }

    @Test("rejects empty ranges and applies half-open boundaries")
    func halfOpenRanges() throws {
        let start = Instant(unixSeconds: 10)
        let end = Instant(unixSeconds: 20)
        let range = try InstantRange(start: start, endExclusive: end)
        #expect(range.contains(start))
        #expect(!range.contains(end))
        #expect(!range.overlaps(try InstantRange(start: end, endExclusive: Instant(unixSeconds: 30))))
        #expect(throws: DomainValidationError.invalidRange) {
            try InstantRange(start: end, endExclusive: start)
        }
    }

    @Test("resolves explicit DST folds and rejects gaps")
    func daylightSavingResolution() throws {
        let resolver = FoundationLocalTimeResolver()
        let madrid = try TimeZoneID("Europe/Madrid")
        let gap = try LocalDateTime(date: CivilDate(year: 2026, month: 3, day: 29), hour: 2, minute: 30)
        #expect(throws: DomainValidationError.nonexistentLocalTime) {
            try resolver.resolve(gap, in: madrid, repeatedTime: nil)
        }

        let fold = try LocalDateTime(date: CivilDate(year: 2026, month: 10, day: 25), hour: 2, minute: 30)
        #expect(throws: DomainValidationError.ambiguousLocalTime) {
            try resolver.resolve(fold, in: madrid, repeatedTime: nil)
        }
        let first = try resolver.resolve(fold, in: madrid, repeatedTime: .first)
        let last = try resolver.resolve(fold, in: madrid, repeatedTime: .last)
        #expect(last.unixSeconds - first.unixSeconds == 3_600)
    }

    @Test("requires an explicit recognized time zone")
    func timeZoneValidation() throws {
        #expect(try TimeZoneID("Europe/Madrid").identifier == "Europe/Madrid")
        #expect(throws: DomainValidationError.invalidTimeZoneIdentifier) {
            try TimeZoneID("Not/A_Real_Zone")
        }
    }
}
