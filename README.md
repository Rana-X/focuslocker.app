# Focus Locker

Small native macOS focus utility that lets you lock apps from a menu bar app and automatically closes them when they launch.

## Run

```bash
swift run FocusLocker
```

## Build A Double-Clickable App

```bash
./scripts/build-app.sh
```

That produces:

```bash
dist/FocusLocker.app
```

You can move that app bundle into `/Applications` and launch it normally from Finder.

The first launch opens the manager window. After that, the app lives in the macOS menu bar until you choose `Disable All Locks and Quit`.

## What v1 Includes

- Auto-discovers installed apps from standard macOS application folders
- Lock and unlock apps from one searchable list
- Persists locked apps locally
- Terminates locked apps when they launch or become active
- Keeps locked apps closed silently until you manually unlock them in the manager
- Uses a lightweight `launchd` guardian while locks are active so the locker comes back after a normal force-quit

## Notes

- This is a personal focus tool, not tamper-proof security
- Some system-critical apps are intentionally marked unavailable
- Persistence-after-force-quit is best-effort for normal personal use, not hardened anti-tamper protection
- The package is set up so you can also open `Package.swift` in Xcode later if you want a full app-bundle workflow
