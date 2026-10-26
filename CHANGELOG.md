# Changelog

## 0.3

- Add settings menu to pause, resume, and manage multi-user sessions.
- Support application configuration via `ginga_config.json`, CLI parameter, or environment variable.
- Support embedding NCL in NCL and HTML in NCL.
- New `gingacc` package concentrating CC WebServices, configuration, user data, and runtime sources.
- Add Debian package (`.deb`) generation for Linux with Ubuntu 22.04+ compatibility.
- Add multi-distro containerized test suite (`make test-linux-distros`) and builder (`make release-linux-deb`).
- Add Node serve local examples (`make serve-examples`).

## 0.2

- Move vscode to [ginga-code](https://github.com/ginga-org-br/ginga-code) and update `make release` for Windows and Linux to generate the zip used by ginga-code.
- Update folder structure to let the root be the Flutter app root (better vscode support). Now the `packages` folder has the Dart components following Flutter best practices. `node` folder has a inital npm package and playground.
- Add initial NCL multi-user support

## 0.1

- Add minimal run of Ginga-NCL, Ginga-HTML, and Ginga-CC-WebServices runtimes working cross-platform with working primeiro Joao examples. `ncldoc` can run headless with tick-based debug.
- Add `playground` to launch applications from web (playground) and `vscode` to launch from desktop (vscode).
