r"""Свои звуки (ElevenLabs и т.п.) → snd/*.ogg: обрезать тишину, моно 44.1 кГц, выровнять громкость, плавные края.

    python tools/audio/import_sfx.py              — взять всё из snd_src/ и заменить одноимённые звуки игры
    python tools/audio/import_sfx.py --dry        — только показать, что будет сделано
    python tools/audio/import_sfx.py --peak=-3 --rms=-21   — другой уровень (дБ полной шкалы)

Имя исходника = имя звука в игре: door_wood.mp3 или варианты door_wood_1.mp3, door_wood_2.mp3 … (игра берёт случайный).
Все старые файлы этого звука (door_wood.ogg и door_wood_N.ogg) заменяются новым набором. Заменённые имена пишутся
в tools/audio/custom_sfx.txt — make_audio.py их больше не перезаписывает синтезом.
После замены — пересобрать игру: python tools/build.py (импорт Godot там же).
"""
import os
import re
import subprocess
import sys
import tempfile
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "snd_src")
OUT = os.path.join(ROOT, "snd")
CUSTOM = os.path.join(ROOT, "tools", "audio", "custom_sfx.txt")
SR = 44100
EXT = (".mp3", ".wav", ".ogg", ".flac", ".m4a")
MAX_SEC = 7.0


def arg(name, default):
    for a in sys.argv[1:]:
        if a.startswith("--" + name + "="):
            return float(a.split("=", 1)[1])
    return default


PEAK_DB = arg("peak", -3.0)     # пик как у синтезированных дверей (−2…−3 дБ)
RMS_DB = arg("rms", -21.0)      # средний уровень не выше: старые двери −16…−23 дБ, скрип должен быть тихим
DRY = "--dry" in sys.argv


def db(x):
    return 20.0 * np.log10(max(float(x), 1e-9))


def decode(path):
    # моно для 3D-звука. ElevenLabs отдаёт и «широкое» стерео с почти несвязанными каналами: сумма L+R там гасит
    # 3–4 дБ и сам тембр — тогда берём один канал (громче), а не сумму
    r = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-ar", str(SR), "-f", "f32le", "-"],
                       capture_output=True, check=True)
    probe = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "a:0", "-show_entries", "stream=channels",
                            "-of", "csv=p=0", path], capture_output=True, text=True, check=True)
    ch = max(1, int(probe.stdout.strip() or 1))
    x = np.frombuffer(r.stdout, dtype=np.float32).astype(np.float64)
    if ch == 1:
        return x
    s = x[: len(x) // ch * ch].reshape(-1, ch)
    rms = np.sqrt((s ** 2).mean(axis=0)) + 1e-12
    mono = s.mean(axis=1)
    loss = db(np.sqrt((mono ** 2).mean()) / rms.mean())
    if loss < -1.5:
        print(f"    стерео без общей середины (сумма {loss:.1f} дБ) — берём канал {int(np.argmax(rms)) + 1}")
        return s[:, int(np.argmax(rms))].copy()
    return mono


def envelope(x, win):
    # огибающая: максимум |x| в окне (для поиска начала и конца звука)
    n = len(x) // win
    if n == 0:
        return np.array([np.max(np.abs(x))]) if len(x) else np.zeros(1)
    return np.abs(x[: n * win]).reshape(n, win).max(axis=1)


def trim(x):
    win = int(0.01 * SR)
    e = envelope(x, win)
    peak = e.max()
    if peak <= 0:
        return x
    on = np.nonzero(e > peak * 10 ** (-42 / 20))[0]
    off = np.nonzero(e > peak * 10 ** (-52 / 20))[0]
    a = max(0, on[0] * win - int(0.015 * SR))
    b = min(len(x), (off[-1] + 1) * win + int(0.12 * SR))
    return x[a:b]


def fades(x):
    fi = min(len(x) // 4, int(0.006 * SR))
    fo = min(len(x) // 3, int(0.09 * SR))
    if fi > 0:
        x[:fi] *= np.linspace(0.0, 1.0, fi)
    if fo > 0:
        x[-fo:] *= np.linspace(1.0, 0.0, fo) ** 2
    return x


def level(x):
    # громкость по активной части: RMS окон 50 мс выше −40 дБ от пика (паузы внутри скрипа не тянут уровень вниз)
    win = int(0.05 * SR)
    n = max(1, len(x) // win)
    frames = x[: n * win].reshape(n, win) if len(x) >= win else x.reshape(1, -1)
    rms = np.sqrt((frames ** 2).mean(axis=1))
    act = rms[rms > rms.max() * 0.01]
    act_rms = float(np.sqrt((act ** 2).mean())) if len(act) else float(rms.max())
    g_peak = 10 ** (PEAK_DB / 20) / max(np.abs(x).max(), 1e-9)
    g_rms = 10 ** (RMS_DB / 20) / max(act_rms, 1e-9)
    g = min(g_peak, g_rms)
    return x * g, db(np.abs(x).max() * g), db(act_rms * g)


def encode(x, dst):
    tmp = os.path.join(tempfile.gettempdir(), "import_sfx_" + os.path.basename(dst) + ".wav")
    with wave.open(tmp, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "5", dst], check=True)
    os.remove(tmp)


def key_of(stem):
    # door_wood_2 → door_wood (как Snd._scan: хвост-число — номер варианта)
    m = re.match(r"^(.*)_(\d+)$", stem)
    return m.group(1) if m else stem


def main():
    try:
        sys.stdout.reconfigure(errors="replace")
    except Exception:
        pass
    if not os.path.isdir(SRC):
        os.makedirs(SRC)
    gdignore = os.path.join(SRC, ".gdignore")
    if not os.path.exists(gdignore):
        open(gdignore, "w").close()     # Godot не импортирует исходники (иначе mp3 попали бы в exe)
    files = sorted(f for f in os.listdir(SRC) if f.lower().endswith(EXT))
    if not files:
        print("Пусто: положите звуки в", SRC, "(имя файла = имя звука, например door_wood_1.mp3)")
        return
    groups = {}
    for f in files:
        stem = os.path.splitext(f)[0].strip().lower().replace(" ", "_").replace("-", "_")
        groups.setdefault(key_of(stem), []).append((stem, f))
    known = {key_of(os.path.splitext(f)[0]) for f in os.listdir(OUT) if f.endswith(".ogg")}
    done = []
    for key, items in sorted(groups.items()):
        if key not in known:
            print(f"! {key}: в игре нет такого звука — проверьте имя (будет добавлен как новый)")
        new = {stem + ".ogg" for stem, _ in items}
        old = [f for f in os.listdir(OUT) if re.fullmatch(re.escape(key) + r"(_\d+)?\.ogg", f)]
        for stem, f in items:
            x = decode(os.path.join(SRC, f))
            sec0 = len(x) / SR
            x = trim(x)
            if len(x) > MAX_SEC * SR:
                x = x[: int(MAX_SEC * SR)]
            x = fades(x)
            x, pk, rm = level(x)
            print(f"  {f:34s} -> {stem}.ogg  {sec0:4.1f} с -> {len(x) / SR:4.1f} с, пик {pk:5.1f} дБ, уровень {rm:5.1f} дБ")
            if not DRY:
                encode(x, os.path.join(OUT, stem + ".ogg"))
        for f in old:
            if f not in new:
                print(f"  удалить старый {f}")
                if not DRY:
                    for p in (os.path.join(OUT, f), os.path.join(OUT, f + ".import")):
                        if os.path.exists(p):
                            os.remove(p)
        done.append(key)
    if DRY:
        return
    names = set()
    if os.path.exists(CUSTOM):
        names = {l.strip() for l in open(CUSTOM, encoding="utf-8") if l.strip() and not l.startswith("#")}
    names |= set(done)
    with open(CUSTOM, "w", encoding="utf-8") as fh:
        fh.write("# звуки из snd_src/ (tools/audio/import_sfx.py) — make_audio.py их не перезаписывает\n")
        fh.write("\n".join(sorted(names)) + "\n")
    print("Готово:", ", ".join(done), "\nДальше: python tools/build.py")


if __name__ == "__main__":
    main()
