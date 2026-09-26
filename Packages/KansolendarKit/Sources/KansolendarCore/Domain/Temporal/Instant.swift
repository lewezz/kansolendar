import Foundation

/// A point on the Unix timeline, stored at whole-second precision.
public struct Instant: Hashable, Comparable, Sendable, Codable {
    public let unixSeconds: Int64

    public init(unixSeconds: Int64) {
        self.unixSeconds = unixSeconds
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.unixSeconds < rhs.unixSeconds
    }

    public func adding(seconds: Int64) throws -> Self {
        let result = unixSeconds.addingReportingOverflow(seconds)
        guard !result.overflow else { throw DomainValidationError.arithmeticOverflow }
        return Self(unixSeconds: result.partialValue)
    }
}

public struct InstantRange: Hashable, Sendable {
    public let start: Instant
    public let endExclusive: Instant

    public init(start: Instant, endExclusive: Instant) throws {
        guard start < endExclusive else { throw DomainValidationError.invalidRange }
        self.start = start
        self.endExclusive = endExclusive
    }

    init(uncheckedStart start: Instant, endExclusive: Instant) {
        self.start = start
        self.endExclusive = endExclusive
    }

    public func overlaps(_ other: Self) -> Bool {
        start < other.endExclusive && endExclusive > other.start
    }

    public func contains(_ instant: Instant) -> Bool {
        start <= instant && instant < endExclusive
    }
}
