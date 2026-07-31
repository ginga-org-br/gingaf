# gingaf

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)

Technical overview of the Ginga engine architecture and modular implementation.

## Setup

### Flutter SDK

Install the Flutter SDK from the official website:
[https://docs.flutter.dev/get-started/install/](https://docs.flutter.dev/get-started/install/)

### At windows, buding for windows and chrome

Dependencies:

The flutter requires Microsoft.VisualStudio.2019.BuildTools. The `webview_all_windows` plugin requires **Windows SDK 10.0.22621.0** (Windows 11 SDK) or later. Native Windows WebView support requires `nuget.exe` and Visual Studio Build Tools with the C++ workload.

```powershell
winget install --id Microsoft.WindowsSDK.10.0.22621 --source winget
winget install --id Microsoft.VisualStudio.2019.BuildTools --override "--passive --wait --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
```

Then, at gingaf folder, run this command:

```powershell
winget install --id NuGet.NuGet
nuget sources add -Name nuget.org -Source https://api.nuget.org/v3/index.json
New-Item -ItemType Directory -Force -Path build/windows/x64/packages
nuget install Microsoft.Windows.ImplementationLibrary -Version 1.0.220914.1 -ExcludeVersion -OutputDirectory build/windows/x64/packages
nuget install Microsoft.Web.WebView2 -Version 1.0.1210.39 -ExcludeVersion -OutputDirectory build/windows/x64/packages
```

Project configure (once per machine)

```powershell
flutter config --enable-web
flutter config --enable-windows-desktop
```

### At windows, buding for android

Dependencies:

```powershell
winget install -e --id Google.AndroidStudio
flutter config --android-sdk "$env:LOCALAPPDATA\Android\Sdk"
# 1. Open Android Studio
# 2. Go to "More Actions" > "SDK Manager"
# 3. Select the "SDK Tools" tab
# 4. Check "Android SDK Command-line Tools (latest)" and click Apply/OK
# 5. Accept the licenses:
flutter doctor --android-licenses
```

Project configure (once per machine):

```powershell
flutter config --enable-android
# Download an Android 34 system image (requires accepting licenses)
Write-Output "y" | & "$env:LOCALAPPDATA\Android\Sdk\cmdline-tools\latest\bin\sdkmanager.bat" "system-images;android-34;google_apis_playstore;x86_64"
# Create the Android Virtual Device (AVD)
Write-Output "no" | & "$env:LOCALAPPDATA\Android\Sdk\cmdline-tools\latest\bin\avdmanager.bat" create avd -n flutter_emulator -k "system-images;android-34;google_apis_playstore;x86_64" --device "pixel"
```

at `ginga` fodler and an created emulator called `emulator-5554`, run:

```
flutter run --no-pub -d emulator-5554 --dart-define="APP=examples/image.ncl"
```

## Testing

Execute the test suite for core logic and integration:

```bash
flutter test
```

## Run Ginga-NCL or Ginga-HTML applications with UI

All example NCL and HTML documents are stored in the `examples/` folder.

You can configure and run the application via environment variables or compile-time definitions (`--dart-define`):

- `APP`: Path to the application file (e.g. `examples/image.ncl` or `examples/image.html`).
- `MAINAV`: Path to the background video URI. Set it to empty or `true` to use the default butterfly video.

### Run with Flutter command

> [!IMPORTANT]
> When defining multiple parameters at compile time using `--dart-define`, they **must** be passed as separate arguments (e.g. `--dart-define="APP=..." --dart-define="MAINAV=..."`). Combining them with semicolons (e.g., `--dart-define="APP=...;MAINAV=..."`) is invalid and will cause the build or configuration validation to fail.

```bash
cd gingaf/ginga
# Using compile-time definitions
flutter run -d windows --dart-define="APP=examples/image.ncl"
flutter run -d windows --dart-define="APP=examples/video.ncl" --dart-define="MAINAV=true"
flutter run -d chrome --dart-define="APP=examples/image.ncl"
```

For convenience, you can use `make run-example` for the current platform:

```bash
cd gingaf/ginga
make run-example app=image.ncl
make run-example app=image.html
```
