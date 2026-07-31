import Foundation

struct MultipartBinaryPart: Equatable, Sendable {
    let name: String
    let filename: String
    let mimeType: String?
    let data: Data
}

enum EndpointRequestBody: Equatable, Sendable {
    case formURLEncoded([EndpointField])
    case multipartBinary(
        boundary: String,
        fields: [EndpointField],
        part: MultipartBinaryPart
    )
    case none
}

enum EndpointRequestBuilderError: Error, Equatable, Sendable {
    case bodyCodecMismatch
    case headerCollision
    case invalidBoundary
    case invalidBoundaryCollision
    case invalidFieldName
    case invalidMultipartMetadata
    case invalidURL
    case reservedHeader
}

struct EndpointRequestBuilder: Sendable {
    private let authorizer: any RequestAuthorizing

    init(authorizer: any RequestAuthorizing) {
        self.authorizer = authorizer
    }

    func makeRequest(
        endpoint: EndpointDescriptor,
        authentication: AuthContext,
        body: EndpointRequestBody
    ) async throws -> HTTPRequest {
        try Task.checkCancellation()
        let encodedBody = try Self.encode(body, codec: endpoint.bodyCodec)
        let url = try Self.makeURL(for: endpoint)
        let authorizationHeaders = try await authorizer.headers(
            for: authentication,
            endpoint: endpoint
        )
        try Task.checkCancellation()
        guard authorizationHeaders.keys.allSatisfy({ headerName in
            !Self.reservedHeaders.contains(headerName.lowercased())
        }) else {
            throw EndpointRequestBuilderError.reservedHeader
        }

        var headers = endpoint.fixedHeaders
        let fixedHeaderNames = Set(headers.keys.map { $0.lowercased() })
        let authorizationHeaderNames = authorizationHeaders.keys.map {
            $0.lowercased()
        }
        guard Set(authorizationHeaderNames).count == authorizationHeaders.count,
              authorizationHeaderNames.allSatisfy({ name in
                  !fixedHeaderNames.contains(name)
              }) else {
            throw EndpointRequestBuilderError.headerCollision
        }
        for (name, value) in authorizationHeaders {
            headers[name] = value
        }
        if !endpoint.allowedResponseMIMETypes.isEmpty {
            headers["Accept"] = endpoint.allowedResponseMIMETypes.joined(
                separator: ", "
            )
        }
        if let contentType = encodedBody.contentType {
            headers["Content-Type"] = contentType
        }

        return try HTTPRequest(
            method: endpoint.method,
            url: url,
            headers: headers,
            body: encodedBody.data,
            timeout: endpoint.timeout,
            responseBodyLimit: endpoint.responseBodyLimit,
            redirectPolicy: endpoint.redirectPolicy
        )
    }

    private static let reservedHeaders: Set<String> = [
        "accept",
        "content-length",
        "content-type",
        "host"
    ]

    private static func makeURL(for endpoint: EndpointDescriptor) throws -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = endpoint.host
        components.port = endpoint.port
        components.percentEncodedPath = endpoint.path
        if !endpoint.queryItems.isEmpty {
            components.percentEncodedQuery = try encodeFields(
                endpoint.queryItems,
                spaceAsPlus: false
            )
        }
        guard let url = components.url else {
            throw EndpointRequestBuilderError.invalidURL
        }
        return url
    }

    private static func encode(
        _ body: EndpointRequestBody,
        codec: EndpointBodyCodec
    ) throws -> (data: Data?, contentType: String?) {
        switch (body, codec) {
        case (.none, .none):
            return (nil, nil)
        case let (.formURLEncoded(fields), .formURLEncoded):
            return (
                Data(try encodeFields(fields, spaceAsPlus: true).utf8),
                "application/x-www-form-urlencoded"
            )
        case let (
            .multipartBinary(boundary, fields, part),
            .multipartBinary
        ):
            return (
                try encodeMultipart(
                    boundary: boundary,
                    fields: fields,
                    part: part
                ),
                "multipart/form-data; boundary=\(boundary)"
            )
        default:
            throw EndpointRequestBuilderError.bodyCodecMismatch
        }
    }

    private static func encodeFields(
        _ fields: [EndpointField],
        spaceAsPlus: Bool
    ) throws -> String {
        for field in fields where field.name.isEmpty {
            throw EndpointRequestBuilderError.invalidFieldName
        }
        return fields.sorted(by: fieldOrdering).map { field in
            let name = percentEncode(field.name, spaceAsPlus: spaceAsPlus)
            let value = percentEncode(field.value, spaceAsPlus: spaceAsPlus)
            return "\(name)=\(value)"
        }
        .joined(separator: "&")
    }

    private static func fieldOrdering(
        _ lhs: EndpointField,
        _ rhs: EndpointField
    ) -> Bool {
        if lhs.name == rhs.name {
            return lhs.value < rhs.value
        }
        return lhs.name < rhs.name
    }

    private static func percentEncode(
        _ value: String,
        spaceAsPlus: Bool
    ) -> String {
        let hex = Array("0123456789ABCDEF".utf8)
        var encoded = ""
        encoded.reserveCapacity(value.utf8.count)

        for byte in value.utf8 {
            switch byte {
            case 45, 46, 48...57, 65...90, 95, 97...122, 126:
                encoded.unicodeScalars.append(UnicodeScalar(byte))
            case 32 where spaceAsPlus:
                encoded.append("+")
            default:
                encoded.append("%")
                encoded.unicodeScalars.append(UnicodeScalar(hex[Int(byte >> 4)]))
                encoded.unicodeScalars.append(UnicodeScalar(hex[Int(byte & 0x0F)]))
            }
        }
        return encoded
    }

    private static func encodeMultipart(
        boundary: String,
        fields: [EndpointField],
        part: MultipartBinaryPart
    ) throws -> Data {
        guard (1...70).contains(boundary.utf8.count),
              boundary.utf8.allSatisfy(isSafeBoundaryByte) else {
            throw EndpointRequestBuilderError.invalidBoundary
        }
        guard isSafeHeaderParameter(part.name),
              isSafeHeaderParameter(part.filename),
              part.mimeType.map(isSafeMIMEType) ?? true,
              fields.allSatisfy({ isSafeHeaderParameter($0.name) }) else {
            throw EndpointRequestBuilderError.invalidMultipartMetadata
        }
        let boundaryBytes = Data(boundary.utf8)
        guard fields.allSatisfy({
            Data($0.value.utf8).range(of: boundaryBytes) == nil
        }),
        part.data.range(of: boundaryBytes) == nil else {
            throw EndpointRequestBuilderError.invalidBoundaryCollision
        }

        var data = Data()
        for field in fields.sorted(by: fieldOrdering) {
            data.append(Data("--\(boundary)\r\n".utf8))
            data.append(
                Data(
                    (
                        "Content-Disposition: form-data; " +
                            "name=\"\(field.name)\"\r\n\r\n"
                    ).utf8
                )
            )
            data.append(Data(field.value.utf8))
            data.append(Data("\r\n".utf8))
        }

        data.append(Data("--\(boundary)\r\n".utf8))
        data.append(
            Data(
                (
                    "Content-Disposition: form-data; name=\"\(part.name)\"; " +
                        "filename=\"\(part.filename)\"\r\n"
                ).utf8
            )
        )
        if let mimeType = part.mimeType {
            data.append(Data("Content-Type: \(mimeType)\r\n".utf8))
        }
        data.append(Data("\r\n".utf8))
        data.append(part.data)
        data.append(Data("\r\n--\(boundary)--\r\n".utf8))
        return data
    }

    private static func isSafeBoundaryByte(_ byte: UInt8) -> Bool {
        switch byte {
        case 42, 45, 46, 48...57, 65...90, 95, 97...122:
            true
        default:
            false
        }
    }

    private static func isSafeHeaderParameter(_ value: String) -> Bool {
        guard !value.isEmpty else {
            return false
        }
        return value.utf8.allSatisfy { byte in
            switch byte {
            case 45, 46, 48...57, 65...90, 95, 97...122:
                true
            default:
                false
            }
        }
    }

    private static func isSafeMIMEType(_ value: String) -> Bool {
        let components = value.split(
            separator: "/",
            omittingEmptySubsequences: false
        )
        guard components.count == 2 else {
            return false
        }
        return components.allSatisfy { component in
            !component.isEmpty && component.utf8.allSatisfy { byte in
                switch byte {
                case 43, 45, 46, 48...57, 65...90, 94, 95, 97...122:
                    true
                default:
                    false
                }
            }
        }
    }
}
