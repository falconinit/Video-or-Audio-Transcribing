# Update-WindowsTerminal.ps1
# Checks for Windows Terminal (wt.exe); installs if missing, otherwise updates via winget.

# Ensure winget is available
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "winget not found. Installing Winget via Chocolatey..." -ForegroundColor Yellow
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Host "Chocolatey not found. Please install Chocolatey first." -ForegroundColor Red
        Exit 1
    }
    choco install microsoft-windows-terminal -y
    # After install, winget should be present in latest Windows 10/11
}

# Check for wt.exe (Windows Terminal)
if (Get-Command wt.exe -ErrorAction SilentlyContinue) {
    Write-Host "Windows Terminal detected. Attempting to update..." -ForegroundColor Cyan
    winget upgrade --id Microsoft.WindowsTerminal -e --silent --accept-package-agreements --accept-source-agreements |
        Write-Host
    Write-Host "Update complete." -ForegroundColor Green
} else {
    Write-Host "Windows Terminal not installed. Installing now..." -ForegroundColor Cyan
    winget install --id Microsoft.WindowsTerminal -e --silent --accept-package-agreements --accept-source-agreements |
        Write-Host
    Write-Host "Installation complete." -ForegroundColor Green
}