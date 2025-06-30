# —————————————————————————————————————————
# 0. Download yt-dlp.exe & FFMPEG, extract FFMPEG/bin → download folder
# —————————————————————————————————————————

# Ask where to put yt-dlp.exe (and ffmpeg)
$destDir = Read-Host "Enter full path to download folder for yt-dlp.exe"
if (-not (Test-Path $destDir)) {
    Write-Host "Creating folder $destDir" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $destDir | Out-Null
}

# 0.1 Download yt-dlp.exe
Write-Host "Downloading yt-dlp.exe to $destDir…" -ForegroundColor Cyan
Start-BitsTransfer `
  -Source "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe" `
  -Destination (Join-Path $destDir "yt-dlp.exe")

# 0.2 Download ffmpeg ZIP
Write-Host "Downloading ffmpeg ZIP to $destDir…" -ForegroundColor Cyan
$zipFile = Join-Path $destDir "ffmpeg-release-essentials.zip"
Start-BitsTransfer `
  -Source "https://www.gyan.dev/ffmpeg/builds/packages/ffmpeg-7.1.1-essentials_build.zip" `
  -Destination $zipFile

# 0.3 Extract and promote bin\* → $destDir
Write-Host "Extracting ffmpeg ZIP…" -ForegroundColor Cyan
$extractDir = Join-Path $destDir "ffmpeg-temp"
Expand-Archive -Path $zipFile -DestinationPath $extractDir -Force

Write-Host "Moving ffmpeg binaries up one level…" -ForegroundColor Cyan
$binDir = Join-Path $extractDir "ffmpeg-7.1.1-essentials_build\bin"
Get-ChildItem -Path $binDir -File | Move-Item -Destination $destDir -Force

# 0.4 Clean up ZIP and temp folder
Remove-Item -Path $zipFile -Force
Remove-Item -Path $extractDir -Recurse -Force

# ————————————————————————————————
# Setup Script: Chocolatey → WinGet → pip → Extras
# ————————————————————————————————

# 1. Install Chocolatey if missing
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = `
        [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    iex ((New-Object System.Net.WebClient).DownloadString(
        'https://community.chocolatey.org/install.ps1'))
    Write-Host "Chocolatey installed" -ForegroundColor Green

    # Import Chocolatey profile and refresh env so PATH is live immediately
    Import-Module "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
    refreshenv
} else {
    Write-Host "Chocolatey already installed" -ForegroundColor Yellow
}

# 2. Helpers
function CommandExists { param([string]$c) $null -ne (Get-Command $c -ErrorAction SilentlyContinue) }
function IsWingetInstalled { param([string]$n) winget list | Select-String $n }

# 3. Install core via Chocolatey
choco install python git winget ffmpeg -y
Write-Host "Installed Python, Git, WinGet & FFmpeg" -ForegroundColor Green

# 4. Fallback to WinGet for Python
if (-not (CommandExists "python")) {
    Write-Host "Installing Python 3.11 via WinGet..." -ForegroundColor Yellow
    winget install --id Python.Python.3.11 -e --silent
} else {
    Write-Host "Python present" -ForegroundColor Green
}

# 5. Ensure pip
if (-not (CommandExists "pip")) {
    Write-Host "Installing pip..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri https://bootstrap.pypa.io/get-pip.py -OutFile get-pip.py
    python get-pip.py
    Remove-Item get-pip.py
    Write-Host "pip installed" -ForegroundColor Green
} else {
    Write-Host "pip already present" -ForegroundColor Green
}

# 6. Upgrade pip & install Python packages
Write-Host "Upgrading pip and installing packages..." -ForegroundColor Cyan
python -m pip install --upgrade pip

pip install `
    git+https://github.com/openai/whisper.git `
    numpy==1.26.4 numba==0.60.0 `
    pandas matplotlib scipy notebook Flask Django `
    scikit-learn tensorflow torch torchvision torchaudio `
    keras nltk spacy transformers SpeechRecognition `
    pydub ffmpeg-python requests beautifulsoup4 pillow `
    opencv-python moviepy tkinter whisper pyinstaller -y

Write-Host "All Python packages installed" -ForegroundColor Green

# 7. Check for unmet dependencies
pip check | Write-Host
Write-Host "Dependency check complete" -ForegroundColor Green

# 8. Ensure PyTorch
try {
    $v = python -c "import torch; print(torch.__version__)"
    Write-Host "PyTorch v$v present" -ForegroundColor Green
} catch {
    Write-Host "Installing CPU-only PyTorch..." -ForegroundColor Yellow
    pip install torch torchvision torchaudio
    Write-Host "PyTorch installed" -ForegroundColor Green
}

# 9. WinGet installs: VS Code, Docker, WSL2
if (-not (IsWingetInstalled "Microsoft.VisualStudioCode")) {
    winget install --id Microsoft.VisualStudioCode -e --silent
    Write-Host "VS Code installed" -ForegroundColor Green
} else { Write-Host "VS Code present" }

if (-not (IsWingetInstalled "Docker.DockerDesktop")) {
    winget install --id Docker.DockerDesktop -e --silent
    Write-Host "Docker Desktop installed" -ForegroundColor Green
} else { Write-Host "Docker Desktop present" }

if (-not (wsl --list)) {
    Write-Host "Installing WSL2..." -ForegroundColor Cyan
    wsl --install
} else { Write-Host "WSL2 present" }

# 10. Update PATH for Python & Git
$scopes = @("Machine","User")
$dirs   = @(
    (Join-Path $env:LOCALAPPDATA "Programs\Python\Python311"),
    (Join-Path $env:LOCALAPPDATA "Programs\Python\Python311\Scripts"),
    "C:\Program Files\Git\cmd"
)

foreach ($scope in $scopes) {
    $p    = [Environment]::GetEnvironmentVariable("Path",[EnvironmentVariableTarget]::$scope)
    $orig = $p
    foreach ($d in $dirs) {
        if (-not ($p -like "*$d*")) { $p += ";$d" }
    }
    if ($p -ne $orig) {
        [Environment]::SetEnvironmentVariable("Path",$p,[EnvironmentVariableTarget]::$scope)
        Write-Host "Updated $scope PATH" -ForegroundColor Green
    } else {
        Write-Host "$scope PATH already up-to-date" -ForegroundColor Yellow
    }
}

# 11. Optionally package your transcription script
$scriptPath = "path\to\your\video_transcribe.py"
if (Test-Path $scriptPath) {
    Write-Host "Packaging script..." -ForegroundColor Cyan
    pyinstaller --onefile $scriptPath
    Write-Host "Executable in ./dist" -ForegroundColor Green
} else {
    Write-Host "No script at $scriptPath – skipping packaging" -ForegroundColor Yellow
}

Write-Host "Setup complete!" -ForegroundColor Magenta