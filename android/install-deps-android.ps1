[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

Write-Host "Checking Java JDK installation..."
$java = Get-Command java -ErrorAction SilentlyContinue
if (-not $java) {
    Write-Host "Installing Eclipse Adoptium Temurin JDK via winget..."
    winget install --id EclipseAdoptium.Temurin.21.JDK -e --silent --accept-source-agreements --accept-package-agreements
}

$androidDir = "C:\Android"
$cmdlineToolsDir = "$androidDir\cmdline-tools\latest"

if (Test-Path "$androidDir\cmdline-tools\latest-2") {
    Remove-Item -Path "$androidDir\cmdline-tools\latest-2" -Recurse -Force
}

if (-not (Test-Path $cmdlineToolsDir)) {
    Write-Host "Setting up Android cmdline-tools in $cmdlineToolsDir..."
    New-Item -Path $cmdlineToolsDir -ItemType Directory -Force | Out-Null
    $zipPath = "$env:TEMP\cmdline-tools.zip"
    $tempExtract = "$env:TEMP\cmdline-tools-extract"

    Write-Host "Downloading Android command-line tools..."
    Invoke-WebRequest -Uri "https://dl.google.com/android/repository/commandlinetools-win-15859902_latest.zip" -OutFile $zipPath

    Write-Host "Extracting command-line tools..."
    Expand-Archive -Path $zipPath -DestinationPath $tempExtract -Force
    Move-Item -Path "$tempExtract\cmdline-tools\*" -Destination $cmdlineToolsDir -Force

    Remove-Item $zipPath, $tempExtract -Recurse -Force
}

Write-Host "Configuring ANDROID_HOME and PATH..."
[System.Environment]::SetEnvironmentVariable("ANDROID_HOME", $androidDir, [System.EnvironmentVariableTarget]::User)
$userPath = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::User)
$binPath = "$cmdlineToolsDir\bin"
if ($userPath -notlike "*$binPath*") {
    [System.Environment]::SetEnvironmentVariable("Path", "$userPath;$binPath", [System.EnvironmentVariableTarget]::User)
}
$env:ANDROID_HOME = $androidDir
$env:Path = "$binPath;$env:Path"

$sdkmanager = "$cmdlineToolsDir\bin\sdkmanager.bat"
$avdmanager = "$cmdlineToolsDir\bin\avdmanager.bat"

if (Test-Path $sdkmanager) {
    Write-Host "Installing Android SDK platform-tools and system image..."
    "y`ny`ny`ny`n" | & $sdkmanager --sdk_root=$androidDir "platform-tools" "platforms;android-34" "system-images;android-34;google_apis;x86_64" | Out-Null

    if (Test-Path $avdmanager) {
        Write-Host "Creating Android virtual device 'flutter_dev'..."
        & $avdmanager create avd -n flutter_dev -k "system-images;android-34;google_apis;x86_64" --device "pixel" --force | Out-Null
    }
}

Write-Host "Android SDK and emulator 'flutter_dev' configured successfully in $androidDir."
