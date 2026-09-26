import Foundation

public struct RecurrenceBudget: Hashable, Sendable {
    public let maximumQueryDays: Int64
    public let maximumCandidates: Int
    public let maximumOccurrences: Int

    public static let standard = RecurrenceBudget(uncheckedQueryDays: 366, candidates: 100_000, occurrences: 20_000)

    public init(maximumQueryDays: Int64 = 366, maximumCandidates: Int = 100_000, maximumOccurrences: Int = 20_000) throws {
        guard (1...366).contains(maximumQueryDays),
              (1...100_000).contains(maximumCandidates),
              (1...20_000).contains(maximumOccurrences) else {
            throw DomainValidationError.invalidRecurrence
        }
        self.maximumQueryDays = maximumQueryDays
        self.maximumCandidates = maximumCandidates
        self.maximumOccurrences = maximumOccurrences
    }

    private init(uncheckedQueryDays: Int64, candidates: Int, occurrences: Int) {
        maximumQueryDays = uncheckedQueryDays
        maximumCandidates = candidates
        maximumOccurrences = occurrences
    }
}

public struct EventOccurrence: Hashable, Sendable {
    public let key: EventOccurrenceKey
    public let calendarID: UUID
    public let title: String
    public let notes: String?
    public let location: String?
    public let time: EventTime
}

/// Expands only the documented recurrence profile. It returns either a complete result or an error.
public struct RecurrenceEngine: Sendable {
    private let resolver: any LocalTimeResolving

    public init(resolver: some LocalTimeResolving = FoundationLocalTimeResolver()) {
        self.resolver = resolver
    }

    public func expand(
        _ series: RecurringSeries,
        in query: EventTimeRange,
        budget: RecurrenceBudget = .standard
    ) throws -> [EventOccurrence] {
        try validateQuery(query, for: series.event.time, budget: budget)
        let anchor = try Anchor(time: series.event.time)
        let queryEnd = try queryEndDate(query)
        let weeklyDays = series.rule.weekdays.isEmpty
            ? [anchor.date.isoWeekday]
            : series.rule.weekdays.map(\.rawValue)
        var candidateIndex = 0
        var tested = 0
        var validStarts = 0
        var results: [EventOccurrence] = []

        candidateLoop: while true {
            let candidate = try dateCandidate(
                index: candidateIndex,
                anchor: anchor.date,
                frequency: series.rule.frequency,
                interval: series.rule.interval,
                weeklyDays: weeklyDays
            )
            let candidateDate: CivilDate
            switch candidate {
            case .finished:
                break candidateLoop
            case .skipped:
                candidateIndex += 1
                tested += 1
                if tested > budget.maximumCandidates { throw DomainValidationError.candidateLimitExceeded }
                continue
            case let .date(value):
                candidateDate = value
            }

            if candidateDate >= queryEnd { break }
            guard tested < budget.maximumCandidates else { throw DomainValidationError.candidateLimitExceeded }
            tested += 1

            guard let occurrenceTime = try makeOccurrenceTime(candidateDate, anchor: anchor) else {
                candidateIndex += 1
                continue // a zoned occurrence in a DST gap is omitted and does not count
            }
            let occurrenceStart = startKey(of: occurrenceTime)
            if !isBeforeOrAtEnd(occurrenceTime, end: series.rule.end) { break }
            validStarts += 1

            let key = EventOccurrenceKey(eventID: series.event.id, originalStart: occurrenceStart)
            if !series.cancellations.contains(key), overlaps(occurrenceTime, query: query) {
                guard results.count < budget.maximumOccurrences else {
                    throw DomainValidationError.occurrenceLimitExceeded
                }
                results.append(EventOccurrence(
                    key: key,
                    calendarID: series.event.calendarID,
                    title: series.event.title,
                    notes: series.event.notes,
                    location: series.event.location,
                    time: occurrenceTime
                ))
            }
            if case let .count(limit) = series.rule.end, validStarts >= limit { break }
            candidateIndex += 1
        }

        return results
    }

    private func validateQuery(_ query: EventTimeRange, for time: EventTime, budget: RecurrenceBudget) throws {
        switch (time, query) {
        case let (.allDay(_), .civil(range)):
            guard range.dayCount <= budget.maximumQueryDays else { throw DomainValidationError.queryLimitExceeded }
        case let (.utc(_), .instant(range)), let (.zoned(_), .instant(range)):
            let length = range.endExclusive.unixSeconds.subtractingReportingOverflow(range.start.unixSeconds)
            let maximumSeconds = budget.maximumQueryDays.multipliedReportingOverflow(by: 86_400)
            guard !length.overflow,
                  !maximumSeconds.overflow,
                  length.partialValue <= maximumSeconds.partialValue else {
                throw DomainValidationError.queryLimitExceeded
            }
        default:
            throw DomainValidationError.incompatibleQuery
        }
    }

    private func queryEndDate(_ query: EventTimeRange) throws -> CivilDate {
        switch query {
        case let .civil(range): range.endExclusive
        case let .instant(range): try Anchor.utcDate(from: range.endExclusive)
        }
    }

    private enum DateCandidate {
        case date(CivilDate)
        case skipped
        case finished
    }

    private func dateCandidate(index: Int, anchor: CivilDate, frequency: RecurrenceFrequency, interval: Int, weeklyDays: [Int]) throws -> DateCandidate {
        guard index >= 0 else { throw DomainValidationError.arithmeticOverflow }
        let product = index.multipliedReportingOverflow(by: interval)
        guard !product.overflow else { throw DomainValidationError.arithmeticOverflow }
        switch frequency {
        case .daily:
            return try candidateByAddingDays(product.partialValue, to: anchor)
        case .weekly:
            let firstWeekCount = weeklyDays.filter { $0 >= anchor.isoWeekday }.count
            let delta: Int
            if index < firstWeekCount {
                let day = weeklyDays.filter { $0 >= anchor.isoWeekday }[index]
                delta = day - anchor.isoWeekday
            } else {
                let remaining = index - firstWeekCount
                let weekNumber = remaining / weeklyDays.count + 1
                let weekday = weeklyDays[remaining % weeklyDays.count]
                let weeks = weekNumber.multipliedReportingOverflow(by: interval)
                guard !weeks.overflow else { throw DomainValidationError.arithmeticOverflow }
                let offset = weeks.partialValue.multipliedReportingOverflow(by: 7)
                guard !offset.overflow else { throw DomainValidationError.arithmeticOverflow }
                delta = offset.partialValue - anchor.isoWeekday + weekday
            }
            return try candidateByAddingDays(delta, to: anchor)
        case .monthly:
            let base = (anchor.year - 1) * 12 + anchor.month - 1
            let target = base.addingReportingOverflow(product.partialValue)
            guard !target.overflow else { throw DomainValidationError.arithmeticOverflow }
            guard (0..<(9999 * 12)).contains(target.partialValue) else { return .finished }
            let year = target.partialValue / 12 + 1
            let month = target.partialValue % 12 + 1
            let daysInMonth = CivilDate.isLeapYear(year) && month == 2
                ? 29
                : ([4, 6, 9, 11].contains(month) ? 30 : (month == 2 ? 28 : 31))
            guard anchor.day <= daysInMonth else { return .skipped }
            return .date(try CivilDate(year: year, month: month, day: anchor.day))
        case .yearly:
            let targetYear = anchor.year.addingReportingOverflow(product.partialValue)
            guard !targetYear.overflow else { throw DomainValidationError.arithmeticOverflow }
            guard (1...9999).contains(targetYear.partialValue) else { return .finished }
            guard (anchor.month != 2 || anchor.day != 29 || CivilDate.isLeapYear(targetYear.partialValue)) else { return .skipped }
            return .date(try CivilDate(year: targetYear.partialValue, month: anchor.month, day: anchor.day))
        }
    }

    private func candidateByAddingDays(_ days: Int, to anchor: CivilDate) throws -> DateCandidate {
        guard let days64 = Int64(exactly: days) else { throw DomainValidationError.arithmeticOverflow }
        let total = anchor.daysSinceUnixEpoch.addingReportingOverflow(days64)
        guard !total.overflow else { throw DomainValidationError.arithmeticOverflow }
        guard let date = try? CivilDate(daysSinceUnixEpoch: total.partialValue) else { return .finished }
        return .date(date)
    }

    private func makeOccurrenceTime(_ date: CivilDate, anchor: Anchor) throws -> EventTime? {
        switch anchor.kind {
        case .allDay:
            let end = try date.adding(days: anchor.durationDays)
            return .allDay(try AllDayEventTime(start: date, endExclusive: end))
        case .utc:
            let local = try LocalDateTime(date: date, hour: anchor.hour, minute: anchor.minute, second: anchor.second)
            let instant = try Anchor.utcInstant(from: local)
            return .utc(try TimedEventTime(start: instant, durationSeconds: anchor.durationSeconds))
        case let .zoned(zone, _):
            let local = try LocalDateTime(date: date, hour: anchor.hour, minute: anchor.minute, second: anchor.second)
            do {
                let value = try ZonedEventTime(
                    localStart: local,
                    timeZone: zone,
                    repeatedTime: .first,
                    durationSeconds: anchor.durationSeconds,
                    resolver: resolver
                )
                return .zoned(value)
            } catch DomainValidationError.nonexistentLocalTime {
                return nil
            }
        }
    }

    private func startKey(of time: EventTime) -> EventStart {
        switch time {
        case let .allDay(value): .civil(value.range.start)
        case let .utc(value): .instant(value.start)
        case let .zoned(value): .zoned(value.localStart, value.timeZone)
        }
    }

    private func isBeforeOrAtEnd(_ time: EventTime, end: RecurrenceEnd) -> Bool {
        switch (time, end) {
        case (_, .never), (_, .count): true
        case let (.allDay(value), .untilCivilDate(limit)): value.range.start <= limit
        case let (.utc(value), .untilInstant(limit)): value.start <= limit
        case let (.zoned(value), .untilInstant(limit)): value.resolvedStart <= limit
        default: false
        }
    }

    private func overlaps(_ time: EventTime, query: EventTimeRange) -> Bool {
        switch (time, query) {
        case let (.allDay(value), .civil(range)): value.range.overlaps(range)
        case let (.utc(value), .instant(range)): value.range.overlaps(range)
        case let (.zoned(value), .instant(range)): value.instantRange.overlaps(range)
        default: false
        }
    }
}

private struct Anchor {
    enum Kind {
        case allDay
        case utc
        case zoned(TimeZoneID, RepeatedTimeChoice)
    }

    let date: CivilDate
    let hour: Int
    let minute: Int
    let second: Int
    let durationSeconds: Int64
    let durationDays: Int
    let kind: Kind

    init(time: EventTime) throws {
        switch time {
        case let .allDay(value):
            date = value.range.start
            hour = 0; minute = 0; second = 0
            durationSeconds = 0
            guard value.durationInDays <= Int64(Int.max) else { throw DomainValidationError.arithmeticOverflow }
            durationDays = Int(value.durationInDays)
            kind = .allDay
        case let .utc(value):
            let components = try Self.utcComponents(from: value.start)
            date = components.date
            hour = components.hour; minute = components.minute; second = components.second
            durationSeconds = value.durationSeconds; durationDays = 0
            kind = .utc
        case let .zoned(value):
            date = value.localStart.date
            hour = value.localStart.hour; minute = value.localStart.minute; second = value.localStart.second
            durationSeconds = value.durationSeconds; durationDays = 0
            kind = .zoned(value.timeZone, value.repeatedTime)
        }
    }

    static func utcDate(from instant: Instant) throws -> CivilDate { try utcComponents(from: instant).date }

    static func utcComponents(from instant: Instant) throws -> (date: CivilDate, hour: Int, minute: Int, second: Int) {
        var day = instant.unixSeconds / 86_400
        var secondsInDay = instant.unixSeconds % 86_400
        if secondsInDay < 0 { day -= 1; secondsInDay += 86_400 }
        return (
            try CivilDate(daysSinceUnixEpoch: day),
            Int(secondsInDay / 3_600),
            Int((secondsInDay % 3_600) / 60),
            Int(secondsInDay % 60)
        )
    }

    static func utcInstant(from local: LocalDateTime) throws -> Instant {
        let daySeconds = local.date.daysSinceUnixEpoch.multipliedReportingOverflow(by: 86_400)
        guard !daySeconds.overflow else { throw DomainValidationError.arithmeticOverflow }
        let secondsOfDay = Int64(local.hour * 3_600 + local.minute * 60 + local.second)
        let total = daySeconds.partialValue.addingReportingOverflow(secondsOfDay)
        guard !total.overflow else { throw DomainValidationError.arithmeticOverflow }
        return Instant(unixSeconds: total.partialValue)
    }
}
