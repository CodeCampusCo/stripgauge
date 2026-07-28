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

The statusline mode must always exit 0 — a failure there breaks the user's status line in every
Claude Code session.

## How `main` is protected

Two rulesets, because ruleset bypass is granted per ruleset rather than per rule:

- **protect main** — pull request required, CI must pass, no force-push, no deletion. No bypass
  actors, so this applies to everyone including the owner.
- **require code owner review** — one approving review, and it has to come from a code owner
  (`.github/CODEOWNERS`). Org admins bypass this one.

The split is what lets a solo owner keep working — GitHub never lets authors approve their own pull
requests, so without the bypass a single code owner could never merge anything — while a contributor
with write access is already covered the day they arrive. Nothing needs enabling later.

Bypass is deliberately `OrganizationAdmin` rather than the repository admin role, so granting
someone admin on this repo does not also hand them a way around review.

When the reviewer should no longer be one person, change `CODEOWNERS` to an org team; otherwise every
contributor's pull request waits on a single human.

## Verifying

`swift test` covers everything except the Touch Bar itself, which can only be checked by eye:
`./build.sh && open StripGauge.app`, then ⇧⌘6 screenshots the Touch Bar to the Desktop.
