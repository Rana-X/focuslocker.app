# Focus Locker Release Flow

This repo now supports two build paths:

- `./scripts/build-app.sh` for a local ad-hoc bundle you can run on your own Mac
- Xcode Archive/Export for production distribution, notarization, Sparkle updates, and DMG packaging

## Prerequisites

- Full Xcode installed and selected with `xcode-select`
- Developer ID Application certificate in your keychain
- Apple notarization profile configured for `notarytool`
- `xcodegen` installed if you want to regenerate the Xcode project from `project.yml`

## One-Time Setup

1. Replace `REPLACE_WITH_SPARKLE_PUBLIC_EDDSA_KEY` in `AppResources/Info.plist` with your Sparkle public key.
2. Replace `REPLACE_WITH_TEAM_ID` in `release/exportOptions.plist` or pass `TEAM_ID=...` when archiving.
3. Host your Sparkle appcast over HTTPS and point `SUFeedURL` at it.
4. Generate the Xcode project:

```bash
./scripts/generate-xcode-project.sh
```

## Create A Signed App

```bash
TEAM_ID=YOURTEAMID ./scripts/archive-release.sh
```

This archives and exports `FocusLocker.app` into `build/export/`.

## Notarize And Staple

```bash
NOTARY_PROFILE=focuslocker ./scripts/notarize-release.sh build/export/FocusLocker.app
```

## Validate Gatekeeper

```bash
./scripts/validate-release.sh build/export/FocusLocker.app
```

## Create The DMG

```bash
./scripts/create-dmg.sh build/export/FocusLocker.app
```

## Sparkle Releases

1. Build and notarize the new app.
2. Generate the update archive that Sparkle expects.
3. Sign the archive with your Sparkle private EdDSA key.
4. Publish the archive and new appcast entry to your HTTPS update host.

The local SwiftPM build does not embed Sparkle. Sparkle is intended for the Xcode release build described above.
