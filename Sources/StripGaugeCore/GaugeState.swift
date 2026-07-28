import Foundation

/// What the statusline hook hands to the Touch Bar process.
///
/// Both percentages are optional because Claude Code only reports rate limits
/// for Claude.ai subscribers, only after the first API response of a session,
/// and each window can be absent independently of the other.
public struct GaugeState: Codable, Equatable, Sendable {
    public var fiveHourPercent: Double?
    public var sevenDayPercent: Double?

    /// Whole epoch seconds. JSON integers round-trip exactly on every Foundation
    /// version, which a floating-point timestamp does not, and a staleness window
    /// measured in tens of seconds has no use for the fraction.
    public var updatedAt: Int

    public init(fiveHourPercent: Double?, sevenDayPercent: Double?, updatedAt: Date) {
        self.fiveHourPercent = fiveHourPercent
        self.sevenDayPercent = sevenDayPercent
        self.updatedAt = Int(updatedAt.timeIntervalSince1970)
    }

    /// Considered gone once nothing has written for this long. Must stay
    /// comfortably above the statusLine `refreshInterval`, or an idle-but-open
    /// session looks like a closed one.
    public static let staleAfter = 30

    public func isStale(now: Date = Date()) -> Bool {
        Int(now.timeIntervalSince1970) - updatedAt > Self.staleAfter
    }

    /// The window closest to its limit — what the colour should reflect.
    public var worstPercent: Double? {
        [fiveHourPercent, sevenDayPercent].compacted().max()
    }

    /// Fills gaps from what is already on disk, so a session that has not yet
    /// made an API call — and therefore reports no rate limits — refreshes the
    /// timestamp without blanking numbers another session already published.
    /// A stale previous state contributes nothing: those numbers are no longer
    /// trustworthy.
    public func merged(over previous: GaugeState?, now: Date = Date()) -> GaugeState {
        guard let previous, !previous.isStale(now: now) else { return self }
        var merged = self
        merged.fiveHourPercent = fiveHourPercent ?? previous.fiveHourPercent
        merged.sevenDayPercent = sevenDayPercent ?? previous.sevenDayPercent
        return merged
    }
}

extension Sequence {
    fileprivate func compacted<T>() -> [T] where Element == T? {
        compactMap { $0 }
    }
}

// MARK: - Storage

public enum GaugeStore {
    public static let directory = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: "Library/Application Support/stripgauge", directoryHint: .isDirectory)

    public static let file = directory.appending(path: "state.json")

    public static func encode(_ state: GaugeState) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(state)
    }

    public static func decode(_ data: Data) throws -> GaugeState {
        try JSONDecoder().decode(GaugeState.self, from: data)
    }

    /// Written atomically so a concurrent reader never sees a half-written file.
    /// Several Claude Code sessions write here; last writer wins, which is correct
    /// because these percentages are account-wide and identical across sessions.
    public static func write(_ state: GaugeState) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try encode(state).write(to: file, options: .atomic)
    }

    public static func read() throws -> GaugeState {
        try decode(try Data(contentsOf: file))
    }
}
