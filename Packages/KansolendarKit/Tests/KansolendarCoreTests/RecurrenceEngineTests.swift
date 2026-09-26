import Foundation
import KansolendarCore
import Testing

@Suite("Recurrence engine")
struct RecurrenceEngineTests {
    @Test("daily recurrence counts DTSTART and applies cancellations by original date")
    func dailyCountAndCancellation() throws {
        let calendarID = UUID()
        let event = try Event(
            calendarID: calendarID,
            title: "Daily",
            time: .allDay(try AllDayEventTime(
                start: CivilDate(year: 2026, month: 1, day: 1),
                endExclusive: CivilDate(year: 2026, month: 1, day: 2)
            ))
        )
        let cancelled = EventOccurrenceKey(eventID: event.id, originalStart: .civil(try CivilDate(year: 2026, month: 1, day: 2)))
        let rule = try RecurrenceRule(frequency: .daily, end: .count(4))
        let series = try RecurringSeries(event: event, rule: rule, cancellations: [cancelled])
        let query = try EventTimeRange.civil(CivilDateRange(
            start: CivilDate(year: 2026, month: 1, day: 1),
            endExclusive: CivilDate(year: 2026, month: 1, day: 8)
        ))
        let result = try RecurrenceEngine().expand(series, in: query)
        #expect(result.count == 3)
        let expected: [EventStart] = [
            .civil(try CivilDate(year: 2026, month: 1, day: 1)),
            .civil(try CivilDate(year: 2026, month: 1, day: 3)),
            .civil(try CivilDate(year: 2026, month: 1, day: 4))
        ]
        #expect(result.map(\.key.originalStart) == expected)
    }

    @Test("weekly recurrence applies weekdays and interval from the DTSTART week")
    func weeklyDays() throws {
        let start = try CivilDate(year: 2026, month: 9, day: 23) // Wednesday
        let event = try allDayEvent(start: start)
        let rule = try RecurrenceRule(frequency: .weekly, weekdays: [.wednesday, .friday], end: .count(4))
        let series = try RecurringSeries(event: event, rule: rule)
        let result = try RecurrenceEngine().expand(series, in: .civil(try CivilDateRange(
            start: start,
            endExclusive: CivilDate(year: 2026, month: 10, day: 10)
        )))
        let expected: [EventStart] = [
            .civil(try CivilDate(year: 2026, month: 9, day: 23)),
            .civil(try CivilDate(year: 2026, month: 9, day: 25)),
            .civil(try CivilDate(year: 2026, month: 9, day: 30)),
            .civil(try CivilDate(year: 2026, month: 10, day: 2))
        ]
        #expect(result.map(\.key.originalStart) == expected)
    }

    @Test("weekly interval skips whole ISO weeks without shifting weekdays")
    func weeklyInterval() throws {
        let start = try CivilDate(year: 2026, month: 9, day: 23)
        let series = try RecurringSeries(
            event: allDayEvent(start: start),
            rule: RecurrenceRule(frequency: .weekly, interval: 2, weekdays: [.wednesday, .friday], end: .count(4))
        )
        let results = try RecurrenceEngine().expand(series, in: .civil(try CivilDateRange(
            start: start,
            endExclusive: CivilDate(year: 2026, month: 10, day: 20)
        )))
        let expected: [EventStart] = [
            .civil(try CivilDate(year: 2026, month: 9, day: 23)),
            .civil(try CivilDate(year: 2026, month: 9, day: 25)),
            .civil(try CivilDate(year: 2026, month: 10, day: 7)),
            .civil(try CivilDate(year: 2026, month: 10, day: 9))
        ]
        #expect(results.map(\.key.originalStart) == expected)
    }

    @Test("monthly day 31 and yearly leap day skip invalid calendar dates")
    func skipsInvalidCalendarCandidates() throws {
        let jan31 = try CivilDate(year: 2026, month: 1, day: 31)
        let monthly = try RecurringSeries(
            event: allDayEvent(start: jan31),
            rule: RecurrenceRule(frequency: .monthly, end: .count(4))
        )
        let monthlyResult = try RecurrenceEngine().expand(monthly, in: .civil(try CivilDateRange(
            start: jan31,
            endExclusive: CivilDate(year: 2026, month: 8, day: 1)
        )))
        let expectedMonthly: [EventStart] = [
            .civil(try CivilDate(year: 2026, month: 1, day: 31)),
            .civil(try CivilDate(year: 2026, month: 3, day: 31)),
            .civil(try CivilDate(year: 2026, month: 5, day: 31)),
            .civil(try CivilDate(year: 2026, month: 7, day: 31))
        ]
        #expect(monthlyResult.map(\.key.originalStart) == expectedMonthly)

        let leapDay = try CivilDate(year: 2024, month: 2, day: 29)
        let yearly = try RecurringSeries(
            event: allDayEvent(start: leapDay),
            rule: RecurrenceRule(frequency: .yearly, end: .count(2))
        )
        let firstLeapResult = try RecurrenceEngine().expand(yearly, in: .civil(try CivilDateRange(
            start: leapDay,
            endExclusive: CivilDate(year: 2025, month: 1, day: 1)
        )))
        let secondLeapResult = try RecurrenceEngine().expand(yearly, in: .civil(try CivilDateRange(
            start: CivilDate(year: 2028, month: 2, day: 29),
            endExclusive: CivilDate(year: 2029, month: 3, day: 1)
        )))
        let secondLeapDay = try CivilDate(year: 2028, month: 2, day: 29)
        #expect(firstLeapResult.map(\.key.originalStart) == [.civil(leapDay)])
        #expect(secondLeapResult.map(\.key.originalStart) == [.civil(secondLeapDay)])
    }

    @Test("zoned daily recurrence keeps wall time and omits a DST gap")
    func zonedDSTGap() throws {
        let zone = try TimeZoneID("Europe/Madrid")
        let local = try LocalDateTime(date: CivilDate(year: 2026, month: 3, day: 28), hour: 2, minute: 30)
        let time = try ZonedEventTime(
            localStart: local,
            timeZone: zone,
            repeatedTime: .first,
            durationSeconds: 1_800,
            resolver: FoundationLocalTimeResolver()
        )
        let event = try Event(calendarID: UUID(), title: "Early", time: .zoned(time))
        let series = try RecurringSeries(event: event, rule: RecurrenceRule(frequency: .daily, end: .count(3)))
        let query = try InstantRange(
            start: Instant(unixSeconds: time.resolvedStart.unixSeconds - 3_600),
            endExclusive: Instant(unixSeconds: time.resolvedStart.unixSeconds + 4 * 86_400)
        )
        let result = try RecurrenceEngine().expand(series, in: .instant(query))
        #expect(result.count == 3)
        #expect(result.compactMap { if case let .zoned(value) = $0.time { value.localStart.date.day } else { nil } } == [28, 30, 31])
        #expect(result.compactMap { if case let .zoned(value) = $0.time { value.localStart.hour } else { nil } } == [2, 2, 2])
    }

    @Test("rejects excessive ranges and never returns partial results on budget exhaustion")
    func recurrenceBudgets() throws {
        let start = try CivilDate(year: 2026, month: 1, day: 1)
        let series = try RecurringSeries(event: allDayEvent(start: start), rule: RecurrenceRule(frequency: .daily))
        let longQuery = try EventTimeRange.civil(CivilDateRange(
            start: start,
            endExclusive: CivilDate(year: 2028, month: 1, day: 1)
        ))
        #expect(throws: DomainValidationError.queryLimitExceeded) {
            try RecurrenceEngine().expand(series, in: longQuery)
        }

        let shortQuery = try EventTimeRange.civil(CivilDateRange(
            start: start,
            endExclusive: CivilDate(year: 2026, month: 1, day: 6)
        ))
        let smallBudget = try RecurrenceBudget(maximumQueryDays: 10, maximumCandidates: 2, maximumOccurrences: 10)
        #expect(throws: DomainValidationError.candidateLimitExceeded) {
            try RecurrenceEngine().expand(series, in: shortQuery, budget: smallBudget)
        }

        let outputBudget = try RecurrenceBudget(maximumQueryDays: 10, maximumCandidates: 10, maximumOccurrences: 1)
        #expect(throws: DomainValidationError.occurrenceLimitExceeded) {
            try RecurrenceEngine().expand(series, in: shortQuery, budget: outputBudget)
        }

        let oneOccurrenceSeries = try RecurringSeries(
            event: allDayEvent(start: start),
            rule: RecurrenceRule(frequency: .daily, end: .count(1))
        )
        let exactBudget = try RecurrenceBudget(maximumQueryDays: 10, maximumCandidates: 1, maximumOccurrences: 1)
        let exactBudgetResult = try RecurrenceEngine().expand(oneOccurrenceSeries, in: shortQuery, budget: exactBudget)
        #expect(exactBudgetResult.count == 1)
    }

    @Test("UNTIL is inclusive and an earlier event can overlap the query")
    func untilAndOverlap() throws {
        let start = try CivilDate(year: 2026, month: 6, day: 1)
        let event = try Event(
            calendarID: UUID(),
            title: "Two days",
            time: .allDay(try AllDayEventTime(start: start, endExclusive: start.adding(days: 2)))
        )
        let series = try RecurringSeries(
            event: event,
            rule: RecurrenceRule(frequency: .daily, end: .untilCivilDate(CivilDate(year: 2026, month: 6, day: 3)))
        )
        let overlapQuery = try CivilDateRange(
            start: CivilDate(year: 2026, month: 6, day: 2),
            endExclusive: CivilDate(year: 2026, month: 6, day: 4)
        )
        let occurrences = try RecurrenceEngine().expand(series, in: .civil(overlapQuery))
        let secondDay = try CivilDate(year: 2026, month: 6, day: 2)
        let thirdDay = try CivilDate(year: 2026, month: 6, day: 3)
        #expect(occurrences.map(\.key.originalStart) == [
            .civil(start),
            .civil(secondDay),
            .civil(thirdDay)
        ])
    }

    @Test("rejects incompatible recurrence rules and query kinds")
    func rejectsInvalidRuleAndQuery() throws {
        #expect(throws: DomainValidationError.invalidRecurrence) {
            try RecurrenceRule(frequency: .daily, weekdays: [.monday])
        }
        #expect(throws: DomainValidationError.invalidRecurrence) {
            try RecurrenceRule(frequency: .weekly, end: .count(0))
        }
        #expect(throws: DomainValidationError.invalidRecurrence) {
            try RecurrenceBudget(maximumQueryDays: 367)
        }
        let event = try allDayEvent(start: CivilDate(year: 2026, month: 1, day: 1))
        let series = try RecurringSeries(event: event, rule: RecurrenceRule(frequency: .daily))
        #expect(throws: DomainValidationError.incompatibleQuery) {
            try RecurrenceEngine().expand(series, in: .instant(InstantRange(
                start: Instant(unixSeconds: 0), endExclusive: Instant(unixSeconds: 86_400)
            )))
        }
    }

    private func allDayEvent(start: CivilDate) throws -> Event {
        try Event(
            calendarID: UUID(),
            title: "Series",
            time: .allDay(try AllDayEventTime(start: start, endExclusive: start.adding(days: 1)))
        )
    }
}
