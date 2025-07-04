# Video-or-Audio-Transcribing

## Utilizing some PowerShell and a Python script, these are the Windows steps to transcribe a YouTube video or any video or audio file to a text file. The video and audio files are also saved.

## Go check out yt-dlp and their amazing work! https://github.com/yt-dlp


### Getting Started.
#### Open PowerShell as Administrator

Run
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

#### Install or Update Windows Terminal (Optional)
Run Update-WindowsTerminal.ps1

```powershell
& '.\Update-WindowsTerminal.ps1'
```

#### Full Script

```powershell
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
```

#### Click on Windows Terminal icon while pressing Ctrl and Shift together

Run
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

Run installrequirements.ps1

```powershell
& '.\installrequirements.ps1'
```

#### Full Script

```powershell
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
# 6.a. Ensure exact numpy==1.26.4
# -----------------------------------------------------
Write-Host "Checking for numpy installation..." -ForegroundColor Cyan

# Try to read the installed version
try {
    $installed = & python -c "import numpy; print(numpy.__version__)" 2>$null
} catch {
    $installed = $null
}

if ($installed) {
    if ($installed -ne '1.26.4') {
        Write-Host "Found numpy v$installed; uninstalling..." -ForegroundColor Yellow
        python -m pip uninstall -y numpy
        Write-Host "Installing numpy v1.26.4..." -ForegroundColor Cyan
        python -m pip install numpy==1.26.4
    } else {
        Write-Host "numpy v1.26.4 already installed; skipping." -ForegroundColor Green
    }
} else {
    Write-Host "numpy not found; installing v1.26.4..." -ForegroundColor Cyan
    python -m pip install numpy==1.26.4
}

# -----------------------------------------------------
# 6.b. Install remaining Python packages
# -----------------------------------------------------
Write-Host "Installing remaining Python packages..." -ForegroundColor Cyan
python -m pip install `
    git+https://github.com/openai/whisper.git `
    numba==0.60.0 `
    torch torchvision torchaudio tk `
    nltk spacy transformers SpeechRecognition moviepy `
    pydub opencv-python ffmpeg-python requests pyinstaller

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

```

#### Download yt-dlp to folder of choosing (C:\Users\name\Documents\yt-dlp) (this example uses PowerShell, you can use your browser)

https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe

```powershell
Start-BitsTransfer `
  -Source "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe" `
  -Destination ".\yt-dlp.exe"
```

#### Download ffmpeg to same folder (this example uses PowerShell, you can use your browser)

https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip

```powershell
Start-BitsTransfer `
  -Source "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip" `
  -Destination ".\ffmpeg-release-essentials.zip"
```

#### Extract zip file to same folder (ffmpeg.exe etc... should be taken out of the bin folder and pasted in the yt-dlp folder)

![alt text](https://raw.githubusercontent.com/falconinit/Video-or-Audio-Transcribing/refs/heads/main/yt-dlp.png)

#### Optionally, you can run this more comprehensive PowerShell script to do the downloading and extracting for you.

```powershell
& '.\download_yt-dlp_ffmpeg_installreqs.ps1'
```
#### Run python script in PowerShell in same folder as above and just follow the prompts.

```powershell
python '.\ytDL_transcribe_multi.py'
```
#### Full Python Script

```python
import os
import glob
import subprocess
import tkinter as tk
from tkinter import filedialog, messagebox
from moviepy.editor import VideoFileClip
from pydub import AudioSegment
import whisper
import multiprocessing

model = None

def show_splash_screen():
    splash = tk.Tk()
    splash.title("Batch Transcribe - Welcome")
    splash.geometry("400x300")
    splash.configure(bg="white")

    tk.Label(splash, text="Batch Transcribe", font=("Arial", 18, "bold"), bg="white").pack(pady=10)
    tk.Label(
        splash,
        text=(
            "This program lets you either:\n"
            "• Enter a video ID to download-and-transcribe\n"
            "• Or select existing audio/video files to transcribe\n\n"
            "Click OK to continue."
        ),
        font=("Arial", 10),
        bg="white",
        justify="center",
    ).pack(pady=20)
    tk.Button(splash, text="OK", command=splash.destroy, bg="#4CAF50", fg="white").pack(pady=10)
    splash.mainloop()

def prompt_for_video_id():
    dlg = tk.Tk()
    dlg.title("Download Video")
    dlg.geometry("350x150")

    tk.Label(dlg, text="Enter YouTube Video ID (i.e. 4PHAHYCfnPE) to \n"
                    "download and transcribe a YouTube video \n"
                    "(has not been tested while using a VPN) \n"
                    "or leave blank to select files:").pack(padx=10, pady=10)
    entry = tk.Entry(dlg, width=30)
    entry.pack(padx=10)

    def on_ok():
        dlg.video_id = entry.get().strip()
        dlg.destroy()

    tk.Button(dlg, text="OK", command=on_ok, bg="#4CAF50", fg="white").pack(pady=10)
    dlg.mainloop()

    return getattr(dlg, 'video_id', '')

def download_video(video_id):
    cmd = [
        ".\\yt-dlp.exe",
        "-f", "bv+ba/b",
        "-S", "res,ext:mp4:m4a",
        "--recode", "mp4",
        "-o", "%(title)s-%(id)s.%(ext)s",
        video_id
    ]
    try:
        subprocess.run(cmd, check=True)
    except subprocess.CalledProcessError as e:
        messagebox.showerror("Download Failed", f"yt-dlp failed:\n{e}")
        return []

    # Find the downloaded MP4 by matching "*-<video_id>.mp4"
    pattern = f"*-{video_id}.mp4"
    matches = glob.glob(pattern)
    if not matches:
        messagebox.showerror("File Not Found", f"No file matching {pattern} was found.")
    return matches

def get_file_paths():
    root = tk.Tk()
    root.withdraw()
    paths = filedialog.askopenfilenames(
        title="Select audio or video files",
        filetypes=(
            ("Audio/Video Files", "*.mp4;*.mp3;*.wav;*.m4a;*.flac;*.mov;*.avi;*.mkv"),
            ("All files", "*.*"),
        ),
    )
    return list(paths)

def convert_to_wav(file_path, output_wav_path):
    if os.path.exists(output_wav_path):
        print(f"[INFO] WAV exists, skipping: {output_wav_path}")
        return

    ext = os.path.splitext(file_path)[1].lower()
    if ext in [".mp4", ".mov", ".avi", ".mkv"]:
        video = VideoFileClip(file_path)
        video.audio.write_audiofile(output_wav_path, codec="pcm_s16le")
    else:
        audio = AudioSegment.from_file(file_path)
        audio.export(output_wav_path, format="wav")

def worker_init():
    global model
    print("[Worker Init] Loading Whisper model...")
    model = whisper.load_model("base")
    print("[Worker Init] Model ready.")

def process_file(file_path):
    global model
    try:
        wav_path = file_path.rsplit(".", 1)[0] + ".wav"
        convert_to_wav(file_path, wav_path)

        print(f"[INFO] Transcribing {file_path}")
        result = model.transcribe(wav_path)
        txt_path = file_path.rsplit(".", 1)[0] + ".txt"
        with open(txt_path, "w", encoding="utf-8") as f:
            f.write(result["text"])
        print(f"[SUCCESS] Transcribed and saved: {txt_path}")
    except Exception as e:
        print(f"[ERROR] {file_path}: {e}")

    return file_path

def main():
    show_splash_screen()

    video_id = prompt_for_video_id()
    if video_id:
        file_paths = download_video(video_id)
        if not file_paths:
            return
    else:
        file_paths = get_file_paths()
        if not file_paths:
            messagebox.showwarning("No Files", "No files selected. Exiting.")
            return

    print("[INFO] Files to process:", file_paths)

    cpu_cores = multiprocessing.cpu_count()
    with multiprocessing.Pool(processes=cpu_cores, initializer=worker_init) as pool:
        results = pool.map(process_file, file_paths)

    messagebox.showinfo("Batch Transcribe", "All files have been transcribed successfully!")

    # Open the first transcription in the default editor
    if results:
        first_txt = results[0].rsplit(".", 1)[0] + ".txt"
        if os.path.exists(first_txt):
            os.startfile(first_txt)
        else:
            print(f"[WARN] Could not find {first_txt} to open.")

    print("[INFO] Done:", results)

if __name__ == "__main__":
    main()
```
