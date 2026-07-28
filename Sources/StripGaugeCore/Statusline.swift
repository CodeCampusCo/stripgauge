import Foundation

/// The slice of Claude Code's statusLine payload this tool needs. Everything is
/// optional: fields appear and disappear depending on plan, session age, and
/// Claude Code version, and a missing field must never be an error.
public struct StatuslineInput: Decodable, Sendable {
    public struct Window: Decodable, Sendable {
        public let usedPercentage: Double?
    }

    public struct RateLimits: Decodable, Sendable {
        public let fiveHour: Window?
        public let sevenDay: Window?
    }

    public struct ContextWindow: Decodable, Sendable {
        public let usedPercentage: Double?
    }

    public let rateLimits: RateLimits?
    public let contextWindow: ContextWindow?

    public static func decode(_ data: Data) throws -> StatuslineInput {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(StatuslineInput.self, from: data)
    }

    public var contextPercent: Double? {
        contextWindow?.usedPercentage
    }

    public func state(at now: Date = Date()) -> GaugeState {
        GaugeState(
            fiveHourPercent: rateLimits?.fiveHour?.usedPercentage,
            sevenDayPercent: rateLimits?.sevenDay?.usedPercentage,
            updatedAt: now
        )
    }
}
