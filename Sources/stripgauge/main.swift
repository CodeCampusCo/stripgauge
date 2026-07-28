import AppKit
import StripGaugeCore

/// `stripgauge statusline` is what Claude Code invokes; with no arguments the
/// same binary runs as the Touch Bar app.
if CommandLine.arguments.dropFirst().first == "statusline" {
    runStatusline()
    exit(0)
}

let app = NSApplication.shared
let delegate = GaugeDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()

/// Reads Claude Code's JSON from stdin, hands the quota numbers to the Touch Bar
/// process, and prints one line for the terminal status line.
///
/// This must never fail loudly. A crash or non-zero exit here would break the
/// user's status line, so unreadable input leaves the last good state in place.
func runStatusline() {
    let data = FileHandle.standardInput.readDataToEndOfFile()

    guard let input = try? StatuslineInput.decode(data) else {
        print(Label.statusline(fiveHour: nil, sevenDay: nil, context: nil))
        return
    }

    let state = input.state().merged(over: try? GaugeStore.read())
    try? GaugeStore.write(state)

    let live = state.live()
    print(Label.statusline(fiveHour: live.fiveHour, sevenDay: live.sevenDay, context: input.contextPercent))
}
