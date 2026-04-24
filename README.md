# MacMemoApp

`MacMemoApp` is a lightweight macOS memo app built with SwiftUI.

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
- packages it as `MacMemoApp.zip`
- uploads it to a GitHub Release

You can publish in two ways:

```bash
git tag v1.0.0
git push origin v1.0.0
```

Or run the `Build Release` workflow manually from the GitHub Actions tab and enter a tag like `v1.0.0`.

The downloadable file will appear in the repository `Releases` section.
