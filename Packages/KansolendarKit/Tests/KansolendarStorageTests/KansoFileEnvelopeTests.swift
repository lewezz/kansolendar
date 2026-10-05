import CryptoKit
import Foundation
import KansolendarCore
@testable import KansolendarStorage
import Testing

@Suite("Whole-document Kanso encryption")
struct KansoFileEnvelopeTests {
    private let password = "orchard moon river lantern"

    private func fixture() throws -> KansoDocument {
        let calendar = try LocalCalendar(name: "Secret medical appointments", defaultTimeZone: TimeZoneID("UTC"))
        let event = try Event(
            calendarID: calendar.id, title: "Private consultation",
            notes: "Confidential detail", location: "Hidden clinic",
            time: .allDay(AllDayEventTime(start: CivilDate(year: 2026, month: 10, day: 6), endExclusive: CivilDate(year: 2026, month: 10, day: 7)))
        )
        return KansoDocument(calendars: [calendar], events: [VaultEvent(event: event, recurrence: nil)])
    }

    @Test("password round trip hides content and internal identities")
    func roundTrip() throws {
        let document = try fixture()
        let session = try KansoFileEnvelope.createSession(password: password)
        let bytes = try KansoFileEnvelope.seal(document, session: session)
        try KansoFileEnvelope.validateStructure(bytes)
        let (restored, _) = try KansoFileEnvelope.open(bytes, password: password)
        #expect(restored == document)
        for text in [document.id.uuidString, document.calendars[0].id.uuidString,
                     document.events[0].event.id.uuidString, "Secret medical appointments",
                     "Private consultation", "Confidential detail", "Hidden clinic", password] {
            #expect(bytes.range(of: Data(text.utf8)) == nil)
        }
        // Every save has a fresh nonce, even when the document has not changed.
        #expect(try KansoFileEnvelope.seal(document, session: session) != bytes)
    }

    @Test("wrong password cannot decrypt")
    func wrongPassword() throws {
        let bytes = try KansoFileEnvelope.seal(fixture(), session: KansoFileEnvelope.createSession(password: password))
        #expect(throws: VaultStorageError.authenticationFailed) {
            try KansoFileEnvelope.open(bytes, password: "wrong password never matches")
        }
    }

    @Test("ciphertext modification and truncation fail closed")
    func damagedFiles() throws {
        let bytes = try KansoFileEnvelope.seal(fixture(), session: KansoFileEnvelope.createSession(password: password))
        var modified = bytes
        modified[modified.count - 1] ^= 1
        #expect(throws: (any Error).self) { try KansoFileEnvelope.open(modified, password: password) }
        for size in [0, 7, 12, 39, bytes.count - 1] {
            #expect(throws: (any Error).self) {
                try KansoFileEnvelope.open(Data(bytes.prefix(size)), password: password)
            }
        }
        var oversizedHeader = bytes
        oversizedHeader.replaceSubrange(8..<12, with: [255, 255, 255, 255])
        #expect(throws: (any Error).self) { try KansoFileEnvelope.validateStructure(oversizedHeader) }
    }

    @Test("exact serialized header is authenticated")
    func alteredHeader() throws {
        let document = try fixture()
        let session = try KansoFileEnvelope.createSession(password: password)
        let bytes = try KansoFileEnvelope.seal(document, session: session)
        // JSON whitespace leaves the key wrapper valid but changes the authenticated bytes.
        let changedHeader = session.headerBytes + Data([32])
        let count = UInt32(changedHeader.count)
        let oldPrefixSize = 12 + session.headerBytes.count
        let altered = KansoFileEnvelope.magic + Data([UInt8(count >> 24), UInt8((count >> 16) & 255), UInt8((count >> 8) & 255), UInt8(count & 255)]) + changedHeader + bytes.dropFirst(oldPrefixSize)
        #expect(throws: VaultStorageError.corruptVault) { try KansoFileEnvelope.open(altered, password: password) }
    }

    @Test("orphaned events and duplicate identities are rejected")
    func invalidInventory() throws {
        let document = try fixture()
        #expect(throws: (any Error).self) {
            try KansoDocumentCodec.encode(KansoDocument(events: document.events))
        }
        #expect(throws: (any Error).self) {
            try KansoDocumentCodec.encode(KansoDocument(calendars: document.calendars + document.calendars))
        }
    }
    @Test("timed zones, recurrence and cancellations survive full document encryption")
    func completeTemporalRoundTrip() throws {
        var document = try fixture()
        let calendarID = document.calendars[0].id
        let event = try Event(calendarID: calendarID, title: "Recurring UTC", time: .utc(TimedEventTime(start: Instant(unixSeconds: 0), durationSeconds: 60)))
        let rule = try RecurrenceRule(frequency: .daily, end: .count(5))
        let cancellation = EventOccurrenceKey(eventID: event.id, originalStart: .instant(Instant(unixSeconds: 86400)))
        document.events.append(VaultEvent(event: event, recurrence: rule, cancellations: [cancellation]))
        let zoned = try Event(calendarID: calendarID, title: "Zoned", time: .zoned(ZonedEventTime(
            localStart: LocalDateTime(date: CivilDate(year: 2026, month: 9, day: 1), hour: 14, minute: 15),
            timeZone: TimeZoneID("Europe/Madrid"), repeatedTime: .first, durationSeconds: 3600, resolver: FoundationLocalTimeResolver()
        )))
        document.events.append(VaultEvent(event: zoned, recurrence: nil))
        let data = try KansoFileEnvelope.seal(document, session: KansoFileEnvelope.createSession(password: password))
        let (restored, _) = try KansoFileEnvelope.open(data, password: password)
        #expect(restored == document)
    }

}
