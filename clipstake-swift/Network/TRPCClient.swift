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
        try await getRequest(path: path, input: input)
    }

    func query<T: Decodable>(_ path: String) async throws -> T {
        try await getRequest(path: path, input: nil as String?)
    }

    func mutate<T: Decodable>(_ path: String, input: (some Encodable)? = nil as String?) async throws -> T {
        try await postRequest(path: path, input: input)
    }

    func mutate<T: Decodable>(_ path: String) async throws -> T {
        try await postRequest(path: path, input: nil as String?)
    }

    // MARK: - GET (queries)
    // tRPC queries: GET /api/trpc/<path>?batch=1&input={"0":{"json":<input>}}

    private func getRequest<I: Encodable, T: Decodable>(path: String, input: I?) async throws -> T {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!

        // Build input wrapper
        let inputWrapper: [String: TRPCInputWrapper<I>] = ["0": TRPCInputWrapper(json: input)]
        let inputData = try JSONEncoder().encode(inputWrapper)
        let inputStr = String(data: inputData, encoding: .utf8) ?? "{}"

        components.queryItems = [
            URLQueryItem(name: "batch", value: "1"),
            URLQueryItem(name: "input", value: inputStr)
        ]

        var req = URLRequest(url: components.url!)
        req.httpMethod = "GET"
        addHeaders(to: &req)

        let (data, response) = try await session.data(for: req)

        #if DEBUG
        print("[tRPC GET] \(path)")
        print("[tRPC RSP] \(String(data: data, encoding: .utf8) ?? "<binary>")")
        #endif

        if let http = response as? HTTPURLResponse, http.statusCode == 401 {
            throw AppError.unauthorized
        }

        return try decodeResponse(data: data)
    }

    // MARK: - POST (mutations)
    // tRPC mutations: POST /api/trpc/<path>?batch=1  body: {"0":{"json":<input>}}

    private func postRequest<I: Encodable, T: Decodable>(path: String, input: I?) async throws -> T {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "batch", value: "1")]

        var req = URLRequest(url: components.url!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addHeaders(to: &req)

        let inputWrapper: [String: TRPCInputWrapper<I>] = ["0": TRPCInputWrapper(json: input)]
        req.httpBody = try JSONEncoder().encode(inputWrapper)

        let (data, response) = try await session.data(for: req)

        #if DEBUG
        print("[tRPC POST] \(path)")
        print("[tRPC RSP]  \(String(data: data, encoding: .utf8) ?? "<binary>")")
        #endif

        if let http = response as? HTTPURLResponse, http.statusCode == 401 {
            throw AppError.unauthorized
        }

        return try decodeResponse(data: data)
    }

    // MARK: - Headers

    private func addHeaders(to req: inout URLRequest) {
        req.setValue("clipstake://", forHTTPHeaderField: "expo-origin")
        req.setValue("swift-native", forHTTPHeaderField: "x-trpc-source")
        if let cookie = KeychainHelper.get(KeychainHelper.sessionCookieKey) {
            req.setValue(cookie, forHTTPHeaderField: "Cookie")
        }
    }

    // MARK: - Decode tRPC envelope
    // Response: [{"result":{"data":{"json":<T>}}}]

    private func decodeResponse<T: Decodable>(data: Data) throws -> T {
        let decoder = JSONDecoder()

        // Try array envelope (batch=1 always returns array)
        if let envelope = try? decoder.decode([TRPCResponseEnvelope<T>].self, from: data),
           let first = envelope.first {
            if let error = first.error {
                throw mapTRPCError(error)
            }
            if let result = first.result?.data?.json {
                return result
            }
        }

        // Fallback: single envelope
        if let envelope = try? decoder.decode(TRPCResponseEnvelope<T>.self, from: data) {
            if let error = envelope.error {
                throw mapTRPCError(error)
            }
            if let result = envelope.result?.data?.json {
                return result
            }
        }

        throw AppError.unknown(NSError(
            domain: "TRPCClient",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Could not decode response"]
        ))
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

// MARK: - Input Wrapper

private struct TRPCInputWrapper<I: Encodable>: Encodable {
    let json: I?
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
