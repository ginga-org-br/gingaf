# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.0] - 2026-11-18

### Added

- Add `playground` package with integratedcode editor, Language Server Protocol (LSP) diagnostics/completions/hover/symbols, Debug Adapter Protocol (DAP) breakpoint debugging, multi-file tabs, and inline categorized `CatalogGridView` navigation (`make run-playground-web`, `make run-playground-desktop`).
- Add `plugins` package with examples like: panoramic video support using `.ncl360`  and SRT subtitles.
- Add TV 3.0 testbed integration (`tv3ws_client`, transparent overlay mode, and remote key/time/stream event bridge).

### Changed

- Standardize widget and test filenames in `packages/nclui` with the `_widget.dart` and `_widget_test.dart` suffixes
- make `dartdoc` API generation (`make dartdoc`) to document the public `Ginga` entry widget.

### Fixed

- Load and apply per-example `ginga_config.json` (`mainAvSrc`, users, and system variables) when selecting or running applications from the Playground catalog.
- Exclude `SettingsMenu` overlay controls from stealing NCL focus navigation and allow launching desktop Playground mode without pre-specifying `APP` or `CONFIG`.

## [0.3.0] - 2026-10-26

### Added

- Add settings menu to pause, resume, and manage multi-user sessions.
- Support application configuration via `ginga_config.json`, CLI parameter, or environment variable.
- Support embedding NCL in NCL and HTML in NCL.
- New `gingacc` package concentrating CC WebServices, configuration, user data, and runtime sources.
- Add Debian package (`.deb`) generation for Linux with Ubuntu 22.04+ compatibility.
- Add multi-distro containerized test suite (`make test-linux-distros`) and builder (`make release-linux-deb`).
- Add Node serve local examples (`make serve-examples`).

## [0.2.0]

### Changed

- Move vscode to [ginga-code](https://github.com/ginga-org-br/ginga-code) and update `make release` for Windows and Linux to generate the zip used by ginga-code.
- Update folder structure to let the root be the Flutter app root (better vscode support). Now the `packages` folder has the Dart components following Flutter best practices. `node` folder has an initial npm package and playground.
- Add initial NCL multi-user support.

## [0.1.0]

### Added

- Add minimal run of Ginga-NCL, Ginga-HTML, and Ginga-CC-WebServices runtimes working cross-platform with working Primeiro Joao examples. `ncldoc` can run headless with tick-based debug.
- Add `playground` to launch applications from web (playground) and `vscode` to launch from desktop (vscode).
