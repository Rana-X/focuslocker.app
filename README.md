# Focus Locker

Native macOS focus utility with a Dock app for management and a bundled background helper that keeps locked apps closed after you quit the main window.

## Run

```bash
swift run FocusLocker
```

## Local App Bundle

```bash
./scripts/build-app.sh
```

That produces an ad-hoc local bundle:

```bash
dist/FocusLocker.app
```

The built app bundle includes a nested `FocusLockerAgent.app` in `Contents/Library/LoginItems/`.

You can move `dist/FocusLocker.app` into `/Applications` and launch it normally from Finder.

## Runtime Design

- Auto-discovers installed apps from standard macOS application folders
- Lock and unlock apps from one searchable list
- Persists active lock state in `~/Library/Application Support/FocusLocker/lock-state.json`
- Reopens cleanly from Finder or Dock without spawning duplicate UI instances
- Registers a background login-item helper with `SMAppService`
- Terminates locked apps when they launch or become active
- Keeps locked apps closed until you manually unlock them in the manager or the helper menu

## Production Release

The production distribution path now lives in:

- `project.yml` for the XcodeGen project definition
- `release/RELEASE.md` for the release checklist
- `scripts/archive-release.sh` for Xcode archive/export
- `scripts/notarize-release.sh` for notarization
- `scripts/create-dmg.sh` for the DMG
- `scripts/validate-release.sh` for Gatekeeper validation

Sparkle updater keys are declared in `AppResources/Info.plist`, but the updater framework is intended for the Xcode release build, not the raw SwiftPM bundle.

## Notes

- This is a personal focus tool, not tamper-proof security
- Some system-critical apps are intentionally marked unavailable
- Quitting the main app does not disable active locks while the helper remains registered
- `Disable All Locks and Quit` clears the shared lock state and unregisters the helper
- The helper currently uses a tight fallback sweep because login-item workspace notifications are not fully reliable on this machine
- Full signing, notarization, and Sparkle validation require a Mac with full Xcode installed
