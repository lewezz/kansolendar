import Foundation
import KansolendarCore

/// Decrypted state exists only in the owning actor's unlocked session.
/// Persist the encoded value only through KansoFileEnvelope, never as a sidecar.
internal struct KansoDocument: Sendable, Equatable {
    let id: UUID
    var calendars: [LocalCalendar]
    var events: [VaultEvent]

    static let maximumCalendars = 1_000
    static let maximumEvents = 100_000

    init(id: UUID = UUID(), calendars: [LocalCalendar] = [], events: [VaultEvent] = []) {
        self.id = id
        self.calendars = calendars
        self.events = events
    }

    func validate() throws {
        guard calendars.count <= Self.maximumCalendars, events.count <= Self.maximumEvents,
              Set(calendars.map(\.id)).count == calendars.count,
              Set(events.map { $0.event.id }).count == events.count else {
            throw VaultStorageError.corruptVault
        }
        let calendarIDs = Set(calendars.map(\.id))
        var uids: [UUID: Set<String>] = [:]
        for item in events {
            guard calendarIDs.contains(item.event.calendarID),
                  item.cancellations.allSatisfy({ $0.eventID == item.event.id }),
                  uids[item.event.calendarID, default: []].insert(item.event.uid).inserted else {
                throw VaultStorageError.corruptVault
            }
            if let recurrence = item.recurrence {
                _ = try RecurringSeries(event: item.event, rule: recurrence, cancellations: item.cancellations)
            } else if !item.cancellations.isEmpty {
                throw VaultStorageError.corruptVault
            }
        }
    }
}

/// IDs, relationships, inventory and payloads all go inside the outer ciphertext.
/// Reuse the domain codec rather than bypassing its date/time and recurrence validation.
internal enum KansoDocumentCodec {
    private struct CalendarRecord: Codable {
        let id: UUID
        let payload: Data
    }

    private struct EventRecord: Codable {
        let id: UUID
        let calendarID: UUID
        let payload: Data
        let cancellations: [Data]
    }

    private struct DocumentRecord: Codable {
        let version: Int
        let id: UUID
        let calendars: [CalendarRecord]
        let events: [EventRecord]
    }

    static func encode(_ document: KansoDocument) throws -> Data {
        try document.validate()
        let record = DocumentRecord(
            version: 1, id: document.id,
            calendars: try document.calendars.map { CalendarRecord(id: $0.id, payload: try VaultPayloadCodec.encode($0)) },
            events: try document.events.map { item in
                EventRecord(
                    id: item.event.id, calendarID: item.event.calendarID,
                    payload: try VaultPayloadCodec.encode(item.event, recurrence: item.recurrence),
                    cancellations: try item.cancellations.map { try VaultPayloadCodec.encode(EventCancellation(key: $0)) }
                )
            }
        )
        let data = try JSONEncoder().encode(record)
        guard data.count <= KansoFileEnvelope.maximumPlaintextBytes else { throw VaultStorageError.invalidInput }
        return data
    }

    static func decode(_ data: Data) throws -> KansoDocument {
        guard data.count <= KansoFileEnvelope.maximumPlaintextBytes else { throw VaultStorageError.corruptVault }
        let record = try JSONDecoder().decode(DocumentRecord.self, from: data)
        guard record.version == 1 else { throw VaultPayloadCodecError.unsupportedVersion(record.version) }
        guard record.calendars.count <= KansoDocument.maximumCalendars,
              record.events.count <= KansoDocument.maximumEvents else { throw VaultStorageError.corruptVault }
        let document = try KansoDocument(
            id: record.id,
            calendars: record.calendars.map { try VaultPayloadCodec.decodeCalendar($0.payload, id: $0.id) },
            events: record.events.map { item in
                guard item.cancellations.count <= 100_000 else { throw VaultStorageError.corruptVault }
                let cancellations = try item.cancellations.map { try VaultPayloadCodec.decodeCancellation($0, eventID: item.id).key }
                guard Set(cancellations).count == cancellations.count else { throw VaultStorageError.corruptVault }
                return try VaultPayloadCodec.decodeEvent(
                    item.payload, id: item.id, calendarID: item.calendarID, cancellations: Set(cancellations)
                )
            }
        )
        try document.validate()
        return document
    }
}
