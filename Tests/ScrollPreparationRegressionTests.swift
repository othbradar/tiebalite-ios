import Testing
@testable import TiebaLite

extension SFScrollTests {
    @MainActor @Suite(.serialized)
    struct ScrollPreparationRegressionTests {
        @Test func candidatePreparationCoalescesWithoutCancellingAnotherConsumer() async throws {
            let repository = U14ActionMock(), gate = U14ActionGate(), session = U14Session()
            let store = ContentActionStore(repository: repository, ledger: .init(file: nil), visibility: ContentRemovalVisibility(),
                                           context: { session.value }, account: { 42 })
            let target = ContentActionTarget(kind: .post, threadID: 10, postID: 11)
            repository.inspectGate = gate
            let first = Task { await store.prepareDeletion(target, authorID: 42) }
            await gate.waitForEntry()
            ScrollWorkMetrics.start()
            let second = Task { await store.prepareDeletion(target, authorID: 42) }
            try #require(await VirtualListNativeCondition.wait { ScrollWorkMetrics.value("preparation.join") == 1 })
            _ = ScrollWorkMetrics.stop()
            first.cancel()
            gate.release(); await first.value; await second.value
            #expect(repository.inspections == 1 && store.permissions[target]?.canDelete == true)
            #expect(store.busy.isEmpty && repository.writes == 0)
            session.value = .init(namespace: "sf-b", revision: 2); store.sessionChanged()
            let lateGate = U14ActionGate(); repository.inspectGate = lateGate
            let late = Task { await store.prepareDeletion(target, authorID: 42) }
            await lateGate.waitForEntry()
            session.value = .init(namespace: "sf-c", revision: 3); store.sessionChanged()
            lateGate.release(); await late.value
            #expect(store.permissions.isEmpty)
            repository.inspectGate = nil
            await store.prepareDeletion(target, authorID: 42)
            #expect(store.permissions[target]?.canDelete == true)
        }

        @Test func candidatePreparationDoesNotAddAnInspectionDuringAWrite() async {
            let repository = U14ActionMock(), gate = U14ActionGate()
            let store = ContentActionStore(repository: repository, ledger: .init(file: nil), visibility: ContentRemovalVisibility(),
                                           context: { .init(namespace: "sf-write", revision: 1) }, account: { 42 })
            let target = ContentActionTarget(kind: .post, threadID: 10, postID: 11)
            repository.writeGate = gate
            let write = Task { await store.toggleLike(target) }
            await gate.waitForEntry()
            let count = repository.inspections
            await store.prepareDeletion(target, authorID: 42)
            #expect(repository.inspections == count)
            gate.release(); await write.value
            #expect(repository.writes == 1)
        }

        @Test func preparedContentUpdatesSameIdentityWithoutRepeatedRenderingParse() {
            let source = ThreadContentSource(threadID: 1, postID: 2, scope: .post)
            func model(_ body: String, author: String) -> ThreadReaderPostRowModel {
                let subSource = ThreadContentSource(threadID: 1, postID: 3, scope: .subPost)
                let child = ThreadReaderSubpost(
                    parentPostID: 2, author: .init(rawUserID: 4, displayName: author),
                    replyToDisplayName: "乙", metadata: "10-23", document: .init(
                        source: subSource, availability: .available,
                        nodes: [.init(id: .init(source: subSource, ordinal: 0), rawType: 0,
                                      payload: .text(.init(value: body)))], poll: nil))
                return .init(.init(
                    floorNumber: 2, author: .init(rawUserID: 3, displayName: "楼层作者"), metadata: "10-23",
                    document: .init(
                        source: source, availability: .available,
                        nodes: [.init(id: .init(source: source, ordinal: 0), rawType: 0, payload: .text(.init(value: body)))], poll: nil),
                    subposts: [child]))
            }
            let original = model("旧正文", author: "甲")
            ScrollWorkMetrics.start()
            for _ in 0..<30 {
                #expect(original.preparedBlocks.first?.runs == [.text("旧正文")])
                #expect(original.inlineSubposts[0].previewRuns.first == .text("甲: ", bold: true))
            }
            #expect(ScrollWorkMetrics.stop().isEmpty)
            let revised = model("新正文", author: "丙")
            #expect(original.source == revised.source)
            #expect(revised.preparedBlocks.first?.runs == [.text("新正文")])
            #expect(revised.inlineSubposts[0].previewRuns == [.text("丙: ", bold: true), .text("回复 乙："), .text("新正文")])
        }
    }
}
