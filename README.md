<div align="center">

<img src="docs/images/icon.png" width="128" alt="Kiito icon">

# Kiito

**Hold a mouse button and move a trackball to scroll. Free and open source. The cursor stays put.**

[![macOS 26+](https://img.shields.io/badge/macOS-26%2B-black?logo=apple)](#requirements)
[![Swift 6.2](https://img.shields.io/badge/Swift-6.2-F05138?logo=swift&logoColor=white)](Package.swift)
[![License: GPL-3.0](https://img.shields.io/badge/license-GPL--3.0-blue)](https://www.gnu.org/licenses/gpl-3.0.html)
[![Latest release](https://img.shields.io/github/v/release/gabry-ts/kiito)](https://github.com/gabry-ts/kiito/releases)

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/screenshots/profile-dark.png">
  <img src="docs/screenshots/profile-light.png" alt="Kiito profile editor with scroll tuning and cursor styles" width="720">
</picture>

</div>

## Features

- Grab-scroll: hold a trigger button and move the ball, cursor frozen
- Speed, acceleration, axis lock or snap, inertia and axis reversal
- Four built-in profiles plus unlimited custom ones
- Eight cursor styles while scrolling, or none at all
- Per-app exclusions that keep the normal right click
- Menu bar with a quick toggle and automatic updates via Sparkle

## Install

```sh
brew install --cask gabry-ts/tap/kiito
```

Or download the latest `.dmg` from [Releases](https://github.com/gabry-ts/kiito/releases). Kiito updates itself automatically after that.

## Requirements

macOS 26 or later, Apple Silicon or Intel; a mouse or trackball with a spare button; Accessibility permission for the event tap.

## Build from source

```sh
./scripts/build.sh   # build/Kiito.app
open build/Kiito.app
```

## Privacy

Settings stay on your Mac; Kiito reads mouse events and the frontmost app's bundle ID for exclusions, nothing else.

## License

GNU General Public License v3.0. Copyright (C) 2026 Gabriele Partiti.
