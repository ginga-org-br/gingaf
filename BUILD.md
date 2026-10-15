# Build

`gingaf` is based on Flutter. First [install Flutter SDK](https://docs.flutter.dev/install/manual).

## Table of Contents

- [Prerequisites by Platform](#prerequisites-by-platform)
  - [Windows](#windows)
  - [Linux](#linux)
  - [macOS](#macos)
  - [Android](#android)
- [Installing Dependencies](#installing-dependencies)
- [Running Applications](#running-applications)
  - [Running Local Examples](#running-local-examples)
  - [Running from URLs](#running-from-urls)
  - [Web Playground Server](#web-playground-server)
- [Testing](#testing)
- [Documentation](#documentation)
- [Cleaning Build Artifacts](#cleaning-build-artifacts)
- [Releases](#releases)

## Prerequisites by Platform

### Windows

Install core utilities and native build tools via `winget`:

```powershell
winget install coreutils
winget install --id Microsoft.WindowsSDK.10.0.22621 --source winget
winget install --id Microsoft.VisualStudio.2019.BuildTools --override "--passive --wait --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
winget install --id Microsoft.NuGet
```

Install native Windows WebView packages:

```powershell
New-Item -ItemType Directory -Force -Path build/windows/x64/packages
nuget install Microsoft.Windows.ImplementationLibrary -Version 1.0.220914.1 -ExcludeVersion -OutputDirectory build/windows/x64/packages
nuget install Microsoft.Web.WebView2 -Version 1.0.1210.39 -ExcludeVersion -OutputDirectory build/windows/x64/packages
```

Enable Flutter platforms:

```powershell
flutter config --enable-windows-desktop
flutter config --enable-web
```

### Linux

Install native build tools, GTK, WebKit, and MPV libraries:

```bash
sudo apt update
sudo apt install -y cmake ninja-build clang pkg-config libgtk-3-dev libwebkit2gtk-4.1-dev libmpv-dev mpv
```

Enable Linux desktop platform:

```bash
flutter config --enable-linux-desktop
```

### macOS

Ensure Xcode and Command Line Tools are installed:

```bash
xcode-select --install
flutter config --enable-macos-desktop
```

### Android

Install Java JDK and make sure `JAVA_HOME` is set:

```powershell
winget install EclipseAdoptium.Temurin.25.JDK
```

Ensure Android command-line tools and SDK are configured:

```powershell
New-Item -Path "C:\Android\cmdline-tools\latest" -ItemType Directory -Force
Invoke-WebRequest -Uri "https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip" -OutFile "$env:TEMP\cmdline-tools.zip"
Expand-Archive -Path "$env:TEMP\cmdline-tools.zip" -DestinationPath "$env:TEMP\cmdline-tools" -Force
Move-Item -Path "$env:TEMP\cmdline-tools\cmdline-tools\*" -Destination "C:\Android\cmdline-tools\latest\" -Force
Remove-Item "$env:TEMP\cmdline-tools.zip", "$env:TEMP\cmdline-tools" -Recurse -Force
[System.Environment]::SetEnvironmentVariable("ANDROID_HOME", "C:\Android", [System.EnvironmentVariableTarget]::User)
$user_path = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::User)
[System.Environment]::SetEnvironmentVariable("Path", "$user_path;C:\Android\cmdline-tools\latest\bin", [System.EnvironmentVariableTarget]::User)
```

Accept Android SDK licenses and configure Flutter:

```powershell
flutter doctor --android-licenses
flutter config --enable-android
```

To create and launch an Android emulator:

```powershell
sdkmanager "system-images;android-34;google_apis;x86_64"
avdmanager create avd -n flutter_dev -k "system-images;android-34;google_apis;x86_64"
flutter emulators --launch flutter_dev
flutter devices
```

## Installing Dependencies

Install Flutter workspace dependencies:

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
