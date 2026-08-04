#if TEST_SUPPORT
@testable import TiebaLite
#endif

#if UITESTING || TEST_SUPPORT
actor FakeSessionCredentialStore: SessionCredentialStore {
    private var credential: SessionCredential?
    private var recordedLoadCount = 0
    private var recordedSaveCount = 0
    private var recordedDeleteCount = 0

    init(initialCredential: SessionCredential? = nil) {
        credential = initialCredential
    }

    func load() throws -> SessionCredential? {
        recordedLoadCount += 1
        return credential
    }

    func save(_ credential: SessionCredential) throws {
        recordedSaveCount += 1
        self.credential = credential
    }

    func delete() throws {
        recordedDeleteCount += 1
        credential = nil
    }

    func loadCount() -> Int {
        recordedLoadCount
    }

    func saveCount() -> Int {
        recordedSaveCount
    }

    func deleteCount() -> Int {
        recordedDeleteCount
    }
}
#endif
