import Foundation

struct EndpointID: Equatable, Hashable, Sendable {
    let rawValue: String

    init?(_ rawValue: String) {
        guard (1...64).contains(rawValue.utf8.count),
              rawValue.utf8.allSatisfy(Self.isSafeSymbolByte) else {
            return nil
        }
        self.rawValue = rawValue
    }

    private static func isSafeSymbolByte(_ byte: UInt8) -> Bool {
        switch byte {
        case 45, 46, 48...57, 65...90, 95, 97...122:
            true
        default:
            false
        }
    }
}

struct EndpointField: Equatable, Sendable {
    let name: String
    let value: String
}

enum EndpointBodyCodec: Equatable, Sendable {
    case formURLEncoded
    case multipartBinary
    case none
}

enum EndpointResponseFamily: Equatable, Sendable {
    case empty
    case json
    case protobuf
}

enum EndpointRetryPolicy: Equatable, Sendable {
    case never
}

enum EndpointDescriptorValidationError: Error, Equatable, Sendable {
    case invalidHost
    case invalidMIMEType
    case invalidPath
    case invalidPort
    case invalidResponseBodyLimit
    case invalidTimeout
}

struct EndpointDescriptor: Equatable, Sendable {
    let id: EndpointID
    let method: HTTPMethod
    let host: String
    let port: Int?
    let path: String
    let queryItems: [EndpointField]
    let bodyCodec: EndpointBodyCodec
    let responseFamily: EndpointResponseFamily
    let allowedResponseMIMETypes: [String]
    let authentication: EndpointAuthenticationRequirement
    let timeout: TimeInterval
    let responseBodyLimit: Int
    let redirectPolicy: HTTPRedirectPolicy
    let retryPolicy: EndpointRetryPolicy

    init(
        id: EndpointID,
        method: HTTPMethod,
        host: String,
        port: Int? = nil,
        path: String,
        queryItems: [EndpointField] = [],
        bodyCodec: EndpointBodyCodec,
        responseFamily: EndpointResponseFamily,
        allowedResponseMIMETypes: [String],
        authentication: EndpointAuthenticationRequirement,
        timeout: TimeInterval,
        responseBodyLimit: Int,
        redirectPolicy: HTTPRedirectPolicy = .reject,
        retryPolicy: EndpointRetryPolicy = .never
    ) throws {
        let normalizedHost = host.lowercased()
        guard Self.isValidHost(normalizedHost) else {
            throw EndpointDescriptorValidationError.invalidHost
        }
        if let port, !(1...65_535).contains(port) {
            throw EndpointDescriptorValidationError.invalidPort
        }
        guard Self.isValidPath(path) else {
            throw EndpointDescriptorValidationError.invalidPath
        }
        guard timeout.isFinite, timeout > 0 else {
            throw EndpointDescriptorValidationError.invalidTimeout
        }
        guard responseBodyLimit > 0 else {
            throw EndpointDescriptorValidationError.invalidResponseBodyLimit
        }

        let normalizedMIMETypes = allowedResponseMIMETypes.map {
            $0.lowercased()
        }
        let needsMIMEType = responseFamily != .empty
        guard !needsMIMEType || !normalizedMIMETypes.isEmpty,
              normalizedMIMETypes.allSatisfy(Self.isValidMIMEType) else {
            throw EndpointDescriptorValidationError.invalidMIMEType
        }

        self.id = id
        self.method = method
        self.host = normalizedHost
        self.port = port
        self.path = path
        self.queryItems = queryItems
        self.bodyCodec = bodyCodec
        self.responseFamily = responseFamily
        self.allowedResponseMIMETypes = Array(
            Set(normalizedMIMETypes)
        ).sorted()
        self.authentication = authentication
        self.timeout = timeout
        self.responseBodyLimit = responseBodyLimit
        self.redirectPolicy = redirectPolicy
        self.retryPolicy = retryPolicy
    }

    private static func isValidHost(_ host: String) -> Bool {
        guard !host.isEmpty,
              !host.hasPrefix("."),
              !host.hasSuffix("."),
              !host.contains("..") else {
            return false
        }
        return host.utf8.allSatisfy { byte in
            switch byte {
            case 45, 46, 48...57, 97...122:
                true
            default:
                false
            }
        }
    }

    private static func isValidPath(_ path: String) -> Bool {
        guard path.hasPrefix("/"),
              !path.contains("//"),
              !path.contains("?"),
              !path.contains("#"),
              !path.contains("\\"),
              path.utf8.allSatisfy(Self.isSafePathByte) else {
            return false
        }
        return path.split(separator: "/", omittingEmptySubsequences: false)
            .allSatisfy { segment in
                segment != "." && segment != ".."
            }
    }

    private static func isSafePathByte(_ byte: UInt8) -> Bool {
        switch byte {
        case 45, 46, 47, 48...57, 65...90, 95, 97...122, 126:
            true
        default:
            false
        }
    }

    private static func isValidMIMEType(_ mimeType: String) -> Bool {
        guard !mimeType.isEmpty,
              !mimeType.contains(";"),
              !mimeType.contains(where: { $0.isWhitespace }) else {
            return false
        }
        let components = mimeType.split(separator: "/", omittingEmptySubsequences: false)
        return components.count == 2 && components.allSatisfy { !$0.isEmpty }
    }
}
