import Foundation
import GeneratedProtobuf
import SwiftProtobuf
import Testing
import UIKit

@testable import TiebaLite

struct R08SubpostsProtocolTests {
  private let route = SubpostsRoute(threadID: 8_001, postID: 9_002)

  @Test func anonymousRequestMatchesAndroidAndDoesNotCarryCredentials() async throws {
    let bytes = try PBFloorProtocol.encodeRequest(route: route, page: 2)
    let wire = try Tieba_PbFloor_PbFloorRequest(serializedBytes: bytes)
    #expect(wire.data.kz == 8_001 && wire.data.pid == 9_002 && wire.data.pn == 2)
    #expect(wire.data.hasSpid && wire.data.spid == 0)
    #expect(wire.data.hasIsCommReverse && wire.data.isCommReverse == 0)
    #expect(wire.data.hasOriUgcType && wire.data.oriUgcType == 0)
    #expect(wire.data.forumID == 0 && wire.data.scrW == 0 && wire.data.scrH == 0)
    #expect(
      !wire.data.common.hasBduss && !wire.data.common.hasStoken && wire.data.common.clientID.isEmpty
    )
    let request = try await EndpointRequestBuilder(authorizer: AnonymousRequestAuthorizer())
      .makeRequest(
        endpoint: PBFloorProtocol.descriptor(host: "fixture.invalid"), authentication: .anonymous,
        body: PBFloorProtocol.body(route: route, page: 2)
      )
    #expect(
      request.url.absoluteString
        == "https://fixture.invalid/c/f/pb/floor?cmd=302002&format=protobuf")
    #expect(request.headers["Cookie"] == nil && request.headers["Authorization"] == nil)
  }

  @Test func fixtureMapsParentAuthorRichTextAndTwoOverlappingPages() throws {
    let first = try PBFloorProtocol.map(
      PBFloorProtocol.decode(R08PBFloorFixture.bytes(page: 1)), route: route, page: 1)
    let second = try PBFloorProtocol.map(
      PBFloorProtocol.decode(R08PBFloorFixture.bytes(page: 2)), route: route, page: 2)
    #expect(first.parent?.floorNumber == 2 && first.parent?.id.postID == 9_002)
    #expect(first.items.count == 15 && second.items.count == 16)
    #expect(first.hasMore && !second.hasMore)
    #expect(first.items[0].author.levelID == 14 && first.items[0].author.avatarResource != nil)
    #expect(
      TiebaRichText.runs(nodes: first.items[0].document.nodes).contains {
        $0.emoticonID == "image_emoticon91"
      })
    #expect(
      first.items[0].document.nodes.contains {
        if case .mention = $0.payload { true } else { false }
      })
    #expect(
      second.items.last?.document.mediaIntent(
        selecting: .init(
          sourceNodeID: .init(
            source: .init(threadID: 8_001, postID: 10_030, scope: .subPost), ordinal: 1
          ))) != nil)
    #expect(second.items.first?.id == first.items.last?.id)
  }

  @Test func missingAuthorsUnknownContentAndEmptyPageAreReadable() throws {
    var wire = try PBFloorProtocol.decode(R08PBFloorFixture.bytes(page: 1))
    wire.data.subpostList[0].clearAuthor()
    wire.data.subpostList[0].content[0].type = 99
    let page = try PBFloorProtocol.map(wire, route: route, page: 1)
    #expect(page.items[0].author.displayName == "未知作者")
    #expect(page.items[0].author.levelID == nil)
    #expect(page.items[0].document.nodes[0].rawType == 99)
    wire.data.subpostList = []
    wire.data.page.totalPage = 1
    let empty = try PBFloorProtocol.map(wire, route: route, page: 1)
    #expect(empty.items.isEmpty && !empty.hasMore && empty.parent != nil)
  }

  @Test func identityAndMalformedResponsesFailWithoutInventingContent() throws {
    #expect(throws: PBFloorProtocolError.self) {
      try PBFloorProtocol.encodeRequest(route: route, page: 0)
    }
    #expect(throws: PBFloorProtocolError.self) { try PBFloorProtocol.decode(Data()) }
    #expect(throws: (any Error).self) { try PBFloorProtocol.decode(Data([0xff])) }
    var wire = try PBFloorProtocol.decode(R08PBFloorFixture.bytes(page: 1))
    wire.data.post.id = 1
    #expect(throws: PBFloorProtocolError.self) {
      try PBFloorProtocol.map(wire, route: route, page: 1)
    }
    wire.data.post.id = 9_002
    wire.data.page.currentPage = 2
    #expect(throws: PBFloorProtocolError.self) {
      try PBFloorProtocol.map(wire, route: route, page: 1)
    }
    wire.error.errorCode = 403
    #expect(throws: EndpointWireFailure.server(code: 403)) {
      try PBFloorProtocol.decode(wire.serializedData())
    }
  }

  @Test func livePipelineKeepsCancellationAndAnonymousAuth() async throws {
    let client = HarnessMockHTTPClient()
    let repository = LiveSubpostsRepository(client: client, host: "fixture.invalid")
    let load = Task { try await repository.loadPage(route: route, page: 1) }
    try await client.waitForPendingCallCount(1)
    let call = try #require(await client.pendingCalls().first)
    try await client.succeed(
      call.id,
      with: HTTPResponse(
        statusCode: 200,
        headers: ["content-type": "application/octet-stream"],
        body: R08PBFloorFixture.bytes(page: 1)))
    #expect(try await load.value.items.count == 15)
    let cancelled = Task { try await repository.loadPage(route: route, page: 2) }
    try await client.waitForPendingCallCount(1)
    cancelled.cancel()
    await #expect(throws: CancellationError.self) { try await cancelled.value }
  }
}

@MainActor
struct R08SubpostEmoticonTests {
  // Sanitized type/text/c pairs from all three pages of the reported public floor.
  private let samples = [
    ("shoubai_emoji_face_04", "大笑"), ("shoubai_emoji_face_07", "笑哭"),
    ("shoubai_emoji_face_60", "赞同"), ("shoubai_emoji_face_71", "滑稽"),
    ("shoubai_emoji_face_72", "捂脸")
  ]

  @Test(arguments: [0, 1, 2])
  func subpostRegisteredFacesRenderInlineWithoutChangingCopyOrLinkIdentity(_ attempt: Int) throws {
    var response = try PBFloorProtocol.decode(R08PBFloorFixture.bytes(page: 1))
    var mention = Tieba_PbContent()
    mention.type = 4
    mention.text = "固定回复对象"
    var link = Tieba_PbContent()
    link.type = 1
    link.text = "链接"
    link.link = "https://fixture.invalid/reply"
    let emojis = samples.map { key, name in
      var node = Tieba_PbContent()
      node.type = 2
      node.text = key
      node.c = name
      return node
    }
    response.data.subpostList[attempt].content = [mention] + emojis + [link]
    let page = try PBFloorProtocol.map(
      response, route: .init(threadID: 8_001, postID: 9_002), page: 1)
    let document = page.items[attempt].document
    let runs = TiebaRichText.runs(nodes: document.nodes)
    #expect(runs.compactMap(\.emoticonID) == samples.map(\.0))
    #expect(ThreadContentBlock.make(document.nodes).count == 1)
    let original = "固定回复对象" + samples.map { "#(\($0.1))" }.joined() + "链接"
    for size: CGFloat in [17, 22] {
      let rendered = TiebaRichTextBuilder.build(runs: runs, font: .systemFont(ofSize: size))
      #expect(rendered.string == "固定回复对象" + String(repeating: "\u{FFFC}", count: 5) + "链接")
      #expect(TiebaRichTextBuilder.copyText(rendered) == original)
      for index in 6..<11 {
        let attachment =
          rendered.attribute(.attachment, at: index, effectiveRange: nil) as? NSTextAttachment
        #expect(attachment?.image != nil)
      }
    }
    #expect(runs.compactMap(\.linkIntent).first?.sourceNodeID == document.nodes.last?.id)
  }

  @Test func existingNamesAndLiteralImageTextAreNotReinterpreted() {
    for emoticon in TiebaEmoticonRegistry.catalog {
      #expect(TiebaRichText.parse("#(\(emoticon.name))").contains { $0.emoticonID != nil })
    }
    #expect(TiebaEmoticonRegistry.named("滑稽")?.resourceID == "image_emoticon25")
    #expect(TiebaRichText.parse("[图片] #未知话题").map(\.alternativeText).joined() == "[图片] #未知话题")
    #expect(TiebaRichText.parse("[图片] #未知话题").compactMap(\.emoticonID).isEmpty)
    // Both evidence-backed official URLs for this ID return 404. Never substitute different artwork.
    #expect(TiebaEmoticonRegistry.resolve(registryKey: "shoubai_emoji_face_368", name: "绝") == nil)
  }
}
