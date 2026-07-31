import Foundation
import Testing

struct FixtureLoaderTests {
    private struct SamplePayload: Decodable, Equatable, Sendable {
        let name: String
        let items: [Int]
    }

    @Test
    func loadsJSONOpaqueProtobufAndImageFixtures() throws {
        let loader = try makeLoader()

        let payload = try loader.decodeJSON(
            SamplePayload.self,
            id: FixtureID("json.success")
        )
        #expect(payload == SamplePayload(name: "synthetic", items: [1, 2]))

        let binary = try loader.loadData(
            id: FixtureID("protobuf.opaque"),
            expectedFormat: .protobuf
        )
        #expect(!binary.isEmpty)

        let image = try loader.loadData(
            id: FixtureID("image.pixel"),
            expectedFormat: .image
        )
        #expect(String(bytes: image.prefix(4), encoding: .utf8) == "<svg")
    }

    @Test
    func missingAndMalformedFixturesExposeOnlyLogicalPaths() throws {
        let loader = try makeLoader()
        let root = loader.rootDirectory.path

        do {
            _ = try loader.loadData(
                id: FixtureID("json.missing"),
                expectedFormat: .json
            )
            Issue.record("Expected missing fixture failure")
        } catch let error as FixtureLoaderError {
            #expect(error.safeDescription.contains("JSON/missing.json"))
            #expect(!error.safeDescription.contains(root))
        }

        do {
            _ = try loader.decodeJSON(
                SamplePayload.self,
                id: FixtureID("json.malformed")
            )
            Issue.record("Expected malformed fixture failure")
        } catch let error as FixtureLoaderError {
            #expect(error.safeDescription.contains("JSON/malformed.json"))
            #expect(!error.safeDescription.contains(root))
        }
    }

    @Test
    func rejectsHashMismatchDuplicateIDsAndPathTraversal() throws {
        let loader = try makeLoader()

        do {
            _ = try loader.loadData(
                id: FixtureID("text.hash-mismatch"),
                expectedFormat: .binary
            )
            Issue.record("Expected fixture hash mismatch")
        } catch let error as FixtureLoaderError {
            #expect(error.category == .hashMismatch)
        }

        let entry = FixtureManifestEntry(
            id: FixtureID("duplicate"),
            relativePath: "JSON/success.json",
            format: .json,
            sha256: String(repeating: "0", count: 64),
            source: .synthetic,
            purpose: "duplicate validation",
            sanitized: true
        )
        do {
            _ = try FixtureCatalog(entries: [entry, entry])
            Issue.record("Expected duplicate fixture ID rejection")
        } catch let error as FixtureLoaderError {
            #expect(error.category == .duplicateID)
        }

        let traversal = FixtureManifestEntry(
            id: FixtureID("traversal"),
            relativePath: "../outside.json",
            format: .json,
            sha256: String(repeating: "0", count: 64),
            source: .synthetic,
            purpose: "path validation",
            sanitized: true
        )
        do {
            _ = try FixtureCatalog(entries: [traversal])
            Issue.record("Expected fixture path traversal rejection")
        } catch let error as FixtureLoaderError {
            #expect(error.category == .invalidPath)
            #expect(!error.safeDescription.contains("outside.json"))
        }
    }

    @Test
    func unknownFixtureIDIsNotEchoedIntoFailureText() throws {
        let loader = try makeLoader()
        let privateCanary = ["private", "fixture", "identifier"].joined(separator: "-")

        do {
            _ = try loader.loadData(
                id: FixtureID(privateCanary),
                expectedFormat: .json
            )
            Issue.record("Expected unknown fixture ID rejection")
        } catch let error as FixtureLoaderError {
            #expect(error.category == .unknownID)
            #expect(error.logicalPath == "fixture-id")
            #expect(!error.safeDescription.contains(privateCanary))
        }
    }

    private func makeLoader() throws -> FixtureLoader {
        let bundle = Bundle(for: FixtureBundleMarker.self)
        let root = try #require(
            bundle.url(forResource: "Fixtures", withExtension: nil)
        )
        return try FixtureLoader(rootDirectory: root)
    }
}
