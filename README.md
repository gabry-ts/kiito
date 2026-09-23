# Kiito

Kiito is a personal macOS menu bar app that turns a trackball into a scroll tool: hold a
trigger button and move the ball to scroll, with the cursor frozen in place. A click without
movement is passed through as a normal click.

## Features

- Hold a trigger button (right, middle, button 4 or button 5) and move the ball to scroll;
  release to click normally if the ball didn't move past the threshold.
- Optional "Stay On" mode that toggles scrolling on and off with a click, instead of holding
  the trigger down.
- Adjustable speed, acceleration, axis lock, inertia (with a throw duration control) and
  direction reversal per axis.
- Four cursor styles while scrolling, including a custom circular cursor.
- Multiple profiles, switchable from the menu bar.
- Per-app exclusions: apps in the list keep their normal right click.
- Launch at login, and a hideable menu bar icon.

## Requirements

- macOS 26 or later.
- A trackball or mouse with a spare button to use as the trigger.
- Accessibility permission, to install the event tap that intercepts mouse events.

## Build

```
scripts/build.sh
```

This builds a release binary with Swift Package Manager, assembles `build/Kiito.app`, and
code-signs it with a local Apple Development identity so the Accessibility grant survives
rebuilds.

## Install

1. Copy `build/Kiito.app` to `/Applications`. Kiito uses `SMAppService` for "launch at
   login", which only works reliably when the app lives in `/Applications`.
2. Launch Kiito. On first launch it asks for Accessibility permission; grant it and settings
   will open automatically the first time.
3. If a rebuild ever invalidates the Accessibility grant, remove and re-add Kiito in
   System Settings > Privacy & Security > Accessibility.

## Reopening settings

Kiito runs as a menu bar app with no Dock icon. If the menu bar icon is hidden, relaunch
Kiito from Spotlight or Finder to bring the settings window back.

## Settings location

Profiles, excluded apps and general preferences are stored as JSON at
`~/Library/Application Support/Kiito/settings.json`.

## Uninstall

Quit Kiito, remove it from `/Applications`, and delete
`~/Library/Application Support/Kiito` if you want to clear its settings too. If you enabled
launch at login, disable it first from Kiito's settings or from System Settings > General >
Login Items.

## Notes

Hiding the system cursor while scrolling relies on an undocumented CoreGraphics connection
property (`SetsCursorInBackground`), since a background app cannot otherwise change the
global cursor. If that private call is unavailable, Kiito falls back to drawing its cursor
overlay on top of the system cursor.

## License

None yet.
