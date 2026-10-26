# Release Guide

The [Makefile](./Makefile) has targets to build and publish platform release archives.

- `make release`: Builds the production release bundle for the current platform and packages it into a distributable archive (Debian `.deb` package on Linux, or `.zip` archive on Windows and macOS).

- `make release-publish`: Publishes existing release artifacts (`.zip` and `.deb`) to GitHub Releases for tag `v$(VERSION)` via `gh release upload` (or creates the release via `gh release create --generate-notes` if it does not yet exist).

## Integration with ginga-code Extension

The published release archives are consumed directly by [ginga-code](https://github.com/ginga-org-br/ginga-code), the Visual Studio Code extension for Ginga and NCL development. [The extension](https://github.com/ginga-org-br/ginga-code/blob/main/src/extension.js) checks `https://github.com/ginga-org-br/gingaf/releases/latest` to discover the latest available release version for the running platform and downloads the latest one if needed.
