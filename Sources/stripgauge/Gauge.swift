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

    private let top = GaugeDelegate.makeRow()
    private let bottom = GaugeDelegate.makeRow()
    private var item: NSCustomTouchBarItem?
    private var isVisible = false
    private var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard ControlStrip.isAvailable else {
            fail("the Touch Bar private API this depends on is unavailable on this macOS build")
        }

        let item = NSCustomTouchBarItem(identifier: Self.identifier)
        item.view = makeStack()
        self.item = item
        ControlStrip.register(item)

        timer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { _ in
            MainActor.assumeIsolated { self.refresh() }
        }
        refresh()
    }

    // MARK: - Refresh

    private func refresh() {
        guard let state = try? GaugeStore.read(), !state.isStale() else {
            setVisible(false)
            return
        }

        let rows = Label.rows(state)
        top.stringValue = rows.top
        bottom.stringValue = rows.bottom

        let colour = Self.colour(for: Severity.of(state.worstPercent))
        top.textColor = colour
        bottom.textColor = colour

        setVisible(true)
    }

    private func setVisible(_ visible: Bool) {
        guard visible != isVisible else { return }
        isVisible = visible
        ControlStrip.setVisible(visible, identifier: Self.identifier)
    }

    // MARK: - Views

    /// Two rows, sized by their own text. Do not add a width constraint: the
    /// Control Strip discards it and falls back to a default slot.
    private func makeStack() -> NSView {
        let container = NSView()
        container.addSubview(top)
        container.addSubview(bottom)
        NSLayoutConstraint.activate([
            top.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 6),
            top.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -6),
            bottom.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 6),
            bottom.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -6),
            top.topAnchor.constraint(equalTo: container.topAnchor, constant: 1),
            bottom.topAnchor.constraint(equalTo: top.bottomAnchor),
            bottom.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -1),
        ])
        return container
    }

    private static func makeRow() -> NSTextField {
        let field = NSTextField(labelWithString: Label.placeholder)
        field.font = .monospacedDigitSystemFont(ofSize: 10, weight: .semibold)
        field.alignment = .center
        field.lineBreakMode = .byClipping
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }

    private static func colour(for severity: Severity) -> NSColor {
        switch severity {
        case .normal: .labelColor
        case .warning: .systemYellow
        case .alert: .systemRed
        }
    }

    private func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("stripgauge: \(message)\n".utf8))
        exit(1)
    }
}
