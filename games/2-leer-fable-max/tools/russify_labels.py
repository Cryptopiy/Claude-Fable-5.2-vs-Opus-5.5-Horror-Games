"""Советская станция 1987 года: английские надписи на моделях Poly Haven заменяются русскими.

    python tools/russify_labels.py      затем  tools/dev.sh import

Оригиналы текстур копируются в tools/label_src/ (там .gdignore — Godot их не импортирует); скрипт всегда
рисует от оригинала, поэтому его можно запускать повторно. Если заново скачать модели (fetch_assets.py), запустить снова.
Что меняется:
  medbox  «FIRST AID»                      → «АПТЕЧКА»
  gastank логотип «S» и «Warning…»          → «ПРОПАН», «ОГНЕОПАСНО»
  feeder  наклейки «DANGER / KEEP OUT», «WARNING HIGH VOLTAGE» → таблички «ОПАСНО», «ВЫСОКОЕ НАПРЯЖЕНИЕ»
"""
import os, shutil
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "tools", "label_src")
FONTS = r"C:\Windows\Fonts"


def font(size, name="bahnschrift.ttf"):
    for n in (name, "arialnb.ttf", "arialbd.ttf", "arial.ttf"):
        p = os.path.join(FONTS, n)
        if os.path.exists(p):
            f = ImageFont.truetype(p, size)
            try:
                f.set_variation_by_name("Bold Condensed")
            except Exception:
                pass
            return f
    return ImageFont.load_default()


def original(model, name="d.jpg"):
    os.makedirs(SRC, exist_ok=True)
    open(os.path.join(SRC, ".gdignore"), "a").close()
    keep = os.path.join(SRC, model + "_" + name)
    cur = os.path.join(ROOT, "mdl", model, name)
    if not os.path.exists(keep):
        shutil.copyfile(cur, keep)
    return Image.open(keep).convert("RGB"), cur


def patch(im, box, src_off):
    """Закрасить прямоугольник куском той же текстуры со сдвигом src_off (с мягким краем)."""
    x0, y0, x1, y1 = box
    sx, sy = src_off
    piece = im.crop((x0 + sx, y0 + sy, x1 + sx, y1 + sy))
    mask = Image.new("L", (x1 - x0, y1 - y0), 0)
    ImageDraw.Draw(mask).rectangle((3, 3, x1 - x0 - 4, y1 - y0 - 4), fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(2.5))
    im.paste(piece, (x0, y0), mask)


def text_img(text, size, color, rot=0, pad=4, stretch=1.0):
    f = font(size)
    l, t, r, b = f.getbbox(text)
    w, h = r - l + pad * 2, b - t + pad * 2
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(im).text((pad - l, pad - t), text, font=f, fill=color)
    if stretch != 1.0:
        im = im.resize((max(1, int(w * stretch)), h), Image.LANCZOS)
    if rot:
        im = im.rotate(rot, expand=True, resample=Image.BICUBIC)
    return im


def stamp(im, timg, center, wear=0.25, seed=1):
    """Нанести надпись по трафарету: краска местами стёрта (как и на остальной текстуре)."""
    rng = np.random.default_rng(seed)
    a = np.asarray(timg).astype(np.float32)
    n = rng.random(a.shape[:2])
    n = np.asarray(Image.fromarray((n * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2))).astype(np.float32) / 255.0
    a[..., 3] *= np.clip((n - wear * 0.5) * 2.2, 0.0, 1.0)
    t = Image.fromarray(a.astype(np.uint8), "RGBA")
    im.paste(t, (int(center[0] - t.width / 2), int(center[1] - t.height / 2)), t)


def plate(w, h, lines, bg, fg, border=None, tri=False):
    """Табличка: фон, рамка, строки; tri — жёлтый треугольник с молнией сверху."""
    im = Image.new("RGBA", (w, h), bg)
    d = ImageDraw.Draw(im)
    if border:
        d.rectangle((1, 1, w - 2, h - 2), outline=border, width=2)
    y = 4
    if tri:
        s = int(h * 0.42)
        cx = w // 2
        d.polygon([(cx, y), (cx - s // 2 - 4, y + s), (cx + s // 2 + 4, y + s)], fill=(222, 178, 30, 255), outline=(20, 20, 20, 255))
        d.line([(cx + 2, y + s * 0.3), (cx - 4, y + s * 0.62), (cx + 4, y + s * 0.6), (cx - 2, y + s * 0.92)], fill=(20, 20, 20, 255), width=2)
        y += s + 3
    for txt, sz, col in lines:
        f = font(sz)
        l, t, r, b = f.getbbox(txt)
        d.text(((w - (r - l)) / 2 - l, y - t), txt, font=f, fill=col or fg)
        y += (b - t) + 3
    return im


def medbox():
    im, out = original("medbox")
    patch(im, (205, 668, 256, 872), (52, 0))
    stamp(im, text_img("АПТЕЧКА", 44, (222, 226, 220, 255), rot=90, stretch=0.92), (230, 770), 0.3, 3)
    im.save(out, quality=95)


def gastank():
    im, out = original("gastank")
    patch(im, (286, 512, 398, 592), (0, -150))
    patch(im, (418, 528, 466, 600), (0, -150))
    stamp(im, text_img("ПРОПАН", 64, (232, 230, 222, 255), rot=90, stretch=0.9), (345, 552), 0.35, 5)
    stamp(im, text_img("ОГНЕОПАСНО", 20, (226, 224, 216, 255), rot=90), (442, 563), 0.3, 6)
    im.save(out, quality=95)


def feeder():
    im, out = original("feeder")
    # нижняя наклейка DANGER / KEEP OUT (в текстуре вверх ногами — так она стоит на модели правильно)
    p = plate(70, 74, [("ОПАСНО", 19, (200, 26, 22, 255)), ("НЕ ВХОДИТЬ", 11, None), ("без допуска", 9, None)],
              (232, 230, 222, 255), (22, 22, 22, 255), (40, 40, 40, 255), tri=True)
    stamp(im, p.rotate(180), (421, 942), 0.12, 7)
    # жёлтые треугольники «WARNING HIGH VOLTAGE» (их два; рядом — жёлто-чёрные полосы, их не трогаем):
    # центр каждого — по жёлтым точкам в окне 80×80 вокруг известного места
    a = np.asarray(im).astype(np.int32)
    yellow = (a[..., 0] > 170) & (a[..., 1] > 130) & (a[..., 2] < 90)
    seen = []
    for gx, gy in ((303, 600), (740, 600)):
        m = yellow[gy - 40:gy + 40, gx - 40:gx + 40]
        yy, xx = np.nonzero(m)
        if len(xx) < 30:
            continue
        cx, cy = int(xx.mean()) + gx - 40, int(yy.mean()) + gy - 40
        seen.append((cx, cy))
        tp = plate(52, 58, [("ВЫСОКОЕ", 10, None), ("НАПРЯЖЕНИЕ", 8, None)], (222, 178, 30, 255), (20, 20, 20, 255),
                   (20, 20, 20, 255), tri=True)
        stamp(im, tp.rotate(180), (cx, cy - 2), 0.1, 8 + cx)
    im.save(out, quality=95)
    return seen


if __name__ == "__main__":
    medbox()
    gastank()
    print("feeder triangles:", feeder())
    print("готово: tools/dev.sh import")
