import AppKit
import StripGaugeCore

extension Severity {
    var colour: NSColor {
        switch self {
        case .unknown: .secondaryLabelColor
        case .normal: .systemGreen
        case .warning: .systemYellow
        case .alert: .systemRed
        }
    }
}

/// The view shown when the gauge is tapped.
///
/// It covers the app-specific half of the Touch Bar — about 740 pt, measured —
/// while the Control Strip stays put, so this has to earn its width rather than
/// fill it. One block per window: how much is gone, and when it comes back.
@MainActor
final class ExpandedBar {
    private static let identifier = NSTouchBarItem.Identifier("dev.stripgauge.expanded")

    let touchBar = NSTouchBar()

    private let fiveHour = WindowBlock(title: "5h")
    private let sevenDay = WindowBlock(title: "7d")

    init() {
        let stack = NSStackView(views: [fiveHour.view, sevenDay.view])
        stack.orientation = .horizontal
        stack.spacing = 28
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)

        let item = NSCustomTouchBarItem(identifier: Self.identifier)
        item.view = stack

        touchBar.defaultItemIdentifiers = [Self.identifier]
        touchBar.templateItems = [item]
    }

    func update(_ state: GaugeState, now: Date = Date()) {
        let live = state.live(now: now)
        fiveHour.update(percent: live.fiveHour, resetsAt: state.fiveHour.resetsAt, now: now)
        sevenDay.update(percent: live.sevenDay, resetsAt: state.sevenDay.resetsAt, now: now)
    }
}

/// One window: `5h  26%  ▓▓▓░░░░░  3h 41m`
@MainActor
private final class WindowBlock {
    let view: NSStackView

    private let name: NSTextField
    private let percent: NSTextField
    private let bar = BarView()
    private let remaining: NSTextField
    private let clock: NSTextField

    init(title: String) {
        name = Self.text(title, size: 13, weight: .semibold)
        percent = Self.text("", size: 13, weight: .semibold)
        remaining = Self.text("", size: 12, weight: .semibold)
        clock = Self.text("", size: 10, weight: .regular)

        percent.alignment = .right
        percent.widthAnchor.constraint(equalToConstant: 44).isActive = true
        bar.widthAnchor.constraint(equalToConstant: 120).isActive = true
        bar.heightAnchor.constraint(equalToConstant: 8).isActive = true

        // Countdown over clock time, stacked so the pair costs one column
        // rather than two. Nothing here may be squeezed: a clipped "Thu 21:00"
        // reads as "Thu 21", which is a different day entirely.
        let times = NSStackView(views: [remaining, clock])
        times.orientation = .vertical
        times.spacing = 0
        times.alignment = .leading
        for label in [remaining, clock] {
            label.setContentCompressionResistancePriority(.required, for: .horizontal)
        }

        view = NSStackView(views: [name, percent, bar, times])
        view.orientation = .horizontal
        view.spacing = 10
        view.alignment = .centerY
    }

    func update(percent value: Double?, resetsAt: Int?, now: Date) {
        let severity = Severity.of(value)
        percent.stringValue = value.map { "\(Int($0.rounded()))%" } ?? Label.placeholder
        percent.textColor = severity.colour
        name.textColor = severity.colour
        remaining.stringValue = Label.remaining(resetsAt, now: now) ?? ""
        clock.stringValue = Label.clock(resetsAt, now: now) ?? ""

        bar.fraction = (value ?? 0) / 100
        bar.colour = severity.colour
        bar.needsDisplay = true
    }

    private static func text(_ string: String, size: CGFloat, weight: NSFont.Weight) -> NSTextField {
        let field = NSTextField(labelWithString: string)
        field.font = .monospacedDigitSystemFont(ofSize: size, weight: weight)
        field.textColor = .labelColor
        field.lineBreakMode = .byClipping
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }
}

/// A track with the used portion filled.
private final class BarView: NSView {
    var fraction: Double = 0
    var colour: NSColor = .secondaryLabelColor

    override func draw(_ dirtyRect: NSRect) {
        let radius = bounds.height / 2

        NSColor.secondaryLabelColor.withAlphaComponent(0.3).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius).fill()

        let filled = bounds.width * min(max(fraction, 0), 1)
        guard filled > 0 else { return }

        colour.setFill()
        let used = NSRect(x: 0, y: 0, width: max(filled, bounds.height), height: bounds.height)
        NSBezierPath(roundedRect: used, xRadius: radius, yRadius: radius).fill()
    }
}
