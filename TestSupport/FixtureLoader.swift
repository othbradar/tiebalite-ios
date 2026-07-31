import CryptoKit
import Foundation

final class FixtureBundleMarker: NSObject {}

struct FixtureID: Hashable, Codable, Sendable {
    let rawValue: String

    init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        rawValue = try container.decode(String.self)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

enum FixtureFormat: String, Codable, Equatable, Sendable {
    case binary
    case image
    case json
    case protobuf
}

enum FixtureSource: String, Codable, Equatable, Sendable {
    case synthetic
}

struct FixtureManifestEntry: Codable, Equatable, Sendable {
    let id: FixtureID
    let relativePath: String
    let format: FixtureFormat
    let sha256: String
    let source: FixtureSource
    let purpose: String
    let sanitized: Bool

    enum CodingKeys: String, CodingKey {
        case format
        case id
        case relativePath = "path"
        case purpose
        case sanitized
        case sha256
        case source
    }
}

private struct FixtureManifestDocument: Decodable {
    let entries: [FixtureManifestEntry]
    let schemaVersion: Int
}

enum FixtureLoaderErrorCategory: Equatable, Sendable {
    case duplicateID
    case formatMismatch
    case hashMismatch
    case invalidManifest
    case invalidPath
    case malformed
    case missing
    case unknownID
}

struct FixtureLoaderError: Error, Equatable, Sendable {
    let category: FixtureLoaderErrorCategory
    let logicalPath: String

    var safeDescription: String {
        "\(category.safeName): \(logicalPath)"
    }
}

struct FixtureCatalog: Sendable {
    private let entriesByID: [FixtureID: FixtureManifestEntry]

    init(entries: [FixtureManifestEntry]) throws {
        var entriesByID: [FixtureID: FixtureManifestEntry] = [:]
        for entry in entries {
            guard Self.isSafeRelativePath(entry.relativePath) else {
                throw FixtureLoaderError(
                    category: .invalidPath,
                    logicalPath: "manifest-entry"
                )
            }
            guard entry.sanitized else {
                throw FixtureLoaderError(
                    category: .invalidManifest,
                    logicalPath: "manifest-entry"
                )
            }
            guard entriesByID[entry.id] == nil else {
                throw FixtureLoaderError(
                    category: .duplicateID,
                    logicalPath: "manifest-entry"
                )
            }
            entriesByID[entry.id] = entry
        }
        self.entriesByID = entriesByID
    }

    func entry(for id: FixtureID) throws -> FixtureManifestEntry {
        guard let entry = entriesByID[id] else {
            throw FixtureLoaderError(
                category: .unknownID,
                logicalPath: "fixture-id"
            )
        }
        return entry
    }

    private static func isSafeRelativePath(_ path: String) -> Bool {
        guard !path.isEmpty, !path.hasPrefix("/") else {
            return false
        }
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        return components.allSatisfy { component in
            !component.isEmpty && component != "." && component != ".."
        }
    }
}

struct FixtureLoader: Sendable {
    let rootDirectory: URL
    private let catalog: FixtureCatalog

    init(rootDirectory: URL) throws {
        self.rootDirectory = rootDirectory
        let manifestURL = rootDirectory.appendingPathComponent("manifest.json")
        let manifestData: Data
        do {
            manifestData = try Data(contentsOf: manifestURL)
        } catch {
            throw FixtureLoaderError(
                category: .missing,
                logicalPath: "manifest.json"
            )
        }

        let document: FixtureManifestDocument
        do {
            document = try JSONDecoder().decode(
                FixtureManifestDocument.self,
                from: manifestData
            )
        } catch {
            throw FixtureLoaderError(
                category: .invalidManifest,
                logicalPath: "manifest.json"
            )
        }
        guard document.schemaVersion == 1 else {
            throw FixtureLoaderError(
                category: .invalidManifest,
                logicalPath: "manifest.json"
            )
        }
        catalog = try FixtureCatalog(entries: document.entries)
    }

    func loadData(
        id: FixtureID,
        expectedFormat: FixtureFormat
    ) throws -> Data {
        let entry = try catalog.entry(for: id)
        guard entry.format == expectedFormat else {
            throw FixtureLoaderError(
                category: .formatMismatch,
                logicalPath: entry.relativePath
            )
        }

        let fileURL = rootDirectory.appendingPathComponent(entry.relativePath)
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw FixtureLoaderError(
                category: .missing,
                logicalPath: entry.relativePath
            )
        }

        guard Self.sha256(data) == entry.sha256 else {
            throw FixtureLoaderError(
                category: .hashMismatch,
                logicalPath: entry.relativePath
            )
        }
        return data
    }

    func decodeJSON<Value: Decodable & Sendable>(
        _ type: Value.Type,
        id: FixtureID
    ) throws -> Value {
        let entry = try catalog.entry(for: id)
        let data = try loadData(id: id, expectedFormat: .json)
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw FixtureLoaderError(
                category: .malformed,
                logicalPath: entry.relativePath
            )
        }
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { byte in
            String(format: "%02x", byte)
        }
        .joined()
    }
}

private extension FixtureLoaderErrorCategory {
    var safeName: String {
        switch self {
        case .duplicateID:
            "duplicate-id"
        case .formatMismatch:
            "format-mismatch"
        case .hashMismatch:
            "hash-mismatch"
        case .invalidManifest:
            "invalid-manifest"
        case .invalidPath:
            "invalid-path"
        case .malformed:
            "malformed"
        case .missing:
            "missing"
        case .unknownID:
            "unknown-id"
        }
    }
}
