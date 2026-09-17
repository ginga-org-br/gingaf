# Setup

`gingaf` is based in Flutter. So first [install Flutter SDK from](https://docs.flutter.dev/install/manual).

## Table of Contents

- [At Windows, build for Windows and Chrome](#at-windows-build-for-windows-and-chrome)
- [At Windows, build for Android](#at-windows-build-for-android)
- [At Linux, build for Android](#at-linux-build-for-android)

### At windows, build for windows and chrome

To instal depdencies, do commands below. Flutter requires Microsoft.VisualStudio.2019.BuildTools. The `webview_all_windows` plugin requires **Windows SDK 10.0.22621.0** (Windows 11 SDK) or later. Native Windows WebView requires `nuget.exe.

```powershell
winget install --id Microsoft.WindowsSDK.10.0.22621 --source winget
winget install --id Microsoft.VisualStudio.2019.BuildTools --override "--passive --wait --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
winget install --id Microsoft.NuGet
```

At gingaf folder, run this command:

```powershell
New-Item -ItemType Directory -Force -Path build/windows/x64/packages
nuget install Microsoft.Windows.ImplementationLibrary -Version 1.0.220914.1 -ExcludeVersion -OutputDirectory build/windows/x64/packages
nuget install Microsoft.Web.WebView2 -Version 1.0.1210.39 -ExcludeVersion -OutputDirectory build/windows/x64/packages
```

Then, to configure, do:

```powershell
flutter config --enable-web
flutter config --enable-windows-desktop
flutter pub get
flutter build windows
flutter build web
```

You may test by:

```powershell
flutter run -d windows --dart-define="APP=examples/video.ncl"
```

### At windows, build for android

Install java and make sure `JAVA_HOME` is set. You can do the below.

```powershell
winget install EclipseAdoptium.Temurin.25.JDK
# at a new shell
echo $env:JAVA_HOME
java --version
```

Make sure you have `ANDROID_HOME`. You can do the below.

```powershell
New-Item -Path "C:\Android\cmdline-tools\latest" -ItemType Directory -Force
Invoke-WebRequest -Uri "https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip" -OutFile "$env:TEMP\cmdline-tools.zip"
Expand-Archive -Path "$env:TEMP\cmdline-tools.zip" -DestinationPath "$env:TEMP\cmdline-tools" -Force
Move-Item -Path "$env:TEMP\cmdline-tools\cmdline-tools\*" -Destination "C:\Android\cmdline-tools\latest\" -Force
Remove-Item "$env:TEMP\cmdline-tools.zip", "$env:TEMP\cmdline-tools" -Recurse -Force
[System.Environment]::SetEnvironmentVariable("ANDROID_HOME", "C:\Android", [System.EnvironmentVariableTarget]::User)
$user_path = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::User)
[System.Environment]::SetEnvironmentVariable("Path", "$user_path;C:\Android\cmdline-tools\latest\bin", [System.EnvironmentVariableTarget]::User)
# at a new shell
echo $env:ANDROID_HOME
sdkmanager.bat --version
```

Then, to configure and build, do at gingaf folder:

```powershell
flutter doctor --android-licenses
flutter config --enable-android
flutter pub get
flutter build apk
```

If you need emulate android device, you can create and find get a device id as below:

```powershell
sdkmanager "system-images;android-34;google_apis;x86_64"
avdmanager create avd -n flutter_dev  -k "system-images;android-34;google_apis;x86_64"
flutter emulators --launch flutter_dev
flutter devices
```

Finnaly to run an application at an virutal device called `emulator-5554`, do:

```powershell
flutter run --no-pub -d emulator-5554 --dart-define="APP=https://raw.githubusercontent.com/ginga-org-br/gingaf/refs/heads/main/examples/video.ncl"
```

### At linux, build for android

```bash
sudo snap install flutter --classic
sudo apt install -y cmake ninja-build clang pkg-config libgtk-3-dev libwebkit2gtk-4.1-dev libmpv-dev mpv
```

Then, to configure, do:

```powershell
flutter config --enable-linux-desktop
flutter pub get
flutter build linux
```

You may test by:

```powershell
flutter run -d linux --dart-define="APP=examples/video.ncl"
```