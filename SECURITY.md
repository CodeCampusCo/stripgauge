# Security

## Reporting

Report vulnerabilities privately through GitHub's **Report a vulnerability** button under the
Security tab. Please do not open a public issue for anything exploitable.

This is a personal project maintained in spare time. There is no SLA — expect a reply in days,
not hours, and no guaranteed fix timeline.

## What this software touches

Worth knowing when judging impact:

- **No network access.** It makes no requests and has no telemetry.
- **Reads only stdin.** The statusline mode consumes the JSON Claude Code sends it and nothing
  else. It does not read transcripts, credentials, or any Claude Code configuration.
- **Writes one file.** `~/Library/Application Support/stripgauge/state.json`, containing two
  percentages and a timestamp.
- **Unsandboxed, and calls private API.** It loads `DFRFoundation` at runtime to place an item in
  the Control Strip. It is ad-hoc signed by whoever builds it, and it is not notarized, because it
  is built from source rather than distributed.

## Supported versions

Only the latest commit on `main`.
