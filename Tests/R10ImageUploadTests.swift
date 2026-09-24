import Foundation
import Testing
@testable import TiebaLite

@MainActor
struct R10ImageUploadTests {
    @Test func sequentialChunksHaveCorrectSizeSignatureAndNoLoginCookie() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("r10-chunks.bin")
        let bytes = Data(repeating: 42, count: 512_003)
        try bytes.write(to: url)
        let photo = ComposerPhoto(id: "fixture-md5", file: .init(url: url), width: 640, height: 480, byteCount: bytes.count)
        let client = HarnessMockHTTPClient()
        let auth = SessionAuthContextProvider()
        auth.install(try #require(SessionCredential(bduss: "fixture-session", stoken: "fixture-token")))
        let uploader = LiveComposerImageUploader(client: client, authContextProvider: auth)
        let task = Task { try await uploader.upload(photo, forumName: "样本", context: auth.context(), progress: { _ in }) }
        for index in 1...2 {
            try await client.waitForPendingCallCount(1)
            let call = try #require(await client.pendingCalls().first)
            #expect(call.request.url.absoluteString == "https://c.tieba.baidu.com/c/s/uploadPicture")
            #expect(call.request.headers["Cookie"] == "ka=open")
            let sent = try #require(call.request.body)
            let wire = try #require(String(data: sent, encoding: .utf8))
            #expect(wire.contains("name=\"chunkNo\"\r\n\r\n\(index)\r\n"))
            #expect(wire.contains("name=\"isFinish\"\r\n\r\n\(index == 2 ? 1 : 0)\r\n"))
            #expect(wire.contains("name=\"chunk\"; filename=\"file\""))
            #expect(wire.contains(String(repeating: "*", count: index == 1 ? 512_000 : 3)))
            let partBytes = index == 1 ? bytes.prefix(512_000) : bytes.suffix(3)
            let body = ImageUploadProtocol.body(
                photo: photo, chunk: index, bytes: Data(partBytes), forumName: "样本",
                authorization: SessionAuthorization(bduss: "fixture-session", stoken: "fixture-token"))
            if case let .multipartBinary(_, fields, part) = body {
                let values = Dictionary(uniqueKeysWithValues: fields.map { ($0.name, $0.value) })
                #expect(values["chunkNo"] == String(index))
                #expect(values["isFinish"] == (index == 2 ? "1" : "0"))
                #expect(values["resourceId"] == "fixture-md5512000")
                #expect(values["sdk_ver"] == nil && values["naws_game_ver"] == nil)
                #expect(values["sign"] == TextWriteProtocol.signedFields(values.filter { $0.key != "sign" }).last?.value)
                #expect(part.name == "chunk" && part.data.count == (index == 1 ? 512_000 : 3))
            } else { Issue.record("Expected multipart chunk") }
            let json = index == 1 ? #"{"error_code":0,"chunkNo":1}"# : #"""
                {"error_code":"0","chunkNo":"2","picId":"fixture_pic","picInfo":{"originPic":{"width":640,"height":480}}}
                """#
            try await client.succeed(call.id, with: .init(
                statusCode: 200, headers: ["content-type": "application/x-javascript"],
                body: Data(json.utf8)))
        }
        #expect(try await task.value.token == "#(pic,fixture_pic,640,480)")
        #expect(await client.pendingCalls().isEmpty)
    }

    @Test func serverFailureStopsBeforeNextChunkWithoutAutomaticRetry() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("r10-failure.bin")
        try Data(repeating: 42, count: 512_003).write(to: url)
        let photo = ComposerPhoto(id: "failed", file: .init(url: url), width: 1, height: 1, byteCount: 512_003)
        let client = HarnessMockHTTPClient()
        let auth = SessionAuthContextProvider()
        auth.install(try #require(SessionCredential(bduss: "fixture-session", stoken: "fixture-token")))
        let uploader = LiveComposerImageUploader(client: client, authContextProvider: auth)
        let task = Task { try await uploader.upload(photo, forumName: "样本", context: auth.context(), progress: { _ in }) }
        try await client.waitForPendingCallCount(1)
        let call = try #require(await client.pendingCalls().first)
        try await client.succeed(call.id, with: .init(
                statusCode: 200, headers: ["content-type": "application/json"],
                body: Data(#"{"error_code":"40","chunkNo":"1"}"#.utf8)))
        await #expect(throws: ImageUploadFailure.server(40)) { try await task.value }
        #expect(await client.pendingCalls().isEmpty)
    }
}
