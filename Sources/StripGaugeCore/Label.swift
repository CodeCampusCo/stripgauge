import Foundation

/// How close a window is to its limit. Drives the text colour only.
///
/// `unknown` is distinct from `normal` on purpose: before a session's first API
/// response there is no reading at all, and showing that in the same colour as a
/// comfortable one would read as "plenty left" rather than "no idea yet".
public enum Severity: Sendable, Equatable {
    case unknown
    case normal
    case warning
    case alert

    public static func of(_ percent: Double?) -> Severity {
        guard let percent else { return .unknown }
        if percent >= 85 { return .alert }
        if percent >= 60 { return .warning }
        return .normal
    }
}

/// Text for the Control Strip slot.
///
/// The slot is 55.5 x 30 pt — measured, not guessed — which fits two rows of six
/// characters at 10 pt. "5h 100%" needs 50 pt, so the worst case still clears it.
public enum Label {
    public static let placeholder = "—"

    public static func rows(fiveHour: Double?, sevenDay: Double?) -> (top: String, bottom: String) {
        (row("5h", fiveHour), row("7d", sevenDay))
    }

    private static func row(_ prefix: String, _ percent: Double?) -> String {
        guard let percent else { return "\(prefix) \(placeholder)" }
        return "\(prefix) \(Int(percent.rounded()))%"
    }

    /// One line for the terminal status line, where width is not scarce.
    public static func statusline(fiveHour: Double?, sevenDay: Double?, context: Double?) -> String {
        var parts = ["5h " + percent(fiveHour), "7d " + percent(sevenDay)]
        if let context {
            parts.append("ctx " + percent(context))
        }
        return parts.joined(separator: " · ")
    }

    private static func percent(_ value: Double?) -> String {
        guard let value else { return placeholder }
        return "\(Int(value.rounded()))%"
    }

    /// How long until the window resets: "45m", "3h 4m", "2d 3h".
    ///
    /// Shown alongside the wall clock rather than instead of it. A countdown
    /// answers "can I keep going", the clock answers "when do I come back", and
    /// neither substitutes for the other.
    public static func remaining(_ resetsAt: Int?, now: Date = Date()) -> String? {
        guard let resetsAt else { return nil }
        let seconds = resetsAt - Int(now.timeIntervalSince1970)
        guard seconds > 0 else { return nil }

        if seconds < 3_600 { return "\(seconds / 60)m" }
        if seconds < 86_400 { return "\(seconds / 3_600)h \(seconds % 3_600 / 60)m" }
        return "\(seconds / 86_400)d \(seconds % 86_400 / 3_600)h"
    }

    /// The wall clock a window comes back at — "21:00", or "2026-07-30 21:00"
    /// once it is far enough out that the time alone would be ambiguous.
    ///
    /// Numeric throughout, deliberately. Month and weekday names come from a
    /// locale, and a calendar built without one yields ICU's root symbols: the
    /// first version of this shipped "Thu 30 M07 21:00" to the Touch Bar. ISO
    /// ordering also settles day-versus-month for good, and 24-hour time is
    /// shorter than any form carrying AM or PM.
    public static func clock(
        _ resetsAt: Int?,
        now: Date = Date(),
        timeZone: TimeZone = .current
    ) -> String? {
        guard let resetsAt, resetsAt > Int(now.timeIntervalSince1970) else { return nil }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let date = Date(timeIntervalSince1970: TimeInterval(resetsAt))
        let time = String(
            format: "%02d:%02d",
            calendar.component(.hour, from: date),
            calendar.component(.minute, from: date)
        )

        guard resetsAt - Int(now.timeIntervalSince1970) >= 86_400 else { return time }
        return String(
            format: "%04d-%02d-%02d %@",
            calendar.component(.year, from: date),
            calendar.component(.month, from: date),
            calendar.component(.day, from: date),
            time
        )
    }
}
