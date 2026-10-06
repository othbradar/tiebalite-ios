#if DEBUG
  import Foundation

  /// Synthetic two-page data. The production composition root never selects this repository.
  struct FixtureSubpostsRepository: SubpostsRepository {
    func loadPage(route: SubpostsRoute, page: Int) async throws -> SubpostsPage {
      try Task.checkCancellation()
      guard (1...2).contains(page) else { throw PBFloorProtocolError.invalidPage }
      let source = ThreadContentSource(threadID: route.threadID, postID: route.postID, scope: .post)
      let parent = ThreadReaderPost(
        floorNumber: 2,
        author: .init(
          rawUserID: 91, displayName: "固定楼层作者", portrait: "https://fixture.invalid/avatar/91",
          levelID: 14),
        metadata: "2026年9月24日 8:30",
        document: .init(
          source: source, availability: .available,
          nodes: [
            .init(
              id: .init(source: source, ordinal: 0), rawType: 0,
              payload: .text(.init(value: "楼中楼分页样本，保持原楼层位置。#滑稽")))
          ], poll: nil))
      let range = page == 1 ? 1...15 : 15...30
      return SubpostsPage(
        route: route, parent: parent, threadAuthorID: 91, forumID: 90, forumName: "固定样本吧",
        items: range.map { item(route: route, index: $0) }, pageNumber: page, totalPages: 2,
        totalCount: 30)
    }

    private func item(route: SubpostsRoute, index: Int) -> Subpost {
      let source = ThreadContentSource(
        threadID: route.threadID, postID: 10_000 + Int64(index), scope: .subPost)
      var nodes = [
        ThreadContentNode(
          id: .init(source: source, ordinal: 0), rawType: 0,
          payload: .text(.init(value: "回复 固定样本用户：第 \(index) 条完整回复，内联 #滑稽 #捂嘴笑 #(微微一笑)。")))
      ]
      if index == 1 {
        nodes += FixtureThreadReaderPages.actionLinks(source: source, ordinal: 99)
        let faces = [("04", "大笑"), ("07", "笑哭"), ("60", "赞同"), ("71", "滑稽"), ("72", "捂脸")]
        nodes += faces.enumerated().map { ordinal, face in
          ThreadContentNode(
            id: .init(source: source, ordinal: ordinal + 1), rawType: 2,
            payload: .emoji(.init(registryKey: "shoubai_emoji_face_\(face.0)", code: face.1)))
        }
      }
      return Subpost(
        author: .init(
          rawUserID: 90 + Int64(index), displayName: "样本回复者\(index)",
          portrait: "https://fixture.invalid/avatar/\(index)", levelID: 14, ipLocation: "辽宁"),
        document: .init(source: source, availability: .available, nodes: nodes, poll: nil),
        createdAt: 1_790_209_800 + UInt32(index) * 60, agreeCount: Int64(index))
    }
  }
#endif
