import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

protocol CrossPromoTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

struct URLSessionCrossPromoTransport: CrossPromoTransport {
    private let session: URLSession

    init(timeout: TimeInterval) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout * 2
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: configuration)
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw CrossPromoError.invalidResponse
            }
            return (data, httpResponse)
        } catch let error as CrossPromoError {
            throw error
        } catch {
            throw CrossPromoError.transport(error.localizedDescription)
        }
    }
}

enum CrossPromoCoding {
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    /// Timestamps arrive from a Node backend, where `toISOString()` always includes
    /// milliseconds ("2026-07-31T00:37:25.742Z"). `JSONDecoder.dateDecodingStrategy
    /// .iso8601` uses `.withInternetDateTime` only, which REJECTS fractional seconds
    /// on Apple's Foundation — so every session response failed to decode and the SDK
    /// could never establish a session. Accept both shapes.
    // `nonisolated(unsafe)` because ISO8601DateFormatter is not marked Sendable, but is
    // documented as safe to use concurrently for parsing, and these are configured once
    // here and never mutated afterwards.
    private nonisolated(unsafe) static let iso8601WithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private nonisolated(unsafe) static let iso8601Whole: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            if let date = iso8601WithFractionalSeconds.date(from: text)
                ?? iso8601Whole.date(from: text) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected an ISO-8601 date, got \(text)"
            )
        }
        return decoder
    }()
}
