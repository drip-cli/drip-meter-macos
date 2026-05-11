<!-- markdownlint-disable MD033 MD041 -->

<div align="center">

# DripMeter

**Live token-savings meter for [DRIP](https://github.com/drip-cli/drip), in your macOS menu bar.**

[![Build](https://img.shields.io/github/actions/workflow/status/drip-cli/drip-meter-macos/ci.yml?branch=main&label=build&logo=github)](https://github.com/drip-cli/drip-meter-macos/actions)
[![macOS](https://img.shields.io/badge/macOS-14%2B-black.svg?logo=apple)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg?logo=swift)](https://swift.org)
[![License: Apache 2.0](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](./LICENSE)

</div>

A tiny macOS 14+ menu bar app that reads DRIP's local SQLite store and
surfaces, at a glance, how many tokens DRIP has saved you across
**Claude Code**, **Codex CLI** and **Gemini CLI** — the three agents
DRIP supports.

No network calls. No telemetry. No accounts. DripMeter shells out to
`drip meter --json` and reads `~/Library/Application Support/drip/sessions.db`
read-only — that's the entire data surface.

```text
   menu bar:   ▓▓▓▓▓░░░ 87 %     ← live efficiency meter
   click  →    ┌─────────────────────────────────────────┐
               │  Drip                  Updated 2m ago   │
               │ ─────────────────────────────────────── │
               │  108K tokens saved    $0.31    28 g CO₂ │
               │  ████████████▒▒▒▒  87 %                 │
               │                                          │
               │  Per agent (lifetime)                    │
               │   ◈ Claude Code   62 K saved   94 %     │
               │   ▲ Codex         28 K saved   71 %     │
               │   ◇ Gemini        12 K saved   83 %     │
               │                                          │
               │  Top files · ↺ compactions · live feed   │
               └─────────────────────────────────────────┘
```

---

## Table of contents

- [Requirements](#requirements)
- [Install](#install)
- [Features](#features)
- [Architecture](#architecture)
- [Privacy](#privacy)
- [Development](#development)
- [Roadmap](#roadmap)
- [Related](#related)
- [Team](#team)
- [License](#license)

---

## Requirements

- **macOS 14** (Sonoma) or later
- **DRIP** installed: `brew install drip-cli/drip/drip` (or any of the
  install methods listed in the DRIP repo)
- That's it.

DripMeter looks for the `drip` binary in `PATH` and the usual install
prefixes (`/opt/homebrew/bin`, `/usr/local/bin`, `~/.cargo/bin`,
`~/.local/bin`). You can pin a custom path in **Settings → Advanced →
DRIP binary**.

---

## Install

### Homebrew (recommended, planned)

```bash
brew install --cask drip-cli/drip/drip-meter
```

### From source (today)

```bash
git clone git@github.com:drip-cli/drip-meter-macos.git
cd drip-meter-macos
./Scripts/package_app.sh             # builds DripMeter.app in-place
open DripMeter.app
```

Requirements for building: Swift 6.2+ toolchain, macOS 14+.
`CODEXBAR_SIGNING=adhoc ./Scripts/package_app.sh` ad-hoc signs when you
don't have an Apple Developer account.

---

## Features

- **Live menu-bar meter.** A 18 × 18 pt droplet template image whose
  fill matches your `% saved`. Right-click for quick actions (refresh,
  cache compact, drip init for each agent).
- **Per-agent breakdown.** Claude Code, Codex CLI, Gemini CLI, each
  with their official logo + install-detection badge. One-click
  `drip init` per agent from inside the popover.
- **Cost projection.** Pick Sonnet 4.6, Opus 4.7, GPT-5, Gemini 2.5
  (or a custom $/Mtok) and DripMeter extrapolates your savings per
  day, week, month, year based on the elapsed-time linear method
  `drip meter` already uses.
- **Context-compaction tracker.** Surfaces DRIP's v9+ ledger — how
  often your agent compacts, how many tokens were re-sent, with a
  "quality" score showing what % of your savings survived the resets.
- **Top files.** 50-file scrollable list pulled from
  `lifetime_per_file`, with click-through to your editor (Cursor,
  VS Code, Zed, Xcode, …, configurable in Settings → Advanced).
- **Live activity feed.** Real-time stream of intercepted reads via
  `read_events`, FSEvents-driven so the popover refreshes within
  milliseconds of DRIP committing.
- **Milestone notifications.** macOS user notifications when you
  cross 100K / 1M / 10M tokens or $10 / $50 / $100 / $500 saved.
  One-shot, idempotent.
- **Quick actions.** `drip reset`, `drip cache compact`, `drip cache
  gc`, `drip reset --all` from Settings → Advanced. No terminal trip.
- **CodexBar bridge.** When [CodexBar](https://github.com/steipete/CodexBar)
  is installed, DripMeter reads its quota history JSONs (read-only)
  and overlays provider rate-limit progress bars on the per-agent
  cards. Hidden gracefully when CodexBar isn't around.

---

## Architecture

Two SPM targets:

```
Sources/
├── DripMeterCore/             # data layer, no AppKit/SwiftUI
│   ├── DripStore.swift        # @Observable root, refresh scheduler
│   ├── DripCLI.swift          # actor wrapping `drip` subprocess calls
│   ├── DripDatabase.swift     # SQLite reader (readwrite + query_only
│   │                          # pragma so WAL temp tables work)
│   ├── MeterReport.swift      # Codable mirror of `drip meter --json`
│   ├── AgentInstall.swift     # probes ~/.claude / ~/.codex / ~/.gemini
│   ├── CodexBarBridge.swift   # reads quota JSONs read-only when present
│   ├── DatabaseWatcher.swift  # FSEvents on sessions.db with coalescing
│   ├── Milestones.swift       # threshold tracker + UserDefaults memory
│   ├── CompactionWatcher.swift
│   ├── CostModel.swift, IDELauncher.swift, SettingsStore.swift, …
│   └── Tests/                 # 20+ tests on Codable + state machines
└── DripMeter/                 # SwiftUI app + AppKit shell
    ├── DripMeterApp.swift     # @main scene
    ├── MenuBarLabel.swift     # status-item icon + label
    ├── MenuContentView.swift  # popover root
    ├── HeaderCardView.swift, AgentBreakdownView.swift, …
    ├── Tabs/                  # OverviewTabView, AgentsTabView,
    │                          # FilesTabView, LiveTabView
    └── PreferencesView.swift  # NavigationSplitView settings
```

State flows:
1. **Polling** (every cadence interval) + **FSEvents** on
   `sessions.db` → `DripStore.refresh()`.
2. `refresh()` shells out to `drip meter --json`, parses into
   `MeterReport`, and also reads SQLite directly for the
   per-agent breakdown that `meter --json` doesn't expose.
3. `@Observable` propagates to every SwiftUI view watching the
   store; the popover re-renders without manual notification
   plumbing.

Read-only SQLite access opens with `SQLITE_OPEN_READWRITE` then
immediately applies `PRAGMA query_only = 1; PRAGMA temp_store = MEMORY;
PRAGMA busy_timeout = 1000;` — the only combination that lets WAL-mode
databases serve complex `GROUP BY` queries to read-only consumers
without throwing `SQLITE_CANTOPEN`.

---

## Privacy

DripMeter does **zero network calls** by design. It reads three things,
all on your machine:

| Source                                                               | Purpose                                  |
|----------------------------------------------------------------------|------------------------------------------|
| `drip meter --json` (CLI subprocess)                                 | Lifetime totals + top files + history    |
| `~/Library/Application Support/drip/sessions.db` (SQLite, read-only) | Per-agent breakdown, sessions, events    |
| `~/Library/Application Support/com.steipete.codexbar/history/*.json` | Provider quotas (opt-in, only if CodexBar is installed) |

No login, no API key, no telemetry. If `drip` isn't installed yet,
DripMeter shows a one-line onboarding hint pointing at the install
docs.

---

## Development

```bash
swift build                          # debug
swift run DripMeter                  # run from the build directory
swift test                           # core tests (20+ pass)
./Scripts/compile_and_run.sh         # build, kill running instance, relaunch
./Scripts/package_app.sh             # release build → DripMeter.app
./Scripts/make_icons.sh              # regenerate AppIcon from Branding/
```

Hot-reload iteration: keep `compile_and_run.sh` open in a terminal
and hit it whenever you save. Builds usually finish in 1-3 s thanks
to SPM's incremental cache.

Code style: SwiftFormat (`.swiftformat`) and SwiftLint (`.swiftlint.yml`)
configured at the repo root. CI runs both on every PR.

---

## Roadmap

- [ ] Sparkle auto-update once the Apple Developer ID is in place.
- [ ] WidgetKit widget (today + lock-screen) reusing `DripStore`.
- [ ] Per-session drill-down view (`drip sessions` GUI surface).
- [ ] Daily-savings target + streak counter on the menu bar icon
      ([already in the store, missing the visible badge](Sources/DripMeterCore/SettingsStore.swift)).
- [ ] Localised UI strings (EN today, FR planned).

---

## Related

- 🦀 **[DRIP](https://github.com/drip-cli/drip)** — the Rust CLI this
  app surfaces.
- 🌐 **[drip-web](https://github.com/drip-cli/drip-web)** — the
  marketing site at `drip-ai.app`.

---

## Team

Built by **[Perform Code SAS](https://drip-ai.app/legal/notice)** in
Lille, France.

| | Founder | Focus | GitHub |
|---|---|---|---|
| 🎨 | Maxence Bombeeck    | Designer & Swift  | [@MaxenceB59](https://github.com/MaxenceB59) |
| 🦀 | Hugo Pereira Barbosa | Core DRIP         | [@Hugobrbs](https://github.com/Hugobrbs)    |
| 🛠️ | Hugo Ponthieux       | DevOps & Infra    | [@Hugoy8](https://github.com/Hugoy8)        |

---

## License

[Apache-2.0](./LICENSE) © Perform Code SAS
