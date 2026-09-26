import Foundation

public enum DomainValidationError: Error, Equatable, Sendable {
    case invalidCivilDate
    case invalidTimeComponent
    case invalidTimeZoneIdentifier
    case invalidCalendarName
    case invalidEventTitle
    case invalidEventUID
    case contentLimitExceeded
    case invalidText
    case nonexistentLocalTime
    case ambiguousLocalTime
    case invalidRange
    case invalidDuration
    case invalidRecurrence
    case arithmeticOverflow
    case queryLimitExceeded
    case candidateLimitExceeded
    case occurrenceLimitExceeded
    case incompatibleQuery
}
