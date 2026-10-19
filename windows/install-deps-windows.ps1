[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

Write-Host "Installing Windows dependencies via WinGet..."

$git = Get-Command git -ErrorAction SilentlyContinue
if (-not $git) {
    Write-Host "Installing Git..."
    winget install --id Git.Git -e --silent --accept-source-agreements --accept-package-agreements
}

$nuget = Get-Command nuget -ErrorAction SilentlyContinue
if (-not $nuget) {
    Write-Host "Installing NuGet CLI..."
    winget install --id Microsoft.NuGet -e --silent --accept-source-agreements --accept-package-agreements
}

Write-Host "Installing Visual Studio 2022 Build Tools with C++ Desktop workload..."
winget install --id Microsoft.VisualStudio.2022.BuildTools -e --silent --accept-source-agreements --accept-package-agreements --override "--passive --wait --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"

$flutter = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutter) {
    if (-not (Test-Path "C:\src\flutter")) {
        Write-Host "Cloning Flutter SDK..."
        git clone https://github.com/flutter/flutter.git -b stable C:\src\flutter
    }
    $userPath = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::User)
    if ($userPath -notlike "*C:\src\flutter\bin*") {
        Write-Host "Adding Flutter to user PATH..."
        [System.Environment]::SetEnvironmentVariable("Path", "$userPath;C:\src\flutter\bin", [System.EnvironmentVariableTarget]::User)
        $env:Path = "C:\src\flutter\bin;$env:Path"
    }
}

Write-Host "Windows dependencies installed successfully."
