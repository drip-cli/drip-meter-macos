---
name: Bug report
about: Report a reproducible problem in DripMeter
title: "[bug] "
labels: bug
assignees: ""
---

## Description

A clear and concise description of what the bug is.

## Steps to reproduce

1.
2.
3.

A minimal reproduction is worth ten paragraphs.

## Expected behaviour

What you thought DripMeter would do.

## Actual behaviour

What it did instead. Include the exact text shown in the popover or
the Settings window, and (if applicable) a screenshot.

## DripMeter version

```
# Look it up under Settings → About, or run:
defaults read /Applications/DripMeter.app/Contents/Info.plist CFBundleShortVersionString
```

## Environment

- macOS version:                <!-- e.g. 14.4 Sonoma -->
- Architecture:                 <!-- Apple Silicon / Intel -->
- DRIP version:                 <!-- output of `drip --version`, e.g. drip 0.1.0 -->
- DRIP install path:            <!-- output of `which drip` -->

## Logs

If DripMeter is misbehaving silently, check the system log:

```
log stream --predicate 'subsystem == "io.drip-cli.dripmeter"' --info
```

Paste anything relevant here.

## Additional context

Anything else that frames the problem.
