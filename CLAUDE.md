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

## If a contributor ever gets write access

`main` is protected by a ruleset with no bypass actors: everyone, owner included, goes through a
pull request that passes CI, and nobody can force-push or delete the branch. Required approvals is
0, which is what lets a solo owner merge their own work.

The moment someone else has write access, that setting also lets them merge their own pull requests
unreviewed. Close that by enabling `require_code_owner_review` on the ruleset — `.github/CODEOWNERS`
is already in place. Do not enable it before then: GitHub does not allow authors to approve their
own pull requests, so with a single code owner it blocks every one of the owner's own merges.

## Verifying

`swift test` covers everything except the Touch Bar itself, which can only be checked by eye:
`./build.sh && open StripGauge.app`, then ⇧⌘6 screenshots the Touch Bar to the Desktop.
