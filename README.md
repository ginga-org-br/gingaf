# gingaf

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)

`gingaf` is an MIT-licensed, multi-platform implementation of the interactive TV middleware Ginga standardised by ITU-T and SBTVD.

## Architecture

The `gingaf` repository is organized as a host-centric monorepo: the root directory (`.`) contains the Flutter visual host application for Ginga applications. It depends on core Dart packages in `packages/ncldoc/` (the headless execution engine, see [packages/ncldoc/README.md](packages/ncldoc/README.md)) and `packages/ccws/` (the web service library, see [packages/ccws/README.md](packages/ccws/README.md)). While `node/` provides the Node.js middleware and web interactive playground (see [node/README.md](node/README.md)).

User-level applications built on top of `gingaf` include [ginga-playground](https://ginga-org-br.github.io/gingaf/playground/) (for web-based evaluation) and [ginga-code](https://github.com/ginga-org-br/ginga-code) (a Visual Studio Code extension for application development).

```mermaid
block-beta
columns 3
  playground["playground"]
  ginga_code["ginga-code"]
  space
  web["gingaf (web)"]
  desktop["gingaf (desktop)"]
  mobile["gingaf (mobile)"]
  gingaf["gingaf"]:3
  ncldoc["ncldoc"]:2
  ccws["ccws"]:1
```

## Demonstration Videos

### Windows

https://github.com/user-attachments/assets/07c9fb0f-a9f1-406b-b650-fa4eee331af0

### Android

https://github.com/user-attachments/assets/5bbecb80-04c7-4574-88d5-e979d1c11e22

### Chrome

https://github.com/user-attachments/assets/b04eabac-4636-453c-beec-7ec845d841a4

### NCL headless

https://github.com/user-attachments/assets/576cba53-04b7-4b55-b4a5-97d1b78f4a79

### Playground Ginga-NCL (video.ncl)

https://github.com/user-attachments/assets/c6fd4ce3-66a5-4888-8b49-50dde510c2d8

### Playground  Ginga-HTML5 (current_service.html)

https://github.com/user-attachments/assets/3f4aa3f4-5950-4b6e-8a32-50021e8b014f

### Playground  Ginga-NCL with Lua (lua.ncl)

https://github.com/user-attachments/assets/b06bf145-4cc2-4431-9f00-98b218cfedde

### Launch Ginga Application from VSCode

https://github.com/user-attachments/assets/717948df-64ab-42c9-8dd6-3a4a2e3603da

## gingaf (desktop) run applications from local `examples/`

All example NCL and HTML documents are stored in the `examples/` folder. You can configure and run the application via APP environment variable (e.g. `examples/image.ncl` or `examples/image.html`).

```bash
flutter run -d windows --dart-define="APP=examples/image.ncl"
flutter run -d windows --dart-define="APP=examples/video.ncl"
```

For convenience, you can use `make run-example` for the current platform:

```bash
make run-example app=viode.ncl
make run-example app=image.html
make run-example app=primeiro-joao/00syncProp.ncl
```

## gingaf (web, mobile) run applications from URLs

```bash
flutter run -d chrome --dart-define="APP=https://raw.githubusercontent.com/ginga-org-br/gingaf/refs/heads/main/ginga/examples/primeiro-joao/00syncProp.ncl"
```
