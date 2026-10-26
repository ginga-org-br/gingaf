# Build

`gingaf` is based on Flutter. Set up the development environment using the platform specification files below.

## Table of Contents

- [Build-Edit-Test Workflow](#build-edit-test-workflow)
- [Host Dependencies](#host-dependencies)
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

## Build-Edit-Test Workflow

1. Fork or branch from `main`.
2. Configure host dependencies (see [Host Dependencies](#host-dependencies)).
3. Install development dependencies and generate plugins: `make deps`.
4. Implement changes or bug fixes.
5. Run unit tests to verify functionality: `make test`.
6. Run local examples to verify end-to-end behavior: `make run-example app=video.ncl`.

## Host Dependencies

### Windows

Automated setup using the Windows dependency setup script [windows/install-host-deps-windows.ps1](windows/install-host-deps-windows.ps1):

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
./windows/install-host-deps-windows.ps1
```

### Linux

Automated setup using the dependency installation script [linux/install-host-deps-ubuntu.sh](linux/install-host-deps-ubuntu.sh):

```bash
bash linux/install-host-deps-ubuntu.sh
```

#### WSL2 GUI Setup (Windows Subsystem for Linux)

If developing inside WSL2 on Windows, enable WSLg GUI support in `C:\Users\<username>\.wslconfig` like below, so the Ginga player desktop application and VS Code windows can open properly. Apply changes by restarting WSL in Windows PowerShell `powershell wsl --shutdown`:

```ini
[wsl2]
guiApplications=true

[system-distro-env]
WESTON_RDP_DISABLE_COPY_WARNING_TITLE=true
```

### macOS

Ensure Xcode Command Line Tools are installed:

```bash
xcode-select --install
```

Automated setup using the dependency installation script [macos/install-host-deps-macos.sh](macos/install-host-deps-macos.sh):

```bash
bash macos/install-host-deps-macos.sh
```

### Android

Automated setup using the Android SDK setup script [android/install-host-deps-android.ps1](android/install-host-deps-android.ps1) (or [android/install-host-deps-android.sh](android/install-host-deps-android.sh)):

- Windows (PowerShell):
  ```powershell
  Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
  ./android/install-host-deps-android.ps1
  ```
- Linux / macOS:
  ```bash
  bash android/install-host-deps-android.sh
  ```

Accept Android SDK licenses:

```bash
flutter doctor --android-licenses
```

To launch the Android emulator created by `install-host-deps-android`:

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
make release          # Builds release for current host platform (Windows, macOS, or Linux)
make release-web      # Builds web app (build/web)
make release-android  # Produces gingaf-v<VERSION>-android.zip (app-release.apk)
make release-windows  # Produces gingaf-v<VERSION>-windows-x64.zip
make release-linux    # Produces gingaf-v<VERSION>-linux-amd64.deb
make release-linux-deb # Produces gingaf-v<VERSION>-linux-amd64.deb via Ubuntu 22.04 container
make release-macos    # Produces gingaf-v<VERSION>-macos.zip
```

To upload or create a GitHub Release using `gh` CLI:

```bash
make release-publish
```
