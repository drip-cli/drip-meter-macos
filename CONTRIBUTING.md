# Contributing to DripMeter

Thanks for your interest. DripMeter is small and pragmatic — most
contributions land in under 200 lines. This guide tells you how to
set up, what conventions to follow, and how to get a PR merged
quickly.

## Code of conduct

This project follows the [Contributor Covenant v2.1](https://www.contributor-covenant.org/version/2/1/code_of_conduct/).
By participating you agree to abide by its terms.

---

## Setup

You need **Swift 6.0+** (Xcode 16+ or the standalone toolchain) and
macOS 14 Sonoma+. DRIP itself isn't required at build time, but you
need it installed if you want a populated DripMeter window to play
with:

```bash
brew install drip-cli/drip/drip
drip init -g                                 # wire DRIP into Claude Code
```

Build and run from source:

```bash
git clone git@github.com:drip-cli/drip-meter-macos.git
cd drip-meter-macos
swift build                                  # debug
swift test                                   # 20+ tests on DripMeterCore
./Scripts/compile_and_run.sh                 # build, kill, relaunch (.app bundle)
```

`compile_and_run.sh` packages a debug `DripMeter.app`, strips xattrs,
ad-hoc signs and launches it. Hot iteration: keep the script in a
terminal and rerun it on every save. ~3 s incremental thanks to
SPM's cache.

### Try your local build against a real DRIP install

DripMeter reads `~/Library/Application Support/drip/sessions.db`
read-only via `DripDatabase.openReadOnly`. As long as DRIP has
intercepted at least one read, the popover lights up. Use
`drip meter --json` to confirm DRIP is producing data.

---

## Project layout

Two SPM targets:

- `Sources/DripMeterCore/` — pure data layer. No SwiftUI / AppKit.
  Owns `DripStore` (the `@Observable` root), `DripCLI` (subprocess
  actor), `DripDatabase` (SQLite reader with the `query_only`
  pragma quirk), `MeterReport` (JSON mirror), `Milestones`,
  `CompactionWatcher`, `PeriodStats`, `UsageReport`.
- `Sources/DripMeter/` — SwiftUI shell. `DripMeterApp` (the
  `@main` scene), `MenuContentView` (popover root), the four tab
  views, `PreferencesView`, `MilestoneNotifier`.

`Tests/DripMeterCoreTests/` drives the data layer. UI is exercised
manually via `compile_and_run.sh`; we don't ship UI tests because
the value/effort ratio is poor for a menu-bar app at this scale.

The core invariant: **DRIP's SQLite is read-only.** DripMeter never
writes to the file under any circumstance. The `openReadOnly`
helper opens the connection with `SQLITE_OPEN_READWRITE` then
immediately applies `PRAGMA query_only = 1; PRAGMA temp_store =
MEMORY;` — that's the only combination that lets WAL-mode databases
serve complex `GROUP BY` queries to read-only consumers without
throwing `SQLITE_CANTOPEN`. Don't change this without reading the
comment in `DripDatabase.swift`.

---

## Commit conventions

DripMeter uses [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/).
Subject line in imperative mood, ≤ 100 chars, no trailing period.

```
feat:     a new user-facing feature
fix:      a bug fix
perf:     a performance improvement
refactor: a non-behavioural code change
docs:     documentation only
test:     test-only changes
chore:    build, CI, tooling
```

Examples:

```
feat: add 90-day activity heatmap to Stats tab
fix: respect prefers-reduced-motion on streak panel
docs: clarify SQLite read-only pragma in CONTRIBUTING
chore: bump Swift toolchain requirement to 6.2
```

Release notes are generated from these — sloppy subjects make
sloppy release notes.

---

## Pull request flow

1. Fork and branch from `main`. Branch name: `feat/<short-name>` or
   `fix/<short-name>`.
2. Add or update tests in `Tests/DripMeterCoreTests/` for any
   behavioural change to the data layer.
3. Run the full suite: `swift build && swift test`. Both must
   succeed.
4. If your change touches a UI panel, attach a screenshot in the
   PR description (Stats tab, Streak panel, settings — whatever you
   modified).
5. Open the PR against `main`. Use the template.

PRs are reviewed within a few days. We'll either merge, request
changes, or explain why we can't take it.

---

## Adding a new agent breakdown

If you want DripMeter to surface stats for a new DRIP-supported
agent, the steps are:

1. Add the variant in `Sources/DripMeterCore/DripAgent.swift`
   (`raw tag`, `displayName`, `provider icon path`).
2. Add the brand-coloured logo at
   `Sources/DripMeter/Resources/ProviderIcon-<agent>.svg`.
3. Update `AgentInstallProbe` so the "Install detected" badge lights
   up when the agent's config dir exists (`~/.<agent>/`).
4. The breakdown table picks it up automatically — `DripStore`
   queries `sessions` grouped by `agent` and folds the result into
   the matching `DripAgent` variant.

---

## What we won't merge

- Code with no tests for behavioural changes (UI-only changes are
  the obvious exception).
- New dependencies without a clear reason. DripMeter ships with
  only the Apple platform frameworks — no third-party packages.
- Background daemons / network calls / telemetry. DripMeter reads
  DRIP's local SQLite and shells out to `drip meter --json`.
  That's the entire data surface.
- Features that re-implement what DRIP already does. DripMeter is
  a UI on top of DRIP, not a fork of it.

If you're unsure whether something fits, open an issue first — we'll
tell you in a sentence whether it's worth your time.

---

## Releasing (maintainers only)

Releases are tag-driven. Push a `vX.Y.Z` tag and the `release.yml`
workflow does the rest:

1. Builds `DripMeter.app` against the matching `version.env` value.
2. Strips xattrs via `ditto --norsrc --noextattr --noacl`, ad-hoc
   signs, zips into `DripMeter-vX.Y.Z.zip`.
3. Attaches the zip + a `SHA256SUMS` file to the GitHub Release.
4. Regenerates `Casks/dripmeter.rb` in
   [`drip-cli/homebrew-drip`](https://github.com/drip-cli/homebrew-drip)
   with the new version + SHA256, pushes it. `brew upgrade` picks
   it up within minutes.

### Required repository secrets

| Secret | Scope | Purpose |
|---|---|---|
| `HOMEBREW_TAP_TOKEN` | `Contents: read & write` on `drip-cli/homebrew-drip` | Lets the workflow push the regenerated cask. Skipped (with a CI warning) when unset, so forks build cleanly. |

Generate the token at <https://github.com/settings/tokens?type=beta>,
scope it to the tap repo, set Contents: read+write, and add it under
**Repo → Settings → Secrets and variables → Actions** as
`HOMEBREW_TAP_TOKEN`. The same token can serve both DRIP and
DripMeter — both workflows push to the same tap.

### Bump the version

```bash
echo "DRIPMETER_VERSION=0.1.1" > version.env       # whatever new value
echo "DRIPMETER_BUILD=2" >> version.env
git add version.env
git commit -m "chore: release v0.1.1"
git tag -a v0.1.1 -m "DripMeter v0.1.1"
git push origin main v0.1.1
```

The tag push triggers `release.yml`.
