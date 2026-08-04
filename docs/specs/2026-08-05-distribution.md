# Distribution — why there is no Homebrew install

2026-08-05

## The question

Building StripGauge means cloning the repository, running `build.sh`, quitting the running copy,
deleting the old bundle, moving the new one into `/Applications`, adding a Login Item and editing
`~/.claude/settings.json` by hand. A `brew install` would collapse most of that, and would give
upgrades for free. This records why it is not on the roadmap, so the question does not get
re-opened from scratch.

## Both Homebrew routes are closed

**A cask is closed twice over.** `homebrew/cask` rejects repositories below 30 forks, 30 watchers
or 75 stars, and the thresholds rise to 90 / 90 / 225 when the repository owner submits the cask
themselves. This repository is at zero on all three. Separately, Homebrew is retiring the
`--no-quarantine` flag and ends support for every cask that fails a Gatekeeper check on
2026-09-01, so casks must be codesigned and notarized. Notarization requires a paid Apple Developer
account, which this project does not have and is not buying.

**A formula in a personal tap is the wrong shape.** It looked like the way around both problems: a
formula builds from source on the user's machine, so nothing arrives quarantined and Gatekeeper
never sees it, and personal taps have no notability requirement. But Homebrew formulae are not
meant to deliver `.app` bundles — `brew linkapps` is deprecated, and Homebrew's own guidance is
that formulae do not produce relocatable app bundles and that such software belongs in a cask.
A personal tap has no gate stopping it, but the route fights the design of the tool, and the
maintenance falls on one person alongside Swift and Xcode drift.

## What a formula would not have fixed anyway

Even a working tap leaves the Swift toolchain requirement, the Login Item, and the
`~/.claude/settings.json` edit in place. Those are the steps most likely to stop someone, and the
build sequence — the part `brew` would have replaced — is the part a person with the Xcode
toolchain already installed finds routine.

## What is being done instead

A `stripgauge setup` subcommand that reads any existing `statusLine` command before replacing it,
registers the Login Item, and leaves the user's status line intact. That addresses the step that
actually blocks adoption, which packaging never touched.

## What would change this

An outside request. If someone who is not the author asks for `brew install` in an issue, the
demand is real and a personal tap becomes worth an hour's spike. Until then it is packaging built
for nobody.

## Not paying the $99

Apple's Developer Program fee would unlock notarization, prebuilt releases, and eventually a cask.
It is declined — not because the platform is dead, which turned out to be wrong (the Touch Bar
shipped through the 13-inch M2, discontinued October 2023), but because it is a recurring
obligation: annual renewal and silent certificate expiry, on a side project maintained by one
person alongside others.
