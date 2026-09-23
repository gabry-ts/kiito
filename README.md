<div align="center">

<img src="docs/images/icon.png" width="128" alt="Kiito icon">

# Kiito

**Hold a mouse button and move a trackball to scroll. Free and open source. The cursor stays put.**

[![macOS 26+](https://img.shields.io/badge/macOS-26%2B-black?logo=apple)](#install)
[![Swift 6.2](https://img.shields.io/badge/Swift-6.2-F05138?logo=swift&logoColor=white)](Package.swift)
[![License: GPL-3.0](https://img.shields.io/badge/license-GPL--3.0-blue)](https://www.gnu.org/licenses/gpl-3.0.html)
[![Latest release](https://img.shields.io/github/v/release/gabry-ts/kiito)](https://github.com/gabry-ts/kiito/releases)

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/screenshots/profile-dark.png">
  <img src="docs/screenshots/profile-light.png" alt="Kiito profile editor with scroll tuning and cursor styles" width="720">
</picture>

</div>

## Why

- Trackballs like the Logitech MX Ergo have no dedicated scroll ring, and most grab-scroll utilities for them are paid.
- Kiito holds a button, moves the ball, and scrolls, with the cursor frozen so it doesn't drift while you read.

## Features

- **Grab-scroll**: hold a trigger button (right, middle, button 4, or button 5) and move the ball to scroll. Release without crossing the movement threshold and it passes through as a normal click. An optional "Stay On" mode toggles scrolling with a click instead of holding the trigger.
- **Tuning**: adjustable speed and acceleration, three axis modes (free 360° scrolling, snap to one axis with adjustable switching sensitivity, or lock to the first axis until release), inertia with a throw duration control, and independent reversal of each axis.
- **Profiles**: four built-in profiles (Default, Precise, Fast, Reading) plus unlimited custom profiles, switchable from the menu bar.
- **Cursor**: eight styles while scrolling, including a circular indicator, a closed hand, the system move cursor, a dot, a vertical capsule, a compass, a glass disc, or none at all.
- **Per-app exclusions**: apps on the exclusion list keep their normal right click. Kiito ignores the trigger button there.
- **Menu bar**: hideable icon (relaunch from Spotlight or Finder to bring settings back), launch at login, and a quick enable/disable toggle.

## Screenshots

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/screenshots/excluded-apps-dark.png">
  <img src="docs/screenshots/excluded-apps-light.png" alt="Excluded apps list" width="880">
</picture>
<p align="center"><sub>Excluded apps</sub></p>

## Requirements

- macOS 26 or later.
- A trackball or mouse with a spare button to use as the trigger (right, middle, button 4, or button 5).
- Accessibility permission, to install the event tap that intercepts mouse events.

## Install

1. Download the latest `Kiito-<version>.dmg` from [Releases](https://github.com/gabry-ts/kiito/releases) and drag the app to Applications. Kiito uses `SMAppService` for launch at login, which only works reliably when the app lives in `/Applications`.
2. Kiito is signed with a local Apple Development identity and not notarized, so Gatekeeper blocks the first launch:
   - Open the app once, then go to **System Settings > Privacy & Security** and click **Open Anyway** (on older macOS versions, right-click the app and choose **Open**).
   - Or remove the quarantine flag from Terminal: `xattr -dr com.apple.quarantine /Applications/Kiito.app`
3. Launch Kiito. On first launch it asks for Accessibility permission. Grant it in **System Settings > Privacy & Security > Accessibility**; the settings window opens automatically.
4. If a rebuild or reinstall ever invalidates the Accessibility grant, remove and re-add Kiito in that same Accessibility list.

## Reopening settings

- Kiito runs as a menu bar app with no Dock icon.
- If the menu bar icon is hidden, relaunch Kiito from Spotlight or Finder to bring the settings window back.

## Settings location

- Profiles, excluded apps, and general preferences are stored as JSON at `~/Library/Application Support/Kiito/settings.json`.

## Build from source

Requires Xcode (or the Command Line Tools) with Swift 6.2.

```sh
./scripts/build.sh      # build/Kiito.app
open build/Kiito.app
./scripts/make-dmg.sh   # build/Kiito-<version>.dmg
```

- `build.sh` builds a release binary with Swift Package Manager, assembles `build/Kiito.app`, and code-signs it with a local Apple Development identity so the Accessibility grant survives rebuilds.
- `make-dmg.sh` builds the app first if `build/Kiito.app` doesn't exist yet (pass `--rebuild` to force a fresh build), then packages it with `hdiutil`, using only tools that ship with macOS.

## Uninstall

- Quit Kiito and remove it from `/Applications`.
- Delete `~/Library/Application Support/Kiito` to also clear its settings.
- If launch at login is enabled, disable it first, from Kiito's settings or from **System Settings > General > Login Items**.

## Privacy

- Settings stay on your Mac, in a local JSON file you can inspect or delete at any time.
- Kiito reads mouse events and the bundle identifier of the app under the cursor, to apply per-app exclusions. It doesn't read keystrokes or window content.
- No network access, no analytics, no account, no server.

## Notes

- Hiding the system cursor while scrolling relies on an undocumented CoreGraphics connection property (`SetsCursorInBackground`), since a background app can't otherwise change the global cursor.
- If that private call is unavailable, Kiito falls back to drawing its own cursor overlay on top of the system cursor.
- The app is not notarized; see Install for how to open it anyway.

## License

Copyright (C) 2026 Gabriele Partiti

Kiito is free software, released under the [GNU General Public License v3.0](https://www.gnu.org/licenses/gpl-3.0.html).
