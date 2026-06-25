import Foundation

// MARK: - tRPC Client

actor TRPCClient {
    static let shared = TRPCClient()
    private let baseURL = URL(string: "https://prod.clipstake.com/api/trpc")!
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest  = 30
        config.timeoutIntervalForResource = 60
        session = URLSession(configuration: config)
    }

    // MARK: - Public

    func query<T: Decodable>(_ path: String, input: (some Encodable)? = nil as String?) async throws -> T {
        try await request(path: path, input: input)
    }

    func query<T: Decodable>(_ path: String) async throws -> T {
        try await request(path: path, input: nil as String?)
    }

    func mutate<T: Decodable>(_ path: String, input: (some Encodable)? = nil as String?) async throws -> T {
        try await request(path: path, input: input)
    }

    func mutate<T: Decodable>(_ path: String) async throws -> T {
        try await request(path: path, input: nil as String?)
    }

    // MARK: - Core

    private func request<I: Encodable, T: Decodable>(path: String, input: I?) async throws -> T {
        let url = baseURL.appendingPathComponent(path)

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("clipstake://", forHTTPHeaderField: "expo-origin")
        req.setValue("swift-native", forHTTPHeaderField: "x-trpc-source")

        if let cookie = KeychainHelper.get(KeychainHelper.sessionCookieKey) {
            req.setValue(cookie, forHTTPHeaderField: "Cookie")
        }

        // Encode body: {"0": {"json": <input>}}
        let body = TRPCRequestBody(input: input)
        req.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: req)

        if let http = response as? HTTPURLResponse, http.statusCode == 401 {
            throw AppError.unauthorized
        }

        return try decodeResponse(data: data)
    }

    // MARK: - Decode tRPC envelope

    private func decodeResponse<T: Decodable>(data: Data) throws -> T {
        // tRPC response: [{"result":{"data":{"json":<T>}}}]
        // or error:      [{"error":{"json":{"code":...,"message":...}}}]
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            let formats: [ISO8601DateFormatter] = [
                {
                    let f = ISO8601DateFormatter()
                    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    return f
                }(),
                ISO8601DateFormatter()
            ]
            for f in formats {
                if let date = f.date(from: str) { return date }
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(str)")
        }

        // Try array envelope first
        if let envelope = try? decoder.decode([TRPCResponseEnvelope<T>].self, from: data),
           let first = envelope.first {
            if let error = first.error {
                throw mapTRPCError(error)
            }
            if let result = first.result?.data?.json {
                return result
            }
        }

        // Try single envelope
        if let envelope = try? decoder.decode(TRPCResponseEnvelope<T>.self, from: data) {
            if let error = envelope.error {
                throw mapTRPCError(error)
            }
            if let result = envelope.result?.data?.json {
                return result
            }
        }

        throw AppError.unknown(NSError(domain: "TRPCClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not decode response"]))
    }

    private func mapTRPCError(_ error: TRPCError) -> AppError {
        let code = error.json.code ?? ""
        let message = error.json.message ?? "Unknown error"
        if message.lowercased().contains("submission_video_id_uniq") ||
           message.lowercased().contains("duplicate") {
            return .duplicate
        }
        if code == "UNAUTHORIZED" { return .unauthorized }
        return .trpc(code: code, message: message)
    }
}

// MARK: - Request Envelope

private struct TRPCRequestBody<I: Encodable>: Encodable {
    let input: I?

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicKey.self)
        if let input {
            var inner = container.nestedContainer(keyedBy: DynamicKey.self, forKey: DynamicKey("0"))
            try inner.encode(input, forKey: DynamicKey("json"))
        } else {
            var inner = container.nestedContainer(keyedBy: DynamicKey.self, forKey: DynamicKey("0"))
            try inner.encodeNil(forKey: DynamicKey("json"))
        }
    }
}

// MARK: - Response Envelope

private struct TRPCResponseEnvelope<T: Decodable>: Decodable {
    let result: TRPCResult<T>?
    let error: TRPCError?
}

private struct TRPCResult<T: Decodable>: Decodable {
    let data: TRPCData<T>?
}

private struct TRPCData<T: Decodable>: Decodable {
    let json: T?
}

private struct TRPCError: Decodable {
    let json: TRPCErrorDetail
}

private struct TRPCErrorDetail: Decodable {
    let code: String?
    let message: String?
    let httpStatus: Int?
}

// MARK: - Dynamic Coding Keys

private struct DynamicKey: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }
    init(_ string: String) { self.stringValue = string }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}
