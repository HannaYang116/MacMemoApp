# MacMemoApp

`MacMemoApp` is a lightweight macOS memo app built with SwiftUI.

## Open In Xcode

```bash
open MacMemoApp.xcodeproj
```

## Features

- Single-window memo editor
- Automatic local saving
- Last-saved timestamp indicator
- Native macOS layout with a clean writing area

## Run

```bash
swift run
```

The note content is stored in the user's Application Support directory.

## Build App Bundle

To create a double-clickable macOS app bundle:

```bash
./scripts/build_app.sh
```

This generates:

```bash
dist/MacMemoApp.app
```

## GitHub Release Automation

To let other people download the app without setting up Swift or Xcode, use GitHub Releases instead of the source ZIP.

This repo now includes a GitHub Actions workflow that:

- builds `MacMemoApp.app`
- packages it as `MacMemoApp.dmg`
- uploads it to a GitHub Release

You can publish in two ways:

```bash
git tag v1.0.0
git push origin v1.0.0
```

Or run the `Build Release` workflow manually from the GitHub Actions tab and enter a tag like `v1.0.0`.

The downloadable file will appear in the repository `Releases` section.

## Sparkle Auto Updates

Sparkle is now wired into the Xcode app target.

- Appcast feed URL: `https://hannayang116.github.io/MacMemoApp/updates/appcast.xml`
- Public EdDSA key is stored in [Info.plist](/Users/apple/Documents/New%20project/MacMemoApp/Info.plist)
- Update controller lives in [AppUpdater.swift](/Users/apple/Documents/New%20project/Sources/MacMemoApp/AppUpdater.swift)

To prepare a Sparkle release locally:

```bash
./scripts/prepare_sparkle_release.sh 1.0.0
```

This will:

- build the app with version metadata
- create `dist/MacMemoApp.dmg`
- copy a versioned archive into `docs/updates/`
- generate `docs/updates/appcast.xml`

The DMG format is intentional here. Sparkle's documentation recommends distributing website downloads as a signed and notarized DMG because ZIP downloads can trigger app translocation, which blocks in-place updates. After users drag the app out of the DMG in Finder, they can keep it in any writable folder, not only `/Applications`.

For GitHub Actions releases, add a repository secret named `SPARKLE_PRIVATE_KEY` containing your exported Sparkle private key. Without this secret, appcast signing will not work in CI.
