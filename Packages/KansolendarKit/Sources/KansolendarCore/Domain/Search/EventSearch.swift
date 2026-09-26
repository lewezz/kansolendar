import Foundation

public struct EventSearchQuery: Sendable {
    public let text: String?
    public let calendarIDs: Set<UUID>?
    public let timeRange: EventTimeRange

    public init(text: String? = nil, calendarIDs: Set<UUID>? = nil, timeRange: EventTimeRange) {
        self.text = text
        self.calendarIDs = calendarIDs
        self.timeRange = timeRange
    }
}

/// In-memory filtering over event records. Recurrence expansion remains a separate, bounded operation.
public enum EventSearch {
    public static func matching(_ events: [Event], query: EventSearchQuery) -> [Event] {
        let needle = normalized(query.text ?? "")
        return events
            .filter { event in
                if let calendarIDs = query.calendarIDs, !calendarIDs.contains(event.calendarID) { return false }
                if !needle.isEmpty && !normalized(event.title).contains(needle) { return false }
                return overlaps(event.time, range: query.timeRange)
            }
            .sorted { $0.id.uuidString < $1.id.uuidString }
    }

    public static func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .precomposedStringWithCanonicalMapping
    }

    private static func overlaps(_ time: EventTime, range: EventTimeRange) -> Bool {
        switch (time, range) {
        case let (.allDay(value), .civil(civilRange)):
            value.range.overlaps(civilRange)
        case let (.utc(value), .instant(instantRange)):
            value.range.overlaps(instantRange)
        case let (.zoned(value), .instant(instantRange)):
            value.instantRange.overlaps(instantRange)
        default:
            false
        }
    }
}
