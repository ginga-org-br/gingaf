# Changelog

## 0.3

- Support to settings menu to allow pause, resume, and maange users.
- Support to ginga_config.json as param, or automatically load when present in app folder.
- Support to embed NCL in NCL and embed HTML in NCL.
- New gingacc package to concentrate ccws, configuration, user data, and src functions.

## 0.2

- Move vscode to [ginga-code](https://github.com/ginga-org-br/ginga-code) and update `make release` for Windows and Linux to generate the zip used by ginga-code.
- Update folder structure to let the root be the Flutter app root (better vscode support). Now the `packages` folder has the Dart components following Flutter best practices. `node` folder has a inital npm package and playground.
- Add initial NCL multi-user support

## 0.1

- Add minimal run of Ginga-NCL, Ginga-HTML, and Ginga-CC-WebServices runtimes working cross-platform with working primeiro Joao examples. `ncldoc` can run headless with tick-based debug.
- Add `playground` to launch applications from web (playground) and `vscode` to launch from desktop (vscode).
