# Contributing

## Scope

StripGauge shows two numbers in the Control Strip and hides itself when Claude Code is not
running. That is deliberately the whole product. Pull requests that keep it that small are much
easier to accept than ones that grow it.

Especially welcome:

- fixes for a macOS version where the private Touch Bar API moved and the gauge stopped appearing
- handling for a statusline payload shape that breaks parsing
- anything that removes code without removing behaviour

Before building something larger, open an issue first — see `docs/proposals/` for the ideas already
written down and the reasons they are not built yet.

## Working on it

```sh
swift test          # parsing, merging, formatting, thresholds, staleness
./build.sh          # assemble StripGauge.app
open StripGauge.app
```

`Sources/StripGaugeCore` must not import AppKit. That separation is what keeps the logic testable
on a machine with no Touch Bar, and all private API stays confined to `ControlStrip.swift`.

To feed it a payload without waiting for Claude Code:

```sh
echo '{"rate_limits":{"five_hour":{"used_percentage":67},"seven_day":{"used_percentage":88}}}' \
  | StripGauge.app/Contents/MacOS/stripgauge statusline
```

## Verifying a UI change

The Touch Bar cannot be tested automatically. Press ⇧⌘6 to save a screenshot of it to your
Desktop, and attach that to the pull request. A change to what the Control Strip draws is not
reviewable without one.

## Commits

Explain why the change is needed, not what the diff does. If a measurement drove the change — the
Control Strip's real slot size, for instance — put the number in the message.
