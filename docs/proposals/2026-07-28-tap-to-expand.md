# Proposal: tap to expand into a detail bar

2026-07-28 — proposed, not built. Nothing in the repo implements this yet.

## Why

The Control Strip slot is about 55 × 30 pt, which fits two rows of six characters and nothing
else. Everything else worth knowing is already in the statusline payload and currently thrown
away: when each window resets, how full the context is, what the session has cost.

A tap that opens a full-width detail view, and a close box that returns the bar to normal, buys
that space without giving up the Control Strip.

## The mechanism already exists on the machine

The brightness and volume buttons do not grow in place. Tapping one presents a *system-modal
function bar* over the whole Touch Bar, with a close box on the left; dismissing it restores the
previous bar. The takeover lasts only while it is on screen, which is the important difference
from the permanent hijack that MTMR and Pock perform.

Same private framework already loaded for the gauge:

| Symbol | Role |
| --- | --- |
| `presentSystemModalTouchBar` (also seen as `presentSystemModalFunctionBar`) | show a bar over the whole Touch Bar |
| `minimizeSystemModalTouchBar` | dismiss it |
| `DFRSystemModalShowsCloseBoxWhenFrontMost` | draw the ✕ that lets the user dismiss it |

The gauge item's view becomes a button with a target and action; the action presents the bar.

## Data

All of it already arrives on stdin and is currently discarded, so this costs no new source:

| Field | Shows as |
| --- | --- |
| `rate_limits.five_hour.resets_at` | "resets in 2h 14m" |
| `rate_limits.seven_day.resets_at` | "resets Tuesday" |
| `context_window.used_percentage` | context bar for the most recent session |
| `cost.total_cost_usd` | session cost |

`GaugeState` grows four optional fields. The merge rule already written — absent values fall back
to what is on disk, stale values do not — applies unchanged.

## Sketch

```
 ✕ │ 5h  ████████░░░░░░░░  11%   resets in 2h 14m │ 7d  ███████████████░  79%   resets Tue │ ctx 34%  $1.23
```

Reset countdowns are computed in the app from `resets_at`, not from the statusline, so they keep
ticking while Claude Code is idle.

## Risks

**More private API to break.** The gauge depends on two undocumented entry points; this adds
three. A macOS update that moves them should degrade to "tap does nothing" rather than crash,
which means each symbol needs the same `dlsym`-and-check treatment `ControlStrip.swift` already
uses.

**A crash while the modal bar is up.** If the process dies while presenting, the Touch Bar could
be left showing a dead bar. Whether `TouchBarServer` recovers on its own is unknown and is the
main thing the spike has to answer.

**Nothing here is testable by machine.** The layout and the presentation are visual, same as the
gauge. Only the countdown formatting and the widened state schema will have unit tests.

## Spike first

Same shape as the spike that settled the gauge layout: a throwaway app that presents a modal bar
with a close box, proving on this macOS build that

1. `dlsym` finds all three symbols,
2. the bar appears from a Control Strip tap and the ✕ dismisses it,
3. `kill -9` while the bar is up leaves the Touch Bar recoverable.

If 3 fails and the bar stays wedged until logout, this is not worth shipping — the gauge is a
background tool and must not be able to break the machine's own controls.

## Open questions

- Is the detail bar worth a tap, or would the countdown matter more as a third row in the
  Control Strip when a window gets close to full?
- Should tapping ✕ be the only way out, or should it also dismiss on a timeout?
