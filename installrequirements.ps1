# ————————————————————————————————
# Combined Setup Script: Chocolatey → WinGet → pip → Extras
# ————————————————————————————————

# 1. Install Chocolatey if missing
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = `
        [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    iex ((New-Object System.Net.WebClient).DownloadString(
        "https://community.chocolatey.org/install.ps1"))
    Write-Host "Chocolatey installed" -ForegroundColor Green

    # Import Chocolatey profile & refresh env
    Import-Module "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
    refreshenv
} else {
    Write-Host "Chocolatey already installed" -ForegroundColor Yellow
}

# -----------------------------------------------------
# 2. Helpers
# -----------------------------------------------------

function CommandExists { param([string]$c) $null -ne (Get-Command $c -ErrorAction SilentlyContinue) }
function IsWingetInstalled {
    param([string]$n)
    winget list 2>$null | Select-String $n
}

# -----------------------------------------------------
# 3. Install core via Chocolatey
# -----------------------------------------------------

choco install python git ffmpeg -y
Write-Host "Installed Python, Git & FFmpeg via Chocolatey" -ForegroundColor Green

# -----------------------------------------------------
# 4. Fallback to WinGet for Python
# -----------------------------------------------------

if (-not (CommandExists "python")) {
    Write-Host "Installing Python 3.11 via WinGet..." -ForegroundColor Yellow
    winget install --id Python.Python.3.11 -e --silent
} else {
    Write-Host "Python present" -ForegroundColor Green
}

# -----------------------------------------------------
# 5. Ensure pip
# -----------------------------------------------------

if (-not (CommandExists "pip")) {
    Write-Host "Installing pip..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri "https://bootstrap.pypa.io/get-pip.py" -OutFile get-pip.py
    python get-pip.py
    Remove-Item get-pip.py
    Write-Host "pip installed" -ForegroundColor Green
} else {
    Write-Host "pip already present" -ForegroundColor Green
}

# -----------------------------------------------------
# 6. Upgrade pip & install Python packages
# -----------------------------------------------------

Write-Host "Upgrading pip..." -ForegroundColor Cyan
python -m pip install --upgrade pip

Write-Host "Installing Whisper (from GitHub)..." -ForegroundColor Cyan
python -m pip install git+https://github.com/openai/whisper.git

Write-Host "Installing pinned packages numba..." -ForegroundColor Cyan
python -m pip install numba==0.60.0

Write-Host "Installing pinned packages numpy..." -ForegroundColor Cyan
python -m pip install numpy==1.26.4

Write-Host "Installing remaining Python packages..." -ForegroundColor Cyan
python -m pip install `
    torch torchvision torchaudio tk `
    nltk spacy transformers SpeechRecognition moviepy `
    pydub opencv-python ffmpeg-python requests whisper `
        
Write-Host "Installing pinned packages numpy..." -ForegroundColor Cyan
python -m pip install numpy==1.26.4

Write-Host "All Python packages installed" -ForegroundColor Green

# -----------------------------------------------------
# 7. Check for unmet dependencies
# -----------------------------------------------------

pip check | Write-Host
Write-Host "Dependency check complete" -ForegroundColor Green

# -----------------------------------------------------
# 8. Ensure PyTorch
# -----------------------------------------------------

try {
    $v = python -c "import torch; print(torch.__version__)"
    Write-Host "PyTorch v$v present" -ForegroundColor Green
} catch {
    Write-Host "Installing CPU-only PyTorch..." -ForegroundColor Yellow
    python -m pip install torch torchvision torchaudio
    Write-Host "PyTorch installed" -ForegroundColor Green
}

# -----------------------------------------------------
# 9. Update PATH for Python & Git
# -----------------------------------------------------

# Build your list of directories as simple strings
$dirs = @(
    "$env:LOCALAPPDATA\Programs\Python\Python311",
    "$env:LOCALAPPDATA\Programs\Python\Python311\Scripts",
    "C:\Program Files\Git\cmd"
)

# Update both Machine and User PATHs
foreach ($scope in "Machine","User") {
    $p    = [Environment]::GetEnvironmentVariable("Path",[EnvironmentVariableTarget]::$scope)
    $orig = $p

    foreach ($d in $dirs) {
        if ($p -notlike "*$d*") {
            $p += ";" + $d
        }
    }

    if ($p -ne $orig) {
        [Environment]::SetEnvironmentVariable("Path",$p,[EnvironmentVariableTarget]::$scope)
        Write-Host "Updated $scope PATH" -ForegroundColor Green
    } else {
        Write-Host "$scope PATH already up-to-date" -ForegroundColor Yellow
    }
}

Write-Host "Setup complete!" -ForegroundColor Magenta