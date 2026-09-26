import Foundation

public struct Event: Hashable, Sendable, Identifiable {
    public let id: UUID
    public let calendarID: UUID
    /// Opaque iCalendar identity; it is data, never a local path or primary key.
    public let uid: String
    public private(set) var title: String
    public private(set) var notes: String?
    public private(set) var location: String?
    public private(set) var time: EventTime
    public private(set) var revision: UInt64

    public init(
        id: UUID = UUID(),
        calendarID: UUID,
        uid: String? = nil,
        title: String,
        notes: String? = nil,
        location: String? = nil,
        time: EventTime,
        revision: UInt64 = 0
    ) throws {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DomainValidationError.invalidEventTitle
        }
        try Self.validateText(title, maximumBytes: 1_024, allowNewlines: false)
        if let notes { try Self.validateText(notes, maximumBytes: 65_536, allowNewlines: true) }
        if let location { try Self.validateText(location, maximumBytes: 4_096, allowNewlines: false) }
        let resolvedUID = uid ?? id.uuidString
        try Self.validateText(resolvedUID, maximumBytes: 1_024, allowNewlines: false)
        guard !resolvedUID.isEmpty else { throw DomainValidationError.invalidEventUID }

        self.id = id
        self.calendarID = calendarID
        self.uid = resolvedUID
        self.title = title
        self.notes = notes
        self.location = location
        self.time = time
        self.revision = revision
    }

    public mutating func update(title: String, notes: String?, location: String?, time: EventTime) throws {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DomainValidationError.invalidEventTitle
        }
        try Self.validateText(title, maximumBytes: 1_024, allowNewlines: false)
        if let notes { try Self.validateText(notes, maximumBytes: 65_536, allowNewlines: true) }
        if let location { try Self.validateText(location, maximumBytes: 4_096, allowNewlines: false) }
        let nextRevision = revision.addingReportingOverflow(1)
        guard !nextRevision.overflow else { throw DomainValidationError.arithmeticOverflow }
        self.title = title
        self.notes = notes
        self.location = location
        self.time = time
        self.revision = nextRevision.partialValue
    }

    private static func validateText(_ text: String, maximumBytes: Int, allowNewlines: Bool) throws {
        guard text.utf8.count <= maximumBytes else { throw DomainValidationError.contentLimitExceeded }
        for scalar in text.unicodeScalars {
            if scalar.value == 0 { throw DomainValidationError.invalidText }
            if CharacterSet.controlCharacters.contains(scalar), !(allowNewlines && (scalar == "\n" || scalar == "\r" || scalar == "\t")) {
                throw DomainValidationError.invalidText
            }
        }
    }
}
