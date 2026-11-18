"""Правит .import файлы: текстуры мира — VRAM-сжатие и мип-карты, нормали — как карты нормалей,
UI-картинки — без сжатия; записки и прочие картинки с текстом из tex/gen — сжатие высокого качества (BC7).
Звуки snd/loop_* — зациклены. После правки нужен повторный импорт.

    python tools/fix_imports.py
"""
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def set_param(text, key, value):
    pat = re.compile(r"^" + re.escape(key) + r"=.*$", re.M)
    if pat.search(text):
        return pat.sub(f"{key}={value}", text)
    return text.replace("[params]\n", f"[params]\n\n{key}={value}\n", 1)


def main():
    changed = 0
    for base, _dirs, files in os.walk(ROOT):
        rel = os.path.relpath(base, ROOT).replace("\\", "/")
        if rel.startswith(".godot") or rel.startswith("tools") or rel.startswith("release") or rel.startswith("build"):
            continue
        for f in files:
            if not f.endswith(".import"):
                continue
            path = os.path.join(base, f)
            text = open(path, encoding="utf-8").read()
            orig = text
            src = f[:-7].lower()
            if src.endswith((".jpg", ".png", ".tga")) and 'importer="texture"' in text:
                ui = rel.startswith("tex/ui") and not src.startswith(("hair", "steam", "flash"))
                world = not ui and (rel.startswith("tex") or rel.startswith("mdl"))
                if world:
                    text = set_param(text, "compress/mode", "2")
                    text = set_param(text, "mipmaps/generate", "true")
                    text = set_param(text, "detect_3d/compress_to", "0")
                    if "normal" in src or "nor_gl" in src:
                        text = set_param(text, "compress/normal_map", "1")
                    if "rough" in src:
                        text = set_param(text, "compress/normal_map", "2")
                    # записки, правила, фото, рисунок, план: в 3D они тоже есть (нужны VRAM-сжатие и мип-карты), но
                    # на экране записки и в телефоне видны почти 1:1 — DXT1 давал блоки 4×4 и цветной шум у букв.
                    # high_quality — BC7: то же сжатие и мипы, без этих артефактов (вдвое больше памяти, файлов мало)
                    if rel == "tex/gen" and src.startswith(("note_", "rules", "child_drawing", "old_photo", "evac_plan")):
                        text = set_param(text, "compress/high_quality", "true")
            if src.endswith(".ogg") and os.path.basename(src).startswith("loop_"):
                text = set_param(text, "loop", "true")
            if text != orig:
                open(path, "w", encoding="utf-8").write(text)
                changed += 1
    print("исправлено файлов:", changed)


if __name__ == "__main__":
    main()
