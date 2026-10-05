import Foundation
import CryptoKit
import KansolendarCore
@testable import KansolendarStorage
import Testing

@Suite("Portable encrypted file persistence")
struct PortableVaultDatabaseTests {
    private let password = "meadow private calendar phrase"

    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test("public API persists content and releases writer ownership on close")
    func persistsAcrossReopen() async throws {
        let dir = try directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("Personal.kanso")
        let first = try KansolendarVault(portableFileURL: url, createNew: true)
        _ = try await first.createPasswordVault(password: password)
        let calendar = try LocalCalendar(name: "Private", defaultTimeZone: TimeZoneID("UTC"))
        try await first.save(calendar)
        #expect(throws: VaultError.fileInUse) { try KansolendarVault(portableFileURL: url) }
        await first.lock()
        await #expect(throws: VaultError.locked) { try await first.calendars() }
        await first.close()
        let second = try KansolendarVault(portableFileURL: url)
        #expect(try await second.state() == .locked)
        try await second.unlock(password: password)
        #expect(try await second.calendars() == [calendar])
        #expect(try Data(contentsOf: url).prefix(8) == KansoFileEnvelope.magic)
        await second.close()
    }

    @Test("external modification is never silently overwritten")
    func externalChange() async throws {
        let dir = try directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("Personal.kanso")
        let vault = try KansolendarVault(portableFileURL: url, createNew: true)
        _ = try await vault.createPasswordVault(password: password)
        var modified = try Data(contentsOf: url)
        modified[modified.count - 1] ^= 1
        try modified.write(to: url)
        let calendar = try LocalCalendar(name: "Must not overwrite", defaultTimeZone: TimeZoneID("UTC"))
        await #expect(throws: VaultError.fileChanged) { try await vault.save(calendar) }
        #expect(try Data(contentsOf: url) == modified)
        #expect(try await vault.state() == .locked)
        await vault.close()
    }

    @Test("obsolete and foreign formats are rejected without changing source bytes")
    func rejectsOtherFormats() throws {
        let dir = try directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        for (index, data) in [Data("SQLite format 3\0".utf8) + Data(repeating: 0, count: 128), Data("BEGIN:VCALENDAR\nEND:VCALENDAR".utf8), Data(repeating: 0, count: 64)].enumerated() {
            let url = dir.appendingPathComponent("Unsupported-\(index).kanso")
            try data.write(to: url)
            #expect(throws: VaultError.corruptVault) { try KansolendarVault(portableFileURL: url) }
            #expect(try Data(contentsOf: url) == data)
        }
    }
}
