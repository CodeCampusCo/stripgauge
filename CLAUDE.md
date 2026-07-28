# StripGauge

Shows Claude Code's subscription quota in the MacBook Pro Touch Bar Control Strip. See `README.md`
for how the pieces fit together and `docs/specs/` for the design.

## Layout

`Sources/StripGaugeCore` is pure logic and has no AppKit import — keep it that way, it is what the
tests cover. `Sources/stripgauge` holds the AppKit app, and all private API lives in
`ControlStrip.swift` alone.

## Constraints worth knowing before changing the UI

The Control Strip grants about 55 × 30 pt and ignores explicit width constraints, so the two-row
layout is a hard budget of roughly six characters per row, not a stylistic choice.

The expanded bar gets the app-specific half only, about 740 pt, and the Control Strip stays visible
beside it.

Taps reach controls, not gesture recognizers on a plain view, and `NSTouchBar.isVisible` is the only
reliable answer to whether the expanded bar is showing.

The statusline mode must always exit 0 — a failure there breaks the user's status line in every
Claude Code session.

## Verifying

`swift test` covers everything except the Touch Bar itself, which can only be checked by eye:
`./build.sh && open StripGauge.app`, then ⇧⌘6 screenshots the Touch Bar to the Desktop.
