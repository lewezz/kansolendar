import Foundation

public enum CalendarColor: String, CaseIterable, Hashable, Sendable, Codable {
    case red, orange, yellow, green, blue, purple, gray
}

public struct LocalCalendar: Hashable, Sendable, Identifiable {
    public let id: UUID
    public private(set) var name: String
    public let color: CalendarColor
    public var sortOrder: Int
    public let defaultTimeZone: TimeZoneID

    public init(
        id: UUID = UUID(),
        name: String,
        color: CalendarColor = .blue,
        sortOrder: Int = 0,
        defaultTimeZone: TimeZoneID
    ) throws {
        try Self.validateName(name)
        self.id = id
        self.name = name
        self.color = color
        self.sortOrder = sortOrder
        self.defaultTimeZone = defaultTimeZone
    }

    public mutating func rename(to name: String) throws {
        try Self.validateName(name)
        self.name = name
    }

    private static func validateName(_ name: String) throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              name.utf8.count <= 256,
              !name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
            throw DomainValidationError.invalidCalendarName
        }
    }
}
