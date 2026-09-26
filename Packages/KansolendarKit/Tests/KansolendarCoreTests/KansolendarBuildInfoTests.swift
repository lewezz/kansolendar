import KansolendarCore
import Testing

@Suite("Kansolendar build info")
struct KansolendarBuildInfoTests {
    @Test("declares local offline product identity")
    func declaresLocalOfflineIdentity() {
        #expect(KansolendarBuildInfo.productName == "Kansolendar")
        #expect(KansolendarBuildInfo.isOfflineOnly)
    }
}
