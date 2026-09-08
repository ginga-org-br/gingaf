# Release Guide

The [Makefile](./Makefile) has targets to build and publish platform release archives.

- `make release`: Builds the production release bundle for the current platform and packages it into a distributable zip archive. It detects the host platform and architecture, gets the version from `pubspec.yaml`, builds (`flutter build <platform> --release`), and compresses the release bundle into a zip archive following the naming convention `gingaf-v$(VERSION)-$(PLATFORM).zip` (for example, `gingaf-v0.2.0-windows-x64.zip`).

- `make release-publish`: Packages the release and publishes the resulting zip archive to GitHub Releases. It executes `make release` and uploads the zip archive to the release tagged `v$(VERSION)` via `gh release upload v$(VERSION) $(ZIP_NAME) --clobber`. If the release does not exist yet, it creates the release automatically with release notes via `gh release create v$(VERSION) $(ZIP_NAME) --generate-notes`.

## Integration with ginga-code Extension

The published release archives are consumed directly by [ginga-code](https://github.com/ginga-org-br/ginga-code), the Visual Studio Code extension for Ginga and NCL development. [The extension](https://github.com/ginga-org-br/ginga-code/blob/main/src/extension.js) checks `https://github.com/ginga-org-br/gingaf/releases/latest` to discover the latest available release version for the running platform and downloads the latest one if needed.
