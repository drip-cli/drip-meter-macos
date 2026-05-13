# Security policy

## Reporting a vulnerability

If you discover a security issue in DripMeter, please **do not open a
public GitHub issue.**

Email the maintainers privately at the contact address listed on
[drip-ai.app/legal/notice](https://drip-ai.app/legal/notice). Include:

- A description of the issue.
- Steps to reproduce, if possible.
- The DripMeter version (`About → DripMeter` in the Settings window,
  or `cat /Applications/DripMeter.app/Contents/Info.plist | grep -A1 CFBundleShortVersionString`).
- Your macOS version.

We acknowledge reports within 72 hours and aim to ship a patch
within 14 days for critical issues. Anything that risks data
exfiltration, code execution, or local privilege escalation is
treated as critical.

## Scope

DripMeter reads two things, both on your local machine:

1. **DRIP's SQLite database** at
   `~/Library/Application Support/drip/sessions.db` — read-only, via
   `SQLITE_OPEN_READWRITE` + `PRAGMA query_only = 1`. No write path
   exists in the codebase.
2. **The output of `drip meter --json`** — a CLI subprocess invoked
   with a 5-second timeout and an explicitly scrubbed environment
   (no `PATH` injection, no shell expansion).

DripMeter has **zero network calls.** No telemetry, no analytics, no
auto-update endpoint, no crash reporting. Verified at every release
by a manual review of `Package.swift` (no third-party deps) and by
running the app against Little Snitch / Lulu in default-deny mode.

Anything outside this scope — your DRIP install, the agents DRIP
hooks into (Claude Code, Codex CLI, Gemini CLI), macOS itself — is
not part of DripMeter's threat model. Report issues with those
projects directly to their maintainers.

## Supported versions

Only the latest minor version receives security updates. Pre-1.0,
this is the latest patch tag.
