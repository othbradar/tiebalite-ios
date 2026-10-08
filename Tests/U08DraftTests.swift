import Foundation
import Testing
@testable import TiebaLite

@MainActor
struct U08DraftTests {
    private let target = TextComposeTarget(kind: .threadReply, forumID: 42, forumName: "样本", threadID: 101)
    private let context = AuthContext.active(.init(sessionID: .init(rawValue: 8), generation: 1))

    @Test func processRecreationRestoresRawTextAndOwnedPhotoWithoutUploadToken() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let temporary = directory.appendingPathComponent("picked.jpg")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let bytes = try TestImageFixtureFactory.png(width: 24, height: 18)
        try bytes.write(to: temporary)
        let root = directory.appendingPathComponent("drafts")
        let storage = ComposerDraftStorage(directory: root)
        var draft = TextDraft(title: "标题", content: "正文#(滑稽)")
        draft.photos = [.init(id: "sample", file: .init(url: temporary), width: 24, height: 18, byteCount: bytes.count,
                              uploaded: .init(picID: "must-not-persist", width: 24, height: 18))]
        let drafts = TextComposerDrafts(storage: storage, namespace: { "account-a" })
        drafts.save(draft, target: target, context: context)
        await drafts.flush()
        #expect(drafts.persistenceFailure == nil)
        try FileManager.default.removeItem(at: temporary)
        let reopened = TextComposerDrafts(storage: ComposerDraftStorage(directory: root), namespace: { "account-a" })
        let restored = await reopened.restore(target: target, context: context)
        #expect(restored.title == draft.title && restored.content == draft.content)
        let photo = try #require(restored.photos.first)
        #expect(try Data(contentsOf: photo.file.url) == bytes)
        #expect(photo.file.url != temporary && photo.uploaded == nil)
        // A later text-only save must not delete the still-selected durable attachment.
        reopened.save(restored, target: target, context: context)
        await reopened.flush()
        #expect(FileManager.default.fileExists(atPath: photo.file.url.path))
    }

    @Test func stableAccountIgnoresLeaseAndTargetsStayIsolated() async throws {
        var namespace = "account-a"
        let drafts = TextComposerDrafts(namespace: { namespace })
        let draft = TextDraft(content: "保留草稿")
        drafts.save(draft, target: target, context: context)
        let renewed = AuthContext.active(.init(sessionID: .init(rawValue: 99), generation: 7))
        #expect(await drafts.restore(target: target, context: renewed) == draft)
        let captured = drafts.key(target: target, context: context)
        namespace = "account-b"
        #expect(await drafts.restore(key: captured) == TextDraft())
        #expect(await drafts.restore(target: target, context: renewed) == TextDraft())
        namespace = "account-a"
        var other = target
        other.threadID = 102
        drafts.save(.init(content: "另一草稿"), target: other, context: renewed)
        drafts.clear(target: target, context: renewed)
        await drafts.flush()
        #expect(await drafts.restore(target: target, context: renewed) == TextDraft())
        #expect(await drafts.restore(target: other, context: renewed).content == "另一草稿")
    }

    @Test func quotaFailureKeepsExistingDiskDraftAndCurrentMemory() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let storage = ComposerDraftStorage(directory: root, maximumBytes: 512)
        let drafts = TextComposerDrafts(storage: storage, namespace: { "a" })
        drafts.save(.init(content: "已保存"), target: target, context: context)
        await drafts.flush()
        #expect(drafts.persistenceFailure == nil)
        let large = TextDraft(content: String(repeating: "x", count: 1_024))
        drafts.save(large, target: target, context: context)
        await drafts.flush()
        #expect(drafts.persistenceFailure != nil)
        #expect(drafts.load(target: target, context: context) == large)
        let reopened = TextComposerDrafts(storage: storage, namespace: { "a" })
        #expect(await reopened.restore(target: target, context: context).content == "已保存")
    }
    @Test func successClearAndLogoutCannotBeUndoneByPendingEdits() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        var namespace: String? = "a"
        let storage = ComposerDraftStorage(directory: root)
        let drafts = TextComposerDrafts(storage: storage, namespace: { namespace })
        var other = target
        other.threadID = 102
        drafts.save(.init(content: "已发送"), target: target, context: context)
        drafts.save(.init(content: "其他目标"), target: other, context: context)
        await drafts.flush()
        drafts.save(.init(content: "迟到编辑"), target: target, context: context)
        drafts.clear(target: target, context: context)
        await drafts.flush()
        let reopened = TextComposerDrafts(storage: storage, namespace: { namespace })
        #expect(await reopened.restore(target: target, context: context) == TextDraft())
        #expect(await reopened.restore(target: other, context: context).content == "其他目标")
        let oldKey = try #require(drafts.key(target: other, context: context))
        drafts.save(.init(content: "退出前编辑"), key: oldKey)
        namespace = nil
        drafts.accountDidChange()
        drafts.save(.init(content: "退出后迟到"), key: oldKey)
        await drafts.flush()
        #expect(try await storage.load(oldKey) == TextDraft())
    }

}
