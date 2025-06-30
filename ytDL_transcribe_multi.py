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