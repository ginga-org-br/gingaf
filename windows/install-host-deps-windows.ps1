[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

Write-Host "Installing Windows dependencies..."

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Git..."
    winget install --id Git.Git -e --silent --accept-source-agreements --accept-package-agreements
}

winget list --id Microsoft.NuGet -e --accept-source-agreements > $null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Installing NuGet CLI..."
    winget install --id Microsoft.NuGet -e --silent --accept-source-agreements --accept-package-agreements
}

winget list --id Microsoft.VisualStudio.2022.BuildTools -e --accept-source-agreements > $null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Installing Visual Studio 2022 Build Tools with C++ Desktop workload..."
    winget install --id Microsoft.VisualStudio.2022.BuildTools -e --silent --accept-source-agreements --accept-package-agreements --override "--passive --wait --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
}

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    if (-not (Test-Path "C:\flutter")) {
        Write-Host "Cloning Flutter SDK..."
        git clone https://github.com/flutter/flutter.git -b stable C:\flutter
    }
    $userPath = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::User)
    if ($userPath -notlike "*C:\flutter\bin*") {
        Write-Host "Adding Flutter to user PATH..."
        [System.Environment]::SetEnvironmentVariable("Path", "$userPath;C:\flutter\bin", [System.EnvironmentVariableTarget]::User)
        $env:Path = "C:\flutter\bin;$env:Path"
    }
}

Write-Host "Windows dependencies installed successfully."
