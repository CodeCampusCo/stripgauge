import AppKit
import StripGaugeCore

/// Owns the Control Strip item and keeps it in sync with the state file.
///
/// The state file is polled rather than watched: it is replaced by an atomic
/// rename, which swaps the inode and silently kills any fd-based watch.
@MainActor
final class GaugeDelegate: NSObject, NSApplicationDelegate {
    private static let identifier = NSTouchBarItem.Identifier("dev.stripgauge.item")
    private static let pollInterval: TimeInterval = 2

    private let button = GaugeDelegate.makeButton()
    private var rendered = ""
    private var item: NSCustomTouchBarItem?
    private var isVisible = false
    private var timer: Timer?

    private let expanded = ExpandedBar()

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard ControlStrip.isAvailable else {
            fail("the Touch Bar private API this depends on is unavailable on this macOS build")
        }

        button.target = self
        button.action = #selector(toggle)

        let item = NSCustomTouchBarItem(identifier: Self.identifier)
        item.view = button
        self.item = item
        ControlStrip.register(item)

        timer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { _ in
            MainActor.assumeIsolated { self.refresh() }
        }
        refresh()
    }

    // MARK: - Refresh

    /// `STRIPGAUGE_DEBUG=1` traces every tick. The Touch Bar layer cannot be
    /// tested, so this is the only way to tell a stalled timer apart from a
    /// stalled render.
    private static let debug = ProcessInfo.processInfo.environment["STRIPGAUGE_DEBUG"] == "1"

    private func trace(_ message: String) {
        guard Self.debug else { return }
        let now = Date().formatted(date: .omitted, time: .standard)
        FileHandle.standardError.write(Data("[\(now)] \(message)\n".utf8))
    }

    private func refresh() {
        guard let state = try? GaugeStore.read(), !state.isStale() else {
            trace("tick — unreadable or stale, hiding")
            collapse()
            setVisible(false)
            return
        }

        let live = state.live()
        let rows = Label.rows(fiveHour: live.fiveHour, sevenDay: live.sevenDay)
        trace("tick — file says \(rows.top) / \(rows.bottom), showing \(rendered)")

        // Each window is coloured on its own reading. A quiet five-hour window
        // should not look alarming just because the weekly one is filling up.
        setTitle(
            rows,
            top: Severity.of(live.fiveHour).colour,
            bottom: Severity.of(live.sevenDay).colour
        )

        if expanded.touchBar.isVisible {
            expanded.update(state)
        }
        setVisible(true)
    }

    private func setVisible(_ visible: Bool) {
        guard visible != isVisible else { return }
        isVisible = visible
        ControlStrip.setVisible(visible, identifier: Self.identifier)
    }

    // MARK: - Expanding

    /// Tapping toggles. The bar's own `isVisible` is the source of truth: the
    /// close box, and a second tap on the tray item, both dismiss it without
    /// telling us, so a flag of our own goes stale and every later tap is
    /// swallowed.
    @objc private func toggle() {
        let visible = expanded.touchBar.isVisible
        trace("tapped — isVisible=\(visible)")

        if visible {
            ControlStrip.collapse(expanded.touchBar)
            return
        }

        guard let state = try? GaugeStore.read(), !state.isStale() else { return }
        expanded.update(state)
        ControlStrip.expand(expanded.touchBar, from: Self.identifier)
    }

    private func collapse() {
        guard expanded.touchBar.isVisible else { return }
        ControlStrip.collapse(expanded.touchBar)
    }

    // MARK: - Views

    /// A button rather than a label, because the Control Strip delivers taps to
    /// controls and not to gesture recognizers on a plain view. Two rows come
    /// from an attributed title, which is also what lets each row take its own
    /// colour.
    ///
    /// Do not add a width constraint: the Control Strip discards it and falls
    /// back to a default slot.
    private static func makeButton() -> NSButton {
        let button = NSButton(title: Label.placeholder, target: nil, action: nil)
        button.isBordered = false
        button.imagePosition = .noImage
        button.translatesAutoresizingMaskIntoConstraints = false
        (button.cell as? NSButtonCell)?.usesSingleLineMode = false
        (button.cell as? NSButtonCell)?.lineBreakMode = .byClipping
        return button
    }

    private func setTitle(_ rows: (top: String, bottom: String), top: NSColor, bottom: NSColor) {
        let style = NSMutableParagraphStyle()
        style.alignment = .center

        let font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .semibold)
        let title = NSMutableAttributedString()
        title.append(NSAttributedString(
            string: rows.top + "\n",
            attributes: [.font: font, .foregroundColor: top, .paragraphStyle: style]))
        title.append(NSAttributedString(
            string: rows.bottom,
            attributes: [.font: font, .foregroundColor: bottom, .paragraphStyle: style]))

        button.attributedTitle = title
        rendered = "\(rows.top) / \(rows.bottom)"
    }

    private func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("stripgauge: \(message)\n".utf8))
        exit(1)
    }
}
