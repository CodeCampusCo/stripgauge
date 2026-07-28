import Foundation

/// How close a window is to its limit. Drives the text colour only.
public enum Severity: Sendable, Equatable {
    case normal
    case warning
    case alert

    public static func of(_ percent: Double?) -> Severity {
        guard let percent else { return .normal }
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

    public static func rows(_ state: GaugeState) -> (top: String, bottom: String) {
        (row("5h", state.fiveHourPercent), row("7d", state.sevenDayPercent))
    }

    private static func row(_ prefix: String, _ percent: Double?) -> String {
        guard let percent else { return "\(prefix) \(placeholder)" }
        return "\(prefix) \(Int(percent.rounded()))%"
    }

    /// One line for the terminal status line, where width is not scarce.
    public static func statusline(_ state: GaugeState, contextPercent: Double?) -> String {
        var parts = [
            "5h " + percent(state.fiveHourPercent),
            "7d " + percent(state.sevenDayPercent),
        ]
        if let contextPercent {
            parts.append("ctx " + percent(contextPercent))
        }
        return parts.joined(separator: " · ")
    }

    private static func percent(_ value: Double?) -> String {
        guard let value else { return placeholder }
        return "\(Int(value.rounded()))%"
    }
}
