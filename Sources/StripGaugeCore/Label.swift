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
}
