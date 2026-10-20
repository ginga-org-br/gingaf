# Build

`gingaf` is based on Flutter. Set up the development environment using the platform specification files below.

## Table of Contents

- [Build-Edit-Test Workflow](#build-edit-test-workflow)
- [Prerequisites by Platform](#prerequisites-by-platform)
  - [Windows](#windows)
  - [Linux](#linux)
  - [macOS](#macos)
  - [Android](#android)
- [Development Environment Setup](#development-environment-setup)
- [Running Applications](#running-applications)
  - [Running Local Examples](#running-local-examples)
  - [Running from URLs](#running-from-urls)
  - [Web Playground Server](#web-playground-server)
- [Testing](#testing)
- [Documentation](#documentation)
- [Cleaning Build Artifacts](#cleaning-build-artifacts)
- [Releases](#releases)
- [Plugins](#plugins)

## Build-Edit-Test Workflow

1. Fork or branch from `main`.
2. Configure platform prerequisites (see [Prerequisites by Platform](#prerequisites-by-platform)).
3. Install development dependencies and generate plugins: `make deps`.
4. Implement changes or bug fixes.
5. Run unit tests to verify functionality: `make test`.
6. Run local examples to verify end-to-end behavior: `make run-example app=video.ncl`.

## Prerequisites by Platform

### Windows

Automated setup using the Windows dependency setup script [windows/install-deps-windows.ps1](windows/install-deps-windows.ps1):

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
./windows/install-deps-windows.ps1
```

### Linux

Automated setup using the dependency installation script [linux/install-deps-ubuntu.sh](linux/install-deps-ubuntu.sh):

```bash
bash linux/install-deps-ubuntu.sh
```

### macOS

Ensure Xcode Command Line Tools are installed:

```bash
xcode-select --install
```

Automated setup using the dependency installation script [macos/install-deps-macos.sh](macos/install-deps-macos.sh):

```bash
bash macos/install-deps-macos.sh
```

### Android

Automated setup using the Android SDK setup script [android/install-deps-android.ps1](android/install-deps-android.ps1) (or [android/install-deps-android.sh](android/install-deps-android.sh)):

- Windows (PowerShell):
  ```powershell
  Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
  ./android/install-deps-android.ps1
  ```
- Linux / macOS:
  ```bash
  bash android/install-deps-android.sh
  ```

Accept Android SDK licenses:

```bash
flutter doctor --android-licenses
```

To launch the Android emulator created by `install-deps-android`:

```bash
flutter emulators --launch flutter_dev
flutter devices
```

## Development Environment Setup

Install dependencies across all Flutter workspace packages and generate the plugin registry:

```bash
make deps
```

## Running Applications

### Running Local Examples

Example NCL, Lua, and HTML documents are stored in `examples/`. Use `make run-example` specifying the `app` parameter:

```bash
make run-example app=video.ncl
make run-example app=image.html
```

To specify a target device:

```bash
make run-example app=video.ncl d=linux
make run-example app=video.ncl d=windows
make run-example app=video.ncl d=macos
make run-example app=video.ncl d=chrome
```

Direct Flutter command:

```bash
flutter run --no-pub -d <device> --dart-define="GINGA_APP=examples/video.ncl"
```

### Running from URLs

Run applications directly from remote URLs:

```bash
flutter run --no-pub -d chrome --dart-define="GINGA_APP=https://raw.githubusercontent.com/ginga-org-br/gingaf/refs/heads/main/examples/video.ncl"
```

For Android emulator:

```bash
flutter run --no-pub -d emulator-5554 --dart-define="GINGA_APP=https://raw.githubusercontent.com/ginga-org-br/gingaf/refs/heads/main/examples/video.ncl"
```

### Web Playground Server

To build dependencies and launch the local web playground server:

```bash
make serve
```

This starts the playground server at `http://localhost:5173/gingaf/playground/index.html`.

## Testing

Run unit tests across all workspace packages:

```bash
make test
```

Run integration tests:

```bash
make integration_test
make integration_test d=linux
```

## Documentation

Generate Mermaid diagrams and Dart API documentation:

```bash
make doc
```

## Cleaning Build Artifacts

Clean Flutter and Node build outputs:

```bash
make clean
```

## Releases

To build a release package for a target platform:

```bash
make release-web      # Builds web app (build/web)
make release-windows  # Produces gingaf-v<VERSION>-windows-x64.zip
make release-linux    # Produces gingaf-v<VERSION>-linux-x64.zip
make release-macos    # Produces gingaf-v<VERSION>-macos.zip
make release-android  # Produces gingaf-v<VERSION>-android.zip (app-release.apk)
```

To upload or create a GitHub Release using `gh` CLI:

```bash
make release-publish
```
