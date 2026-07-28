import Foundation

/// One rate-limit window as some session last observed it.
///
/// `resetsAt` is what makes two observations comparable. A percentage on its own
/// is meaningless across sessions: each session reports the numbers from *its*
/// last API response, so an idle session keeps republishing a percentage for a
/// window that has already rolled over.
public struct WindowReading: Codable, Equatable, Sendable {
    public var percent: Double?
    public var resetsAt: Int?

    public init(percent: Double? = nil, resetsAt: Int? = nil) {
        self.percent = percent
        self.resetsAt = resetsAt
    }

    public static let unknown = WindowReading()

    public var isEmpty: Bool { percent == nil }

    /// True once the window this was measured in has ended. Such a reading says
    /// nothing about the window we are in now.
    public func hasExpired(now: Int) -> Bool {
        guard let resetsAt else { return false }
        return resetsAt <= now
    }

    /// The percentage to show, or nil when the reading is missing or belongs to
    /// a window that has already ended.
    public func livePercent(now: Int) -> Double? {
        hasExpired(now: now) ? nil : percent
    }

    /// Picks between an incoming observation and the stored one.
    ///
    /// Expired readings lose outright. Otherwise the later window wins, because
    /// it is the one we are in; within the same window the larger percentage
    /// wins, because usage only accumulates until the window resets.
    public static func preferred(_ incoming: WindowReading, over stored: WindowReading, now: Int) -> WindowReading {
        let candidates = [incoming, stored].filter { !$0.isEmpty && !$0.hasExpired(now: now) }
        guard let first = candidates.first else { return .unknown }
        guard candidates.count > 1 else { return first }

        if (incoming.resetsAt ?? 0) != (stored.resetsAt ?? 0) {
            return (incoming.resetsAt ?? 0) > (stored.resetsAt ?? 0) ? incoming : stored
        }
        return (incoming.percent ?? 0) >= (stored.percent ?? 0) ? incoming : stored
    }
}

/// What the statusline hook hands to the Touch Bar process.
public struct GaugeState: Codable, Equatable, Sendable {
    public var fiveHour: WindowReading
    public var sevenDay: WindowReading

    /// Whole epoch seconds. JSON integers round-trip exactly on every Foundation
    /// version, which a floating-point timestamp does not, and a staleness window
    /// measured in tens of seconds has no use for the fraction.
    public var updatedAt: Int

    public init(fiveHour: WindowReading, sevenDay: WindowReading, updatedAt: Date) {
        self.fiveHour = fiveHour
        self.sevenDay = sevenDay
        self.updatedAt = Int(updatedAt.timeIntervalSince1970)
    }

    /// Considered gone once nothing has written for this long. Must stay
    /// comfortably above the statusLine `refreshInterval`, or an idle-but-open
    /// session looks like a closed one.
    public static let staleAfter = 30

    public func isStale(now: Date = Date()) -> Bool {
        Int(now.timeIntervalSince1970) - updatedAt > Self.staleAfter
    }

    /// The percentages worth showing right now.
    public func live(now: Date = Date()) -> (fiveHour: Double?, sevenDay: Double?) {
        let seconds = Int(now.timeIntervalSince1970)
        return (fiveHour.livePercent(now: seconds), sevenDay.livePercent(now: seconds))
    }

    /// The window closest to its limit — what the colour should reflect.
    public func worstPercent(now: Date = Date()) -> Double? {
        let current = live(now: now)
        return [current.fiveHour, current.sevenDay].compactMap { $0 }.max()
    }

    /// Combines this observation with what is already on disk, one window at a
    /// time. A session that has not called the API yet reports nothing and must
    /// not blank numbers another session published; a session left open for hours
    /// reports a dead window and must not overwrite the live one.
    public func merged(over previous: GaugeState?, now: Date = Date()) -> GaugeState {
        guard let previous, !previous.isStale(now: now) else { return self }
        let seconds = Int(now.timeIntervalSince1970)
        var merged = self
        merged.fiveHour = .preferred(fiveHour, over: previous.fiveHour, now: seconds)
        merged.sevenDay = .preferred(sevenDay, over: previous.sevenDay, now: seconds)
        return merged
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
    public static func write(_ state: GaugeState) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try encode(state).write(to: file, options: .atomic)
    }

    public static func read() throws -> GaugeState {
        try decode(try Data(contentsOf: file))
    }
}
