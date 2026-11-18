"""Свои текстуры: луч фонаря, пар, волосы, кожа Хозяйки, таблички, записки, план, мозаика и т. п.

    python tools/make_tex.py
Записки берутся из src/story/notes.json (тот же текст показывает игра).
"""
import json
import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "tex", "ui")
GEN = os.path.join(ROOT, "tex", "gen")
F = os.path.join(ROOT, "fonts")
os.makedirs(OUT, exist_ok=True)
os.makedirs(GEN, exist_ok=True)
random.seed(7)
np.random.seed(7)


def font(name, size):
    return ImageFont.truetype(os.path.join(F, name), size)


def noise(w, h, scale=32, octaves=4):
    out = np.zeros((h, w), np.float32)
    amp = 1.0
    for o in range(octaves):
        s = max(1, int(scale / (2 ** o)))
        small = np.random.rand(h // s + 2, w // s + 2).astype(np.float32)
        im = Image.fromarray((small * 255).astype(np.uint8)).resize((w + 2 * s, h + 2 * s), Image.BICUBIC)
        out += np.asarray(im, np.float32)[s:s + h, s:s + w] / 255.0 * amp
        amp *= 0.5
    out -= out.min()
    out /= max(out.max(), 1e-6)
    return out


# ------------------------------------------------------------------ свет и пар

def flash_cookie():
    """Луч фонаря: яркое ядро, мягкое тело и широкий тусклый ореол, который сходит на нет к краю конуса
    (без жёсткого края-овала на стене). Лёгкое кольцо от отражателя и неровности стекла."""
    n = 256
    y, x = np.mgrid[0:n, 0:n].astype(np.float32)
    r = np.hypot(x - n / 2 + 0.5, y - n / 2 + 0.5) / (n / 2)
    hot = np.exp(-(r / 0.2) ** 2) * 0.55
    body = np.exp(-(r / 0.42) ** 2.2) * 0.5
    ring = np.exp(-((r - 0.46) / 0.06) ** 2) * 0.07
    halo = np.clip(1 - r, 0, 1) ** 1.6 * 0.16
    v = np.clip(hot + body + ring + halo, 0, 1)
    v *= 0.93 + noise(n, n, 24, 3) * 0.07
    v *= np.clip((1.0 - r) / 0.12, 0, 1)
    Image.fromarray((v * 255).astype(np.uint8)).convert("RGB").save(os.path.join(OUT, "flash_cookie.png"))


def steam_puff():
    n = 128
    y, x = np.mgrid[0:n, 0:n].astype(np.float32)
    r = np.hypot(x - n / 2, y - n / 2) / (n / 2)
    a = np.clip(1 - r, 0, 1) ** 1.6 * (0.55 + 0.45 * noise(n, n, 20, 4))
    img = np.zeros((n, n, 4), np.uint8)
    img[..., :3] = 235
    img[..., 3] = (np.clip(a, 0, 1) * 255).astype(np.uint8)
    Image.fromarray(img, "RGBA").save(os.path.join(OUT, "steam_puff.png"))


def hair_strands():
    """Текстура прядей: много тонких волос с альфой, мокрый блеск по центру."""
    w, h = 256, 1024
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for i in range(420):
        x0 = random.uniform(0, w)
        drift = random.uniform(-18, 18)
        thick = random.choice([1, 1, 1, 2, 2, 3])
        c = random.randint(4, 22)
        alpha = random.randint(150, 255)
        end = random.uniform(0.75, 1.0) * h
        pts = []
        for k in range(24):
            t = k / 23
            pts.append((x0 + drift * t + math.sin(t * 6 + i) * 3, t * end))
        d.line(pts, fill=(c, c, c + 2, alpha), width=thick)
    arr = np.asarray(img).astype(np.float32)
    # блики (мокрые)
    for i in range(70):
        x0 = int(random.uniform(0, w))
        y0 = int(random.uniform(0, h * 0.9))
        ln = int(random.uniform(20, 120))
        arr[y0:y0 + ln, x0:x0 + 1, :3] = np.maximum(arr[y0:y0 + ln, x0:x0 + 1, :3], 70)
    Image.fromarray(arr.clip(0, 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, "hair.png"))


def skin():
    """Кожа Хозяйки из текстур Rocketbox: серая, мокрая, с венами; лицо — бельма и тёмные глазницы."""
    src = os.path.join(ROOT, "mdl", "rb", "hozyayka")
    body = Image.open(os.path.join(src, "body_color.png")).convert("RGB")
    head = Image.open(os.path.join(src, "head_color.png")).convert("RGB")

    def grey(im, tint=(0.62, 0.64, 0.6), target=0.34, norm=None):
        a = np.asarray(im).astype(np.float32) / 255.0
        lum = a @ np.array([0.3, 0.55, 0.15], np.float32)
        lum = lum ** 1.15
        n = noise(im.width, im.height, 64, 5)
        veins = noise(im.width, im.height, 8, 3)
        veins = np.clip((np.abs(veins - 0.5) < 0.035).astype(np.float32) * 0.5, 0, 1)
        out = np.stack([lum * tint[0], lum * tint[1], lum * tint[2]], -1)
        out *= (0.75 + n[..., None] * 0.35)
        # яркость к цели, а не цепочкой множителей: было ~0.1 sRGB (≈1 % альбедо) — чёрный силуэт даже в луче.
        # Цель ~0.34 sRGB (≈0.09 линейного): мокрая серая кожа видна в фонаре, без света остаётся тёмной.
        # Меряется только по коже (norm — без волос и одежды); вены, пятна, глазницы, рот и волосы — темнота поверх
        lm = out.mean(-1)
        sel = lm > 0.02 if norm is None else (lm > 0.02) & norm
        out *= target / max(float(np.median(lm[sel])), 1e-3)
        out[..., 0] -= veins * 0.10
        out[..., 1] -= veins * 0.06
        out[..., 2] += veins * 0.02
        # пятна грязи / синяков
        blot = noise(im.width, im.height, 128, 3)
        out *= (1 - np.clip(blot - 0.62, 0, 1)[..., None] * 1.6)
        return np.clip(out, 0, 1)

    # одежда (свитер, блузка, бусы, юбка) → застиранная серая сорочка: размыть детали, наложить грязь
    W0 = body.width
    sx = W0 / 512.0
    mm = Image.new("L", body.size, 0)
    dm = ImageDraw.Draw(mm)
    dm.rectangle([150 * sx, 0, 362 * sx, 400 * sx], fill=255)        # торс
    dm.rectangle([30 * sx, 150 * sx, 482 * sx, 235 * sx], fill=255)  # рукава
    dm.rectangle([20 * sx, 270 * sx, 492 * sx, 390 * sx], fill=255)  # юбка
    mask = np.asarray(mm.filter(ImageFilter.GaussianBlur(6 * sx))).astype(np.float32) / 255.0
    b = grey(body, norm=mask < 0.5)
    cloth = np.asarray(Image.fromarray((b * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(9 * sx))).astype(np.float32) / 255.0
    dirt = noise(body.width, body.height, 48, 5)
    # сорочка темнее кожи (≈0.24 sRGB при коже ≈0.29 после пятен): серые руки и лицо отделяются от неё.
    # При цели 0.28 сорочка выходила вровень с кожей (0.281 против 0.294) и руки на ней терялись
    cl = cloth.mean(-1, keepdims=True) * np.array([1.0, 0.97, 0.9]) * (0.7 + dirt[..., None] * 0.5)
    cm = cl.mean(-1)
    cl *= 0.24 / max(float(np.median(cm[(mask > 0.5) & (cm > 0.01)])), 1e-3)
    b = b * (1 - mask[..., None]) + np.clip(cl, 0, 1) * mask[..., None]
    Image.fromarray((b * 255).astype(np.uint8)).save(os.path.join(GEN, "hoz_body.png"))
    src_a = np.asarray(head).astype(np.float32)
    bright = src_a.mean(-1)
    sat = src_a.max(-1) - src_a.min(-1)
    hairmask = ((bright < 120) & (sat < 70)).astype(np.float32)
    hairmask = np.asarray(Image.fromarray((hairmask * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(4))).astype(np.float32) / 255.0
    hh = grey(head, (0.66, 0.66, 0.62), 0.36, norm=hairmask < 0.5)
    hh = hh * (1 - hairmask[..., None]) + np.array([0.035, 0.03, 0.03])[None, None, :] * hairmask[..., None]
    W = head.width
    img = Image.fromarray((hh * 255).astype(np.uint8))
    d = ImageDraw.Draw(img, "RGBA")
    s = W / 512.0
    # глазницы (по развёртке Rocketbox: глаза около (221,145) и (291,145) при 512)
    for cx in (221, 291):
        for rr, a in ((40, 70), (30, 130), (20, 200)):
            d.ellipse([(cx - rr) * s, (145 - rr * 0.7) * s, (cx + rr) * s, (145 + rr * 0.7) * s], fill=(10, 8, 8, a))
    # рот — тёмная щель, уголки вниз
    d.polygon([(232 * s, 207 * s), (256 * s, 212 * s), (280 * s, 207 * s), (276 * s, 216 * s), (256 * s, 221 * s), (236 * s, 216 * s)], fill=(20, 8, 8, 220))
    # трупные пятна, трещинки на губах, тёмные потёки от глаз
    for _ in range(26):
        cx, cy = random.uniform(150, 360), random.uniform(60, 260)
        r = random.uniform(6, 22)
        d.ellipse([(cx - r) * s, (cy - r * 0.7) * s, (cx + r) * s, (cy + r * 0.7) * s], fill=(40, 45, 42, random.randint(25, 60)))
    for cx in (221, 291):
        for k in range(3):
            x0 = cx + random.uniform(-8, 8)
            d.line([(x0 * s, 155 * s), ((x0 + random.uniform(-4, 4)) * s, random.uniform(185, 230) * s)], fill=(15, 12, 12, 120), width=int(3 * s))
    img = img.filter(ImageFilter.GaussianBlur(1.2 * s))
    # глазное яблоко (кусок развёртки внизу слева) — бельмо
    eye = Image.new("RGBA", img.size, (0, 0, 0, 0))
    de = ImageDraw.Draw(eye)
    de.ellipse([100 * s, 432 * s, 170 * s, 500 * s], fill=(205, 210, 200, 255))
    de.ellipse([122 * s, 452 * s, 148 * s, 478 * s], fill=(170, 178, 170, 255))
    img = Image.alpha_composite(img.convert("RGBA"), eye.filter(ImageFilter.GaussianBlur(3 * s))).convert("RGB")
    img.save(os.path.join(GEN, "hoz_head.png"))
    # мужчина под простынёй — просто белёсая ткань
    cloth = np.ones((256, 256, 3), np.float32) * 0.82
    cloth *= (0.85 + noise(256, 256, 32, 4)[..., None] * 0.2)
    stain = noise(256, 256, 64, 3)
    cloth[..., 1] -= np.clip(stain - 0.6, 0, 1) * 0.5
    cloth[..., 2] -= np.clip(stain - 0.6, 0, 1) * 0.7
    Image.fromarray((cloth.clip(0, 1) * 255).astype(np.uint8)).save(os.path.join(GEN, "sheet.png"))


# ------------------------------------------------------------------ бумага и надписи

def paper(w, h, tone=(226, 218, 196), age=0.5, seed=0):
    rnd = np.random.RandomState(seed)
    n = noise(w, h, 48, 5)
    base = np.array(tone, np.float32)[None, None, :] * (0.9 + n[..., None] * 0.12)
    # пятна сырости
    blot = noise(w, h, 160, 3)
    base *= (1 - np.clip(blot - (0.7 - age * 0.2), 0, 1)[..., None] * np.array([0.3, 0.45, 0.8]))
    # края темнее
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    edge = np.minimum(np.minimum(x, w - x), np.minimum(y, h - y)) / (min(w, h) * 0.12)
    base *= (0.75 + 0.25 * np.clip(edge, 0, 1))[..., None]
    return Image.fromarray(base.clip(0, 255).astype(np.uint8))


def wrap(text, fnt, width, draw):
    lines = []
    for para in text.split("\n"):
        words = para.split(" ")
        cur = ""
        for wd in words:
            t = (cur + " " + wd).strip()
            if draw.textlength(t, font=fnt) <= width:
                cur = t
            else:
                if cur:
                    lines.append(cur)
                cur = wd
        lines.append(cur)
    return lines


def text_block(img, text, fnt, x, y, width, fill, spacing=1.25, jitter=0.0):
    d = ImageDraw.Draw(img)
    lh = int(fnt.size * spacing)
    for ln in wrap(text, fnt, width, d):
        dx = random.uniform(-jitter, jitter)
        d.text((x + dx, y), ln, font=fnt, fill=fill)
        y += lh
    return y


def block_h(text, fnt, width, spacing):
    """Высота блока text_block без рисования."""
    d = ImageDraw.Draw(Image.new("L", (1, 1)))
    return len(wrap(text, fnt, width, d)) * int(fnt.size * spacing)


def fit_font(name, size, floor, fits):
    """Самый крупный кегль от size до floor, при котором fits(шрифт) — иначе floor (текст не режется)."""
    for s in range(size, floor - 1, -1):
        f = font(name, s)
        if fits(f):
            return f
    return font(name, floor)


def notes_textures():
    path = os.path.join(ROOT, "src", "story", "notes.json")
    if not os.path.exists(path):
        print("нет notes.json — записки пропущены")
        return
    notes = json.load(open(path, encoding="utf-8"))
    # длинные записи (журнал истопника, книга жалоб) уходили за нижний край листа 512×680 —
    # кегль подбирается так, чтобы весь текст лёг на лист с полем снизу
    for nid, n in notes.items():
        kind = n.get("look", "paper")
        W, H = (512, 680)
        if kind == "typed":
            img = paper(W, H, (232, 226, 210), 0.5, hash(nid) % 1000)
            ft = font("PTMono-Regular.ttf", 22)
            th = block_h(n["title"].upper(), ft, W - 80, 1.25)
            fb = fit_font("PTMono-Regular.ttf", 17, 13, lambda f: 40 + th + 16 + block_h(n["text"], f, W - 80, 1.3) <= H - 28)
            y = text_block(img, n["title"].upper(), ft, 40, 40, W - 80, (40, 35, 35))
            text_block(img, n["text"], fb, 40, y + 16, W - 80, (45, 40, 40), 1.3)
        elif kind == "news":
            img = paper(W, H, (214, 206, 182), 0.8, hash(nid) % 1000)
            d = ImageDraw.Draw(img)
            head = n.get("paper", "ЧЕРНОРЕЧЕНСКАЯ ПРАВДА")       # шапка с датой шире листа — кегль по ширине
            fh = fit_font("PTSerif-Regular.ttf", 26, 16, lambda f: d.textlength(head, font=f) <= W - 60)
            d.text((30, 26 + (26 - fh.size) * 0.6), head, font=fh, fill=(30, 28, 28))
            d.line((30, 64, W - 30, 64), fill=(40, 40, 40), width=2)
            ft = font("PTSans-Bold.ttf", 30)
            th = block_h(n["title"], ft, W - 60, 1.1)
            fb = fit_font("PTSerif-Regular.ttf", 18, 14, lambda f: 80 + th + 14 + block_h(n["text"], f, W - 60, 1.3) <= H - 28)
            y = text_block(img, n["title"], ft, 30, 80, W - 60, (25, 22, 22), 1.1)
            text_block(img, n["text"], fb, 30, y + 14, W - 60, (40, 36, 34), 1.3)
        elif kind == "board":
            continue
        else:
            img = paper(W, H, (222, 214, 190) if kind != "cardboard" else (170, 140, 100), 0.6, hash(nid) % 1000)
            x = 70 if kind == "notebook" else 34
            fname, base = ("Caveat.ttf", 30) if kind != "cardboard" else ("Neucha.ttf", 26)

            def total(f):
                return 28 + block_h(n["title"], f, W - 90, 1.05) + 6 + block_h(n["text"], f, W - 100, 1.0)
            fnt = fit_font(fname, base, 20, lambda f: total(f) <= H - 24)
            y_text = 28 + block_h(n["title"], fnt, W - 90, 1.05) + 6
            if kind == "notebook":
                # линовка с шагом строки текста — почерк ложится на линии и при меньшем кегле
                d = ImageDraw.Draw(img)
                step = int(fnt.size * 1.0)
                yy = y_text + int(fnt.size * 0.95)
                while yy - step > 40:
                    yy -= step
                while yy < H - 6:
                    d.line((20, yy, W - 20, yy), fill=(150, 160, 190), width=1)
                    yy += step
                d.line((60, 0, 60, H), fill=(200, 120, 120), width=2)
            y = text_block(img, n["title"], fnt, x, 28, W - 90, (30, 30, 60), 1.05, 1.0)
            text_block(img, n["text"], fnt, x, y + 6, W - 100, (25, 25, 55) if kind != "cardboard" else (20, 15, 10), 1.0, 1.5)
        img.save(os.path.join(GEN, "note_" + nid + ".png"))


def rules_board():
    path = os.path.join(ROOT, "src", "story", "notes.json")
    notes = json.load(open(path, encoding="utf-8"))
    n = notes["rules"]
    W, H = 768, 1024
    img = paper(W, H, (225, 222, 205), 0.6, 3)
    d = ImageDraw.Draw(img)
    d.rectangle((14, 14, W - 14, H - 14), outline=(120, 30, 30), width=6)
    y = 40
    for ln in ["ПРАВИЛА", "ПОЛЬЗОВАНИЯ ГОРОДСКОЙ БАНЕЙ № 3"]:
        f = font("PTSans-Bold.ttf", 46 if ln == "ПРАВИЛА" else 30)
        tw = d.textlength(ln, font=f)
        d.text(((W - tw) / 2, y), ln, font=f, fill=(140, 25, 25))
        y += 56 if ln == "ПРАВИЛА" else 50
    printed, hand = n["text"].split("\n\n", 1) if "\n\n" in n["text"] else (n["text"], "")
    printed = printed.replace("ПРАВИЛА ПОЛЬЗОВАНИЯ ГОРОДСКОЙ БАНЕЙ № 3\n", "")
    y = text_block(img, printed, font("PTSans-Regular.ttf", 25), 50, y + 10, W - 100, (30, 30, 30), 1.3)
    # карандашные приписки
    pen = Image.new("RGBA", img.size, (0, 0, 0, 0))
    text_block(pen, hand, font("Caveat.ttf", 36), 60, y + 20, W - 110, (55, 55, 70, 235), 1.0, 2.0)
    pen = pen.rotate(-1.2, resample=Image.BICUBIC)
    img = Image.alpha_composite(img.convert("RGBA"), pen).convert("RGB")
    img.save(os.path.join(GEN, "rules.png"))


def price_list():
    W, H = 512, 640
    img = Image.new("RGB", (W, H), (22, 30, 26))
    d = ImageDraw.Draw(img)
    d.text((40, 30), "ПРЕЙСКУРАНТ", font=font("PTSans-Bold.ttf", 44), fill=(225, 220, 200))
    rows = [("Мытьё, общее отделение", "20 р."), ("Мытьё с парильней", "35 р."), ("Детский билет", "10 р."),
            ("Простыня", "10 р."), ("Веник берёзовый", "50 р."), ("Веник дубовый", "70 р."), ("Мыло", "8 р."),
            ("Мочалка", "15 р."), ("Стрижка", "60 р.")]
    y = 120
    for a, b in rows:
        d.text((40, y), a, font=font("PTSansNarrow-Regular.ttf", 30), fill=(215, 210, 190))
        tw = d.textlength(b, font=font("PTSansNarrow-Bold.ttf", 30))
        d.text((W - 40 - tw, y), b, font=font("PTSansNarrow-Bold.ttf", 30), fill=(215, 210, 190))
        y += 48
    d.text((40, H - 70), "Цены с 01.03.2004", font=font("PTSansNarrow-Regular.ttf", 24), fill=(160, 160, 150))
    n = noise(W, H, 40, 4)
    a = np.asarray(img).astype(np.float32) * (0.8 + 0.25 * n[..., None])
    Image.fromarray(a.clip(0, 255).astype(np.uint8)).save(os.path.join(GEN, "prices.png"))


def sign(name, text, w=1024, h=256, bg=(230, 225, 210), fg=(30, 30, 30), fnt="PTSans-Bold.ttf", size=120, age=0.6):
    """Табличка: текст по центру по самим буквам (у Oswald высокий верхний вынос — по строке надпись садилась на
    нижний край), кегль уменьшается, пока надпись не влезет с полями (длинная строка вылезала за края)."""
    img = paper(w, h, bg, age, hash(name) % 999)
    d = ImageDraw.Draw(img)
    lines = text.split("\n")
    while True:
        f = font(fnt, size)
        pitch = size * 1.1
        boxes = [d.textbbox((0, 0), ln, font=f) for ln in lines]
        top = boxes[0][1]
        bottom = (len(lines) - 1) * pitch + boxes[-1][3]
        wide = max(b[2] - b[0] for b in boxes)
        if (wide <= w * 0.9 and bottom - top <= h * 0.78) or size <= 12:
            break
        size -= 2
    y0 = (h - (bottom - top)) / 2 - top
    for i, (ln, b) in enumerate(zip(lines, boxes)):
        d.text(((w - (b[2] - b[0])) / 2 - b[0], y0 + i * pitch), ln, font=f, fill=fg)
    img.save(os.path.join(GEN, "sign_" + name + ".png"))


def signs():
    sign("bani", "БАНИ", 1024, 256, (40, 34, 30), (205, 190, 160), "Oswald.ttf", 190, 0.9)
    sign("no3", "№ 3", 256, 256, (40, 34, 30), (205, 190, 160), "Oswald.ttf", 140, 0.9)
    sign("kassa", "КАССА", 512, 160, (200, 205, 200), (30, 60, 40), "PTSans-Bold.ttf", 90)
    sign("male", "МУЖСКОЕ\nОТДЕЛЕНИЕ", 512, 256, (200, 205, 210), (25, 40, 90), "PTSans-Bold.ttf", 70)
    sign("female", "ЖЕНСКОЕ\nОТДЕЛЕНИЕ", 512, 256, (210, 200, 205), (110, 25, 40), "PTSans-Bold.ttf", 70)
    sign("parilnya", "ПАРИЛЬНЯ", 512, 140, (90, 60, 40), (225, 200, 160), "PTSans-Bold.ttf", 80)
    sign("staff", "ПОСТОРОННИМ\nВХОД ВОСПРЕЩЁН", 512, 256, (210, 210, 205), (150, 20, 20), "PTSans-Bold.ttf", 58)
    sign("pump", "НАСОСНАЯ", 512, 140, (210, 210, 205), (30, 30, 30), "PTSans-Bold.ttf", 80)
    sign("garderob", "ГАРДЕРОБ", 512, 140, (200, 205, 200), (30, 60, 40), "PTSans-Bold.ttf", 80)
    sign("bufet", "БУФЕТ", 512, 140, (200, 205, 200), (30, 60, 40), "PTSans-Bold.ttf", 80)
    sign("closed", "БАНЯ ЗАКРЫТА\nНА РЕМОНТ\nс 22.12.2004", 512, 400, (235, 232, 220), (30, 30, 30), "PTSansNarrow-Bold.ttf", 66)
    sign("vvod", "ЗАДВИЖКА № 1\nВВОД", 512, 256, (200, 40, 30), (240, 235, 220), "PTSans-Bold.ttf", 70)
    sign("wet", "ОСТОРОЖНО!\nСКОЛЬЗКИЙ ПОЛ", 512, 256, (230, 210, 60), (20, 20, 20), "PTSans-Bold.ttf", 60)
    sign("exit", "ВЫХОД", 512, 160, (30, 110, 50), (230, 250, 230), "PTSans-Bold.ttf", 100, 0.2)
    sign("rules_short", "МЫТЬСЯ ПОСЛЕ\n22:00 ЗАПРЕЩЕНО", 512, 256, (225, 222, 205), (120, 20, 20), "PTSans-Bold.ttf", 60)
    sign("wash_feet", "ПОЛЬЗУЙТЕСЬ\nРЕЗИНОВЫМИ ТАПОЧКАМИ", 512, 256, (220, 225, 215), (30, 60, 40), "PTSansNarrow-Bold.ttf", 54)
    sign("water_save", "БЕРЕГИ\nВОДУ!", 512, 300, (40, 90, 150), (240, 240, 230), "Oswald.ttf", 110)
    sign("sauna_lux", "САУНА «ЛЮКС»\nс 22.00 — по записи", 512, 256, (60, 20, 20), (230, 190, 120), "PTSans-Bold.ttf", 54)
    sign("tech", "ТЕХНИЧЕСКИЙ\nКОРИДОР", 512, 256, (210, 210, 205), (30, 30, 30), "PTSans-Bold.ttf", 70)
    sign("kotelnaya", "КОТЕЛЬНАЯ", 512, 140, (200, 200, 195), (30, 30, 30), "PTSans-Bold.ttf", 80)


def portrait(seed, cap=False, woman=False, w=300, h=360):
    """Старое студийное фото на доску почёта: фон с градиентом, лицо со светлой и теневой стороной, волосы,
    уши, шея, воротник и пиджак, мягкие тени глаз и рта, виньетка, сепия, зерно, белое поле."""
    rnd = random.Random(seed)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    bg = 150 - yy / h * 45 + rnd.uniform(-8, 8)          # студийный фон: светлее сверху
    a = np.repeat(bg[..., None], 3, -1)
    ph = Image.fromarray(a.clip(0, 255).astype(np.uint8))
    pd = ImageDraw.Draw(ph, "RGBA")
    cx = w / 2 + rnd.uniform(-8, 8)
    hw, hh = rnd.uniform(46, 54), rnd.uniform(60, 68)    # полуширина и полувысота головы
    cy = 150 + rnd.uniform(-6, 6)
    skin, shade = int(150 + rnd.uniform(-10, 10)), 95
    # плечи и пиджак, рубашка с V-вырезом, шея
    pd.polygon([(cx - 135, h), (cx - 118, cy + hh + 52), (cx - 40, cy + hh + 28), (cx + 40, cy + hh + 28),
                (cx + 118, cy + hh + 52), (cx + 135, h)], fill=(48, 44, 40))
    pd.polygon([(cx - 34, cy + hh + 24), (cx + 34, cy + hh + 24), (cx, cy + hh + 105)], fill=(205, 200, 190))
    pd.polygon([(cx - 34, cy + hh + 24), (cx - 8, cy + hh + 70), (cx - 46, cy + hh + 44)], fill=(225, 222, 212))
    pd.polygon([(cx + 34, cy + hh + 24), (cx + 8, cy + hh + 70), (cx + 46, cy + hh + 44)], fill=(225, 222, 212))
    if woman:
        pd.polygon([(cx - 16, cy + hh + 30), (cx + 16, cy + hh + 30), (cx, cy + hh + 60)], fill=(70, 62, 56))  # брошь/вырез
    pd.rectangle((cx - 22, cy + hh - 20, cx + 22, cy + hh + 34), fill=(shade + 15,) * 3)
    # волосы за головой (у женщин — пышнее, ниже ушей)
    hair = (38, 34, 30) if not woman else (52, 44, 38)
    if woman:
        pd.ellipse((cx - hw - 30, cy - hh - 16, cx + hw + 30, cy + hh * 0.95), fill=hair)
    else:
        pd.ellipse((cx - hw - 7, cy - hh * 0.25, cx - hw + 9, cy + 18), fill=(skin - 25,) * 3)   # уши
        pd.ellipse((cx + hw - 9, cy - hh * 0.25, cx + hw + 7, cy + 18), fill=(skin - 25,) * 3)
    pd.ellipse((cx - hw, cy - hh, cx + hw, cy + hh), fill=(skin,) * 3)
    # свет слева: правая половина лица и шеи в мягкой тени (размытое пятно, только по лицу)
    sh = Image.new("L", (w, h), 0)
    ImageDraw.Draw(sh).ellipse((cx + hw * 0.05, cy - hh * 1.1, cx + hw * 1.6, cy + hh * 1.5), fill=110)
    face = Image.new("L", (w, h), 0)
    ImageDraw.Draw(face).ellipse((cx - hw - 8, cy - hh, cx + hw + 8, cy + hh), fill=255)
    ImageDraw.Draw(face).rectangle((cx - 22, cy + hh - 20, cx + 22, cy + hh + 34), fill=255)
    k = (np.asarray(sh.filter(ImageFilter.GaussianBlur(14)), np.float32) / 255.0
         * np.asarray(face.filter(ImageFilter.GaussianBlur(2)), np.float32) / 255.0)
    ph = Image.fromarray((np.asarray(ph, np.float32) * (1 - k[..., None])).clip(0, 255).astype(np.uint8))
    pd = ImageDraw.Draw(ph, "RGBA")
    # волосы / рабочая кепка сверху (низкая тулья шире головы, козырёк темнее)
    if cap:
        cb = cy - hh * 0.6 - 10                                           # низ тульи
        pd.chord((cx - hw - 12, cy - hh - 20, cx + hw + 12, cy - hh * 0.2), 180, 360, fill=(46, 40, 35))
        pd.chord((cx - hw - 8, cb - 12, cx + hw + 8, cb + 12), 0, 180, fill=(28, 25, 22))
    else:
        pd.chord((cx - hw - 3, cy - hh - 6, cx + hw + 3, cy + hh * 0.2), 180, 360, fill=hair)
    # глаза, брови, нос, рот — мягкие тени
    for s in (-1, 1):
        ex = cx + s * hw * 0.42
        pd.ellipse((ex - 11, cy - 10, ex + 11, cy + 2), fill=(40, 34, 30, 150))
        pd.line((ex - 14, cy - 18, ex + 12, cy - 19), fill=(35, 30, 26, 170), width=4)
    pd.polygon([(cx, cy - 4), (cx + 9, cy + 26), (cx - 4, cy + 28)], fill=(40, 34, 30, 60))
    pd.line((cx - 15, cy + hh * 0.55, cx + 15, cy + hh * 0.55 + 1), fill=(45, 34, 30, 170), width=4)
    ph = ph.filter(ImageFilter.GaussianBlur(2.6))
    a = np.asarray(ph).astype(np.float32).mean(-1)
    r = np.hypot((xx - w / 2) / (w * 0.62), (yy - h * 0.45) / (h * 0.62))
    a *= np.clip(1.08 - r ** 2 * 0.55, 0.45, 1.1)                       # виньетка
    a *= 0.86 + 0.24 * noise(w, h, 3, 2)                                # зерно
    a *= 0.92 + 0.12 * noise(w, h, 60, 3)                               # неровная печать
    sep = np.stack([a * 1.06, a * 0.96, a * 0.80], -1)                 # сепия
    out = Image.fromarray(sep.clip(0, 255).astype(np.uint8))
    return ImageOps.expand(out, 8, (226, 220, 204))


def honor_board():
    """Доска почёта: фото отца и трёх работников бани."""
    W, H = 400, 520
    people = [("honor_father", True, False, ["КОВАЛЁВ", "Николай Андреевич", "истопник, 1998"]),
              ("honor_0", False, True, ["СОМОВА", "Анна Петровна", "банщица"]),
              ("honor_1", False, True, ["ЧЕРНОВА", "Раиса Семёновна", "заведующая"]),
              ("honor_2", False, False, ["ЛАПТЕВ", "Иван Ильич", "кассир"])]
    for i, (name, cap, woman, lines) in enumerate(people):
        img = paper(W, H, (200, 190, 170), 0.7, 11 + i)
        d = ImageDraw.Draw(img)
        img.paste(portrait(31 + i * 7, cap, woman, 284, 340), (50, 26))
        # подпись крупнее: фамилия читается с пары метров
        y = 392
        for k, ln in enumerate(lines):
            f = font("PTSansNarrow-Bold.ttf", 38 if k == 0 else 28)
            tw = d.textlength(ln, font=f)
            d.text(((W - tw) / 2, y), ln, font=f, fill=(35, 30, 28))
            y += 44 if k == 0 else 34
        img.save(os.path.join(GEN, name + ".png"))


def evac_plan():
    """План эвакуации — тот же план, что в Layout (упрощённо)."""
    W, H = 1040, 640
    img = paper(W, H, (236, 236, 228), 0.3, 5)
    d = ImageDraw.Draw(img)
    d.text((30, 18), "ПЛАН ЭВАКУАЦИИ ПРИ ПОЖАРЕ. 1 ЭТАЖ", font=font("PTSans-Bold.ttf", 30), fill=(170, 20, 20))
    sx, sz, ox, oz = 18.5, 18.5, 40, 70
    rooms = {
        "Вестибюль": (14, 23, 38, 30), "Коридор": (16, 20, 36, 23), "Заведующая": (16, 17, 22, 20), "Бельевая": (22, 17, 27, 20),
        "Парикм.": (27, 17, 32, 20), "Буфет": (32, 17, 36, 20), "Ожид.": (0, 20, 4, 26), "Подсобка": (0, 26, 4, 30),
        "Раздевальня М": (4, 20, 14, 30), "Мыльная М": (0, 9, 14, 20), "Парильня М": (0, 3, 8, 9), "Душ М": (8, 3, 14, 9),
        "Бассейн": (14, 6, 38, 17), "Насосная": (30, 3, 38, 6), "Склад": (23, 3, 28, 6), "Технический коридор": (0, 0, 52, 3),
        "Раздевальня Ж": (38, 20, 48, 30), "Суш.": (48, 20, 52, 24), "Банщица": (48, 24, 52, 30), "Мыльная Ж": (38, 9, 52, 20),
        "Парильня Ж": (44, 3, 52, 9), "Душ Ж": (38, 3, 44, 9),
    }
    f = font("PTSansNarrow-Regular.ttf", 17)
    for name, (x0, z0, x1, z1) in rooms.items():
        box = (ox + x0 * sx, oz + z0 * sz, ox + x1 * sx, oz + z1 * sz)
        d.rectangle(box, outline=(30, 30, 30), width=3, fill=(250, 250, 244) if name != "Бассейн" else (215, 232, 240))
    # чаша бассейна
    d.rectangle((ox + 19 * sx, oz + 8.5 * sz, ox + 33 * sx, oz + 14.5 * sz), outline=(60, 100, 140), width=2, fill=(170, 205, 225))
    # стрелки эвакуации
    for (a, b) in [((26, 21.5), (26, 29.5)), ((9, 15), (9, 26)), ((45, 15), (45, 26)), ((26, 12), (26, 21))]:
        d.line((ox + a[0] * sx, oz + a[1] * sz, ox + b[0] * sx, oz + b[1] * sz), fill=(40, 150, 60), width=5)
        d.polygon([(ox + b[0] * sx - 9, oz + b[1] * sz - 12), (ox + b[0] * sx + 9, oz + b[1] * sz - 12), (ox + b[0] * sx, oz + b[1] * sz + 4)], fill=(40, 150, 60))
    # подписи — после чаши и стрелок, на светлой плашке: стрелки их больше не перечёркивают;
    # «Бассейн» — в полосе зала над чашей, а не под ней
    for name, (x0, z0, x1, z1) in rooms.items():
        box = (ox + x0 * sx, oz + z0 * sz, ox + x1 * sx, oz + z1 * sz)
        tw = d.textlength(name, font=f)
        tx = (box[0] + box[2] - tw) / 2
        if name == "Технический коридор":
            tx = ox + 4 * sx     # левее: в середине — вход в котельную
        ty = (box[1] + box[3]) / 2 - 9 if name != "Бассейн" else oz + 7.25 * sz - 9
        d.rectangle((tx - 3, ty + 1, tx + tw + 3, ty + 20), fill=(250, 250, 244) if name != "Бассейн" else (215, 232, 240))
        d.text((tx, ty), name, font=f, fill=(40, 40, 40))
    # вход в котельную — решётка на северной стене коридора (layout: d_grate, x 24.45…26.05)
    gx0, gx1 = ox + 24.45 * sx, ox + 26.05 * sx
    d.rectangle((gx0, oz - 4, gx1, oz + 4), fill=(60, 60, 60))
    for k in range(7):
        x = gx0 + (gx1 - gx0) * k / 6
        d.line((x, oz - 4, x, oz + 4), fill=(235, 235, 228), width=1)
    gtxt = "Котельная (вниз)"
    tw = d.textlength(gtxt, font=f)
    gx = (gx0 + gx1 - tw) / 2
    d.polygon([((gx0 + gx1) / 2 - 7, oz + 20), ((gx0 + gx1) / 2 + 7, oz + 20), ((gx0 + gx1) / 2, oz + 9)], fill=(170, 20, 20))
    d.rectangle((gx - 3, oz + 21, gx + tw + 3, oz + 40), fill=(250, 250, 244))
    d.text((gx, oz + 20), gtxt, font=f, fill=(170, 20, 20))
    d.ellipse((ox + 24 * sx, oz + 27 * sz, ox + 25 * sx, oz + 28 * sz), fill=(220, 30, 30))
    tw = d.textlength("Вы здесь", font=f)
    d.rectangle((ox + 25.3 * sx - 2, oz + 27 * sz + 1, ox + 25.3 * sx + tw + 2, oz + 27 * sz + 20), fill=(250, 250, 244))
    d.text((ox + 25.3 * sx, oz + 27 * sz), "Вы здесь", font=f, fill=(200, 20, 20))
    # примечание — справа от заголовка, над планом (внизу места нет: план кончается у края листа; размеры листа и
    # масштаб не трогаем — по ним телефон ставит точку «вы здесь»)
    for i, ln in enumerate(["Котельная — в подвале, вход из технического коридора.", "Ответственный: истопник Ковалёв Н.А."]):
        tw = d.textlength(ln, font=f)
        d.text((W - 30 - tw, 14 + i * 21), ln, font=f, fill=(50, 50, 50))
    img.save(os.path.join(GEN, "evac_plan.png"))


def mosaic():
    """Советская мозаика у бассейна: пловчиха, солнце, волны. Смальта ~3 см (стена 8 м — 256 кусочков в ширину),
    у каждого кусочка свой оттенок, тёмные швы; выпавшие кусочки — гнёздами, трещина, потёки снизу,
    лицо пловчихи замазано чёрным."""
    S = 2
    W, H = 1024 * S, 512 * S
    img = Image.new("RGB", (W, H), (60, 120, 150))
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, W, H * 0.45), fill=(230, 200, 120))
    d.ellipse((700 * S, 40 * S, 900 * S, 240 * S), fill=(240, 150, 60))
    for i in range(12):
        a = i * math.pi / 6
        d.line((800 * S, 140 * S, (800 + math.cos(a) * 170) * S, (140 + math.sin(a) * 170) * S), fill=(240, 170, 80), width=10 * S)
    for k in range(6):
        y = 250 + k * 40
        pts = [(x * S, (y + math.sin(x / 60 + k) * 12) * S) for x in range(0, 1044, 10)]
        d.line(pts, fill=(40 + k * 6, 100, 140 + k * 8), width=14 * S)
    d.ellipse((300 * S, 220 * S, 350 * S, 270 * S), fill=(230, 180, 150))
    d.polygon([(340 * S, 250 * S), (520 * S, 270 * S), (510 * S, 300 * S), (330 * S, 280 * S)], fill=(200, 40, 40))
    d.line((350 * S, 240 * S, 250 * S, 190 * S), fill=(230, 180, 150), width=18 * S)
    d.line((500 * S, 290 * S, 620 * S, 300 * S), fill=(230, 180, 150), width=18 * S)
    d.line((500 * S, 285 * S, 600 * S, 330 * S), fill=(230, 180, 150), width=18 * S)
    d.text((40 * S, 30 * S), "ЗДОРОВЬЕ НАРОДА — БОГАТСТВО СТРАНЫ", font=font("Oswald.ttf", 46 * S), fill=(150, 30, 30))
    a = np.asarray(img).astype(np.float32)
    t = 8
    gh, gw = H // t, W // t
    cells = a.reshape(gh, t, gw, t, 3).mean((1, 3))
    rng = np.random.default_rng(1961)
    cells *= rng.uniform(0.86, 1.12, (gh, gw, 1)) * rng.uniform(0.95, 1.05, (gh, gw, 3))
    # выпавшая смальта гнёздами (плюс одиночные), больше всего — вокруг лица пловчихи
    holes = noise(gw, gh, 10, 3)
    yy, xx = np.mgrid[0:gh, 0:gw]
    face = np.exp(-(((xx - 325 * S / t) / (40 * S / t)) ** 2 + ((yy - 245 * S / t) / (50 * S / t)) ** 2))
    miss = (holes > 0.86 - face * 0.55) | (rng.random((gh, gw)) < 0.01)
    cement = np.array([92, 88, 80], np.float32) * rng.uniform(0.7, 1.0, (gh, gw, 1))
    cells = np.where(miss[..., None], cement, cells)
    out = np.repeat(np.repeat(cells, t, 0), t, 1)
    # швы: тёмная затирка, кусочки чуть разного размера
    grout = np.zeros((H, W), np.float32)
    grout[::t, :] = 1
    grout[:, ::t] = 1
    jit = rng.random((gh, gw)) < 0.35
    jj = np.repeat(np.repeat(jit, t, 0), t, 1)
    grout[1::t, :] = np.maximum(grout[1::t, :], jj[1::t, :] * 0.6)
    grout[:, 1::t] = np.maximum(grout[:, 1::t], jj[:, 1::t] * 0.6)
    out = out * (1 - grout[..., None] * 0.55) + np.array([55, 52, 48]) * grout[..., None] * 0.55
    img = Image.fromarray(out.clip(0, 255).astype(np.uint8))
    d = ImageDraw.Draw(img, "RGBA")
    # трещина через всё панно
    x, y = 120 * S, 0
    pts = [(x, y)]
    while y < H:
        x += random.uniform(-14, 18) * S
        y += random.uniform(10, 24) * S
        pts.append((x, y))
    d.line(pts, fill=(25, 22, 20, 230), width=2 * S)
    # потёки снизу вверх от сырости и рыжие подтёки от труб
    for i in range(26):
        x0 = random.uniform(0, W)
        ln = random.uniform(80, 360) * S
        d.line((x0, H, x0 + random.uniform(-6, 6), H - ln), fill=(40, 34, 26, random.randint(25, 55)), width=random.randint(6, 16) * S)
    for i in range(6):
        x0 = random.uniform(0, W)
        d.line((x0, 0, x0 + random.uniform(-4, 4), random.uniform(60, 220) * S), fill=(120, 60, 20, 90), width=random.randint(3, 7) * S)
    # лицо пловчихи замазано
    for i in range(40):
        d.line((random.uniform(290, 360) * S, random.uniform(200, 300) * S, random.uniform(290, 360) * S, random.uniform(260, 420) * S), fill=(10, 10, 10, 160), width=random.randint(2, 6) * S)
    img.save(os.path.join(GEN, "mosaic.png"))


def child_drawing():
    W, H = 512, 400
    img = paper(W, H, (235, 232, 222), 0.4, 9)
    d = ImageDraw.Draw(img)
    # папа с ведром
    d.ellipse((90, 120, 140, 170), outline=(30, 60, 180), width=4)
    d.line((115, 170, 115, 270), fill=(30, 60, 180), width=4)
    d.line((115, 200, 80, 240), fill=(30, 60, 180), width=4)
    d.line((115, 200, 150, 230), fill=(30, 60, 180), width=4)
    d.line((115, 270, 90, 330), fill=(30, 60, 180), width=4)
    d.line((115, 270, 140, 330), fill=(30, 60, 180), width=4)
    d.rectangle((145, 225, 175, 255), outline=(150, 150, 150), width=3)
    # тётя: высокая, волосы до земли, очень длинные руки
    d.ellipse((300, 30, 350, 80), outline=(20, 20, 20), width=4)
    for i in range(38):
        x = 296 + i * 1.6
        d.line((x, 40, x + random.uniform(-25, 25), 370), fill=(15, 15, 15), width=2)
    d.line((310, 120, 220, 330), fill=(15, 15, 15), width=3)
    d.line((340, 120, 440, 330), fill=(15, 15, 15), width=3)
    for i in range(5):
        d.line((220, 330, 205 + i * 7, 352), fill=(15, 15, 15), width=2)
        d.line((440, 330, 430 + i * 7, 352), fill=(15, 15, 15), width=2)
    d.text((40, 20), "ПАПА И ТЁТЯ ХОЗЯЙКА", font=font("Neucha.ttf", 34), fill=(200, 40, 40))
    d.text((360, 360), "АНДРЕЙ 6 ЛЕТ", font=font("Neucha.ttf", 22), fill=(40, 120, 40))
    img.save(os.path.join(GEN, "child_drawing.png"))


def mirror_code():
    """Код на зеркале — виден только в пару (альфа). Холст в пропорциях зеркала 1.3×0.8 м (832×512) — буквы не
    растянуты; строки по центру по самим буквам (у Caveat наклон и свисания), с полями: край зеркала шейдер
    затемняет пятнами, туда надпись не заходит."""
    W, H = 832, 512

    def put(d, txt, size, cy, fill, max_w=W * 0.72):
        f = font("Caveat.ttf", size)
        while d.textbbox((0, 0), txt, font=f)[2] - d.textbbox((0, 0), txt, font=f)[0] > max_w and size > 30:
            size -= 4
            f = font("Caveat.ttf", size)
        bb = d.textbbox((0, 0), txt, font=f)
        d.text(((W - (bb[2] - bb[0])) / 2 - bb[0], cy - (bb[3] - bb[1]) / 2 - bb[1]), txt, font=f, fill=fill)

    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    put(d, "21·12", 170, H * 0.42, (255, 255, 255, 230))
    put(d, "техн.", 70, H * 0.72, (255, 255, 255, 200))
    img = img.filter(ImageFilter.GaussianBlur(2))
    img.save(os.path.join(GEN, "mirror_code.png"))
    # «помыться» — надпись в пару в женской раздевалке (раньше «ИЙ» уходило за правый край)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    put(d, "ЧИСТЕНЬКИЙ", 120, H * 0.46, (255, 255, 255, 230))
    img.filter(ImageFilter.GaussianBlur(2)).save(os.path.join(GEN, "mirror_word.png"))


def old_photo():
    W, H = 512, 360
    img = Image.new("RGB", (W, H), (150, 130, 100))
    d = ImageDraw.Draw(img)
    d.rectangle((0, 220, W, H), fill=(120, 105, 80))
    d.polygon([(150, 220), (150, 120), (260, 70), (370, 120), (370, 220)], fill=(60, 50, 40))
    for y in range(125, 220, 12):
        d.line((150, y, 370, y), fill=(45, 38, 30), width=3)
    d.rectangle((240, 160, 275, 220), fill=(25, 20, 18))
    for i, x in enumerate([90, 115, 400, 425, 450]):
        d.ellipse((x, 160, x + 18, 180), fill=(50, 42, 35))
        d.rectangle((x - 2, 180, x + 20, 230), fill=(55, 46, 38))
    # фигура в дверях — едва различима
    d.rectangle((250, 168, 262, 220), fill=(70, 62, 55))
    img = img.filter(ImageFilter.GaussianBlur(1.6))
    a = np.asarray(img).astype(np.float32) * (0.75 + 0.35 * noise(W, H, 20, 4)[..., None])
    img = Image.fromarray(a.clip(0, 255).astype(np.uint8))
    img = ImageOps.expand(img, 18, (225, 215, 190))
    ImageDraw.Draw(img).text((24, H + 14), "Баня Пряхиных у реки. 1903 г.", font=font("Caveat.ttf", 22), fill=(60, 50, 60))
    img.save(os.path.join(GEN, "old_photo.png"))


def calendar():
    W, H = 400, 560
    img = paper(W, H, (235, 232, 222), 0.5, 13)
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, W, 170), fill=(150, 40, 40))
    d.text((30, 30), "2004", font=font("Oswald.ttf", 90), fill=(240, 230, 210))
    d.text((30, 190), "ДЕКАБРЬ", font=font("PTSans-Bold.ttf", 40), fill=(40, 40, 40))
    f = font("PTSansNarrow-Regular.ttf", 28)
    for row in range(5):
        for col in range(7):
            n = row * 7 + col - 2           # 1 декабря 2004 — среда (третий столбец недели с понедельника)
            if 0 <= n < 31:
                x, y = 30 + col * 50, 260 + row * 52
                d.text((x, y), str(n + 1), font=f, fill=(40, 40, 40) if col < 5 else (170, 30, 30))
                if n + 1 <= 21:
                    d.line((x - 4, y + 4, x + 30, y + 30), fill=(60, 60, 90), width=2)
                if n + 1 == 22:
                    d.ellipse((x - 10, y - 6, x + 40, y + 40), outline=(170, 30, 30), width=3)
    img.save(os.path.join(GEN, "calendar.png"))


# ------------------------------------------------------------------ следы, возраст поверхностей, стекло

def footprint():
    """Мокрый след босой ноги с длинными пальцами (декаль; тёмный, альфа — форма)."""
    w, h = 128, 256
    im = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(im)
    d.ellipse((38, 168, 92, 240), fill=190)          # пятка
    d.polygon([(42, 200), (36, 140), (44, 104), (66, 100), (70, 150), (62, 205)], fill=150)  # свод: внешний край
    d.ellipse((30, 82, 102, 130), fill=210)          # подушечка
    toes = [(30, 8, 46, 78), (50, 0, 63, 72), (67, 6, 79, 74), (83, 18, 94, 80), (97, 38, 106, 86)]
    for t in toes:                                   # пальцы — слишком длинные, с промежутками
        d.ellipse(t, fill=225)
    im = im.filter(ImageFilter.GaussianBlur(1.6))
    a = np.asarray(im, np.float32) / 255.0
    a *= 0.7 + 0.3 * noise(w, h, 6, 2)
    rgba = np.zeros((h, w, 4), np.uint8)
    rgba[..., :3] = 30
    rgba[..., 3] = (np.clip(a, 0, 1) * 255).astype(np.uint8)
    Image.fromarray(rgba, "RGBA").save(os.path.join(GEN, "footprint.png"))


def tnoise(w, h, scale=32, octaves=4, rng=None):
    """Бесшовный шум: решётка случайных чисел повторена 3×3, растянута и вырезана из середины."""
    rng = rng or np.random.default_rng(3)
    out = np.zeros((h, w), np.float32)
    amp = 1.0
    for o in range(octaves):
        s = max(1, int(scale / (2 ** o)))
        gh, gw = max(1, h // s), max(1, w // s)
        small = rng.random((gh, gw)).astype(np.float32)
        big = np.tile(small, (3, 3))
        im = Image.fromarray((big * 255).astype(np.uint8)).resize((gw * 3 * s, gh * 3 * s), Image.BICUBIC)
        arr = np.asarray(im, np.float32)[gh * s:gh * s + h, gw * s:gw * s + w] / 255.0
        out += arr * amp
        amp *= 0.5
    out -= out.min()
    out /= max(out.max(), 1e-6)
    return out


def age_maps():
    """Карты «возраста» (детальный слой материалов, умножение): мир 6×4.5 м на тайл, низ картинки — пол.
    wall: пятна копоти и сырости, потёки от потолка, тёмная влажная полоса у пола.
    floor: разводы, тёмные мокрые пятна. ceil: рыжие кольца протечек, копоть."""
    out = os.path.join(ROOT, "tex", "age")
    os.makedirs(out, exist_ok=True)
    n = 1024
    rng = np.random.default_rng(1961)
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    v = yy / (n - 1)                          # 0 — верх (4.5 м), 1 — пол
    def save(name, dark, tint):
        mul = 1.0 - dark
        rgb = np.stack([np.clip(1.0 - (1.0 - mul) * t, 0, 1) for t in tint], -1)
        alpha = np.clip(dark * 1.8 + 0.06, 0, 1)
        # Детальный слой Godot: albedo *= mix(1, rgb, a), но и NORMAL_MAP тянется к плоской детальной нормали на a —
        # при большой альфе рельеф плитки и кирпича пятнами пропадал. Та же итоговая темнота кодируется наименьшей
        # альфой: k = a·(1 − rgb) в линейном (rgb читается как sRGB), a' = max k, rgb' = 1 − k/a'.
        def lin(c):
            return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)

        def srgb(c):
            return np.where(c <= 0.0031308, c * 12.92, 1.055 * np.power(np.clip(c, 0, 1), 1 / 2.4) - 0.055)
        k = alpha[..., None] * (1.0 - lin(rgb))
        a2 = np.ceil(np.clip(k.max(-1), 1 / 255, 1) * 255) / 255
        rgb2 = srgb(np.clip(1.0 - k / a2[..., None], 0, 1))
        img = np.concatenate([rgb2, a2[..., None]], -1)
        Image.fromarray((np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA").save(os.path.join(out, name + ".png"))
    blot = tnoise(n, n, 256, 5, rng)
    soot = np.clip((blot - 0.5) * 2.4, 0, 1)
    damp = np.clip((tnoise(n, n, 128, 4, rng) - 0.55) * 2.6, 0, 1)
    grain = tnoise(n, n, 8, 2, rng)
    # потёки: от верха вниз, разной длины и ширины, неровные по длине
    streak = np.zeros((n, n), np.float32)
    along = tnoise(n, n, 24, 3, rng)
    for i in range(46):
        x0 = rng.uniform(0, n)
        wd = rng.uniform(4, 22)
        top = rng.uniform(0.0, 0.25)
        length = rng.uniform(0.2, 0.7)
        strength = rng.uniform(0.3, 1.0)
        dx = np.abs(((xx[0] - x0 + n / 2) % n) - n / 2)
        prof = np.exp(-(dx / wd) ** 2)
        t = (v[:, 0] - top) / length
        fall = np.where((t > 0) & (t < 1), np.clip(1 - t, 0, 1) ** 0.8 * np.clip(t * 12, 0, 1), 0.0)
        streak = np.maximum(streak, fall[:, None] * prof[None, :] * strength)
    streak *= 0.55 + 0.45 * along
    band = np.clip((v - 0.84) / 0.16, 0, 1) ** 1.4 * (0.55 + 0.45 * tnoise(n, n, 64, 3, rng))
    dark = np.clip(soot * 0.32 + damp * 0.22 + streak * 0.38 + band * 0.5 + (grain - 0.5) * 0.06, 0, 0.8)
    save("wall", dark, (0.95, 1.0, 1.1))
    # пол: разводы и мокрые пятна
    darkf = np.clip(np.clip((tnoise(n, n, 256, 5, rng) - 0.42) * 1.7, 0, 1) * 0.3
                    + np.clip((tnoise(n, n, 160, 4, rng) - 0.58) * 3.0, 0, 1) * 0.3 + (grain - 0.5) * 0.05, 0, 0.75)
    save("floor", darkf, (1.0, 1.0, 1.05))
    # потолок: рыжие пятна протечек с мягкой каймой и копоть. Раньше кайма была тонкой тёмной линией, а край
    # дрожал от мелкого шума — пятна читались как кабели/волосы и сеткой пересекающихся колец. Теперь форму гнёт
    # крупный шум, тело пятна главное, кайма широкая и слабая, пятна сливаются мягко (не максимумом).
    # blot почти постоянен в пределах одного пятна (масштаб 256 px) и только меняет его размер — круг оставался
    # кругом; форму рвёт warp среднего масштаба (64 px, две октавы — мелкой дрожи края, как раньше, нет): край
    # уходит на ±30 % радиуса, пятно растекается лопастями.
    # У warp свой генератор — места и размеры пятен и карты wall/floor не сдвигаются
    warp = tnoise(n, n, 64, 2, np.random.default_rng(46))
    ring_map = np.zeros((n, n), np.float32)
    for i in range(8):
        cx, cy = rng.uniform(0, n, 2)
        rad = rng.uniform(60, 200)
        d = np.hypot(((xx - cx + n / 2) % n) - n / 2, ((yy - cy + n / 2) % n) - n / 2) / rad
        d *= (0.8 + 0.4 * blot) * (0.7 + 0.6 * warp)
        stain = np.clip(1 - d, 0, 1) ** 0.7 * 0.3 + np.exp(-((d - 0.97) / 0.17) ** 2) * 0.14
        ring_map = 1 - (1 - ring_map) * (1 - stain)
    pad = np.pad(np.clip(ring_map, 0, 1), 16, mode="wrap")          # размытие с переносом — тайл остаётся бесшовным
    ring_map = np.asarray(Image.fromarray((pad * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(3)), np.float32)[16:-16, 16:-16] / 255.0
    darkc = np.clip(ring_map + soot * 0.3, 0, 0.6)
    save("ceil", darkc, (0.8, 1.0, 1.25))


def window_frost():
    """Матовое заиндевевшее стекло (непрозрачное): у рамы сплошной иней, от краёв и углов внутрь растут
    «папоротники» (стебель, от него ветки под ~60°, у веток свои иглы), середина — тёмное ночное стекло.
    Раньше середина была не темнее ~0.4 (окна в полночь горели дневным облачным небом), а потом иглы делались
    мелким шумом, размазанным вдоль x/y: вблизи это читалось мехом или помехами (мех на окне в игре про волосы —
    те же волосы), а на углах смена x/y давала шов под 45°. Яркость и тёмная середина остались прежними
    (в среднем ≈0.1 линейного). RGB — яркость инея."""
    n = 512
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32) / (n - 1)
    rng = np.random.default_rng(29)
    ex, ey = np.minimum(xx, 1 - xx), np.minimum(yy, 1 - yy)
    edge = np.minimum(ex, ey) + (tnoise(n, n, 48, 3, rng) - 0.5) * 0.07   # рваная граница инея
    fine = tnoise(n, n, 3, 2, rng)
    crystal = tnoise(n, n, 12, 3, rng)
    frost = np.clip(1 - edge / (0.1 + 0.07 * crystal), 0, 1) ** 1.3      # сплошной иней у рамы
    # папоротники рисуются вдвое крупнее и сжимаются — тонкие линии сглажены. Свой генератор: общий random
    # (подписи, записки) от этой функции не сдвигается
    S = 2
    N = n * S
    im = Image.new("L", (N, N), 0)
    dr = ImageDraw.Draw(im)
    rnd = random.Random(29)

    def fern(x, y, ang, length, val, depth):
        # depth 2 — стебель (чуть изогнут), 1 — ветка, 0 — игла; ветки к кончику стебля короче
        step = (3.0 if depth == 2 else 2.0) * S
        steps = max(2, int(length / step))
        curv = rnd.uniform(-0.03, 0.03) if depth == 2 else rnd.uniform(-0.01, 0.01)
        pts = [(x, y)]
        for k in range(steps):
            ang += curv + rnd.gauss(0, 0.04)
            x += math.cos(ang) * step
            y += math.sin(ang) * step
            pts.append((x, y))
            left = 1 - k / steps
            if depth > 0 and k > 0 and k % (2 if depth == 2 else 1) == 0:
                for sgn in (-1, 1):
                    if rnd.random() < 0.85:
                        a2 = ang + sgn * rnd.uniform(0.95, 1.12)
                        l2 = length * (0.42 if depth == 2 else 0.3) * left ** 0.6 * rnd.uniform(0.6, 1.0)
                        if l2 > 2 * S:
                            fern(x, y, a2, l2, val * 0.85, depth - 1)
            if depth == 2 and k > 4 and rnd.random() < 0.03:           # изредка стебель ветвится
                fern(x, y, ang + rnd.choice((-1, 1)) * rnd.uniform(0.45, 0.7), length * left * 0.7, val * 0.9, 2)
        dr.line(pts, fill=int(val), width=(3, 2, 1)[2 - depth])

    for i in range(80):
        side = rnd.randrange(5)
        t = rnd.uniform(0.0, 1.0)
        inset = rnd.uniform(0.0, 0.06) * N
        if side == 0:      # левый край
            x, y, a = inset, t * N, 0.0
        elif side == 1:    # правый
            x, y, a = N - inset, t * N, math.pi
        elif side == 2:    # верх
            x, y, a = t * N, inset, math.pi / 2
        elif side == 3:    # низ
            x, y, a = t * N, N - inset, -math.pi / 2
        else:              # из угла по диагонали
            cx, cy = rnd.choice(((0, 0), (1, 0), (0, 1), (1, 1)))
            x, y = cx * N + (1 - 2 * cx) * inset, cy * N + (1 - 2 * cy) * inset
            a = math.atan2(1 - 2 * cy, 1 - 2 * cx)
        fern(x, y, a + rnd.uniform(-0.6, 0.6), rnd.uniform(0.07, 0.26) * N, rnd.uniform(150, 255), 2)
    for i in range(25):    # снизу намерзает больше
        t = rnd.uniform(0.0, 1.0)
        fern(t * N, N - rnd.uniform(0.0, 0.05) * N, -math.pi / 2 + rnd.uniform(-0.7, 0.7), rnd.uniform(0.06, 0.18) * N, rnd.uniform(150, 255), 2)
    dend = np.asarray(im.resize((n, n), Image.LANCZOS).filter(ImageFilter.GaussianBlur(0.6)), np.float32) / 255.0
    reach = np.clip(1 - edge / 0.3, 0, 1) ** 0.8                          # кончики папоротников гаснут к середине
    low = np.clip((yy - 0.8) / 0.2, 0, 1) * 0.2
    a = np.clip(frost * (0.45 + 0.35 * crystal) + dend * reach * (1 - 0.5 * frost) * 0.95
                + low * (0.6 + 0.4 * crystal) + (fine - 0.5) * 0.04, 0, 1)
    v = 0.1 + 0.72 * a
    rgba = np.zeros((n, n, 3), np.uint8)
    rgba[..., 0] = (np.clip(v * (0.9 + 0.06 * dend), 0, 1) * 255).astype(np.uint8)
    rgba[..., 1] = (np.clip(v * 0.96, 0, 1) * 255).astype(np.uint8)
    rgba[..., 2] = (np.clip(v, 0, 1) * 255).astype(np.uint8)
    Image.fromarray(rgba, "RGB").save(os.path.join(GEN, "window_frost.png"))



def hair_clump():
    """Свисающий/лежащий комок волос: пряди сходятся к узлу сверху и редеют книзу (альфа ~30 %),
    чтобы плоская карточка не читалась сплошной доской."""
    w, h = 128, 512
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rnd = random.Random(11)
    for i in range(110):
        x_end = rnd.uniform(4, w - 4)
        x_top = w / 2 + rnd.uniform(-10, 10)
        end = rnd.uniform(0.45, 1.0) * h
        c = rnd.randint(6, 26)
        pts = []
        for k in range(20):
            t = k / 19
            x = x_top + (x_end - x_top) * (t ** 0.7) + math.sin(t * 7 + i) * 2.5
            pts.append((x, t * end))
        d.line(pts, fill=(c, c, c + 2, rnd.randint(170, 255)), width=rnd.choice([1, 1, 2]))
    d.ellipse((w / 2 - 14, -6, w / 2 + 14, 22), fill=(10, 10, 10, 255))
    img.save(os.path.join(OUT, "hair_clump.png"))



def puddle_soot():
    """Лужа (декаль: тёмное мокрое пятно, ORM — низкая шероховатость) и копоть (вертикальный «язык» над топкой)."""
    n = 256
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32) / (n - 1)
    r = np.hypot(xx - 0.5, yy - 0.5) * 2
    blob = noise(n, n, 40, 4)
    a = np.clip((1.0 - r + (blob - 0.5) * 0.9) * 2.2 - 0.6, 0, 1)
    rgba = np.zeros((n, n, 4), np.uint8)
    rgba[..., 0] = 34
    rgba[..., 1] = 38
    rgba[..., 2] = 40
    rgba[..., 3] = (a * 255).astype(np.uint8)
    Image.fromarray(rgba, "RGBA").save(os.path.join(GEN, "puddle.png"))
    orm = np.zeros((n, n, 3), np.uint8)
    orm[..., 0] = 255
    orm[..., 1] = (np.clip(0.08 + (1 - a) * 0.6, 0, 1) * 255).astype(np.uint8)
    orm[..., 2] = 0
    Image.fromarray(orm, "RGB").save(os.path.join(GEN, "puddle_orm.png"))
    # копоть: шире кверху, рваные края
    w, h = 128, 256
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    v = yy / (h - 1)                    # 0 — верх
    half = 0.18 + (1 - v) * 0.3
    dx = np.abs(xx / (w - 1) - 0.5)
    edge = noise(w, h, 12, 3)
    a = np.clip((half - dx + (edge - 0.5) * 0.15) / 0.12, 0, 1) * (0.2 + 0.8 * v ** 0.7) * np.clip(v * 4, 0, 1)
    rgba = np.zeros((h, w, 4), np.uint8)
    rgba[..., :3] = 18
    rgba[..., 3] = (np.clip(a, 0, 1) * 255).astype(np.uint8)
    Image.fromarray(rgba, "RGBA").save(os.path.join(GEN, "soot.png"))



def light_cookies():
    """Маски света (light_projector): окно с переплётом и инеем, решётка топки, рамы фонаря бассейна;
    и текстура углей за решёткой топки (эмиссия)."""
    n = 256
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32) / (n - 1)
    def soft_rect(x0, x1, y0, y1, s):
        return (np.clip((xx - x0) / s, 0, 1) * np.clip((x1 - xx) / s, 0, 1) * np.clip((yy - y0) / s, 0, 1) * np.clip((y1 - yy) / s, 0, 1))
    # окно: прямоугольник с крестом переплёта и форточкой, снизу намёрзло (темнее), края инея ярче
    win = soft_rect(0.12, 0.88, 0.1, 0.9, 0.06)
    bar = np.maximum(np.exp(-((xx - 0.5) / 0.022) ** 2), np.exp(-((yy - 0.36) / 0.02) ** 2))
    win *= 1.0 - 0.92 * bar
    win *= 0.75 + 0.25 * noise(n, n, 12, 3)
    win *= 1.0 - 0.45 * np.clip((yy - 0.72) / 0.18, 0, 1)
    Image.fromarray((np.clip(win, 0, 1) * 255).astype(np.uint8)).save(os.path.join(GEN, "cookie_window.png"))
    # решётка топки: горизонтальные прутья, мягкий спад к краям — полосатый клин на полу
    r = np.hypot(xx - 0.5, (yy - 0.5) * 1.2) * 2
    body = np.clip(1 - r, 0, 1) ** 0.8
    bars = 0.25 + 0.75 * (0.5 + 0.5 * np.cos((yy - 0.5) * 2 * math.pi * 7.0)) ** 3
    Image.fromarray((np.clip(body * bars, 0, 1) * 255).astype(np.uint8)).save(os.path.join(GEN, "cookie_grate.png"))
    # фонарь в потолке бассейна: пять рам поперёк
    sky = soft_rect(0.04, 0.96, 0.1, 0.9, 0.08)
    for i in range(5):
        sky *= 1.0 - 0.85 * np.exp(-((xx - (0.1 + i * 0.2)) / 0.018) ** 2)
    sky *= 0.8 + 0.2 * noise(n, n, 20, 3)
    Image.fromarray((np.clip(sky, 0, 1) * 255).astype(np.uint8)).save(os.path.join(GEN, "cookie_skylight.png"))
    # угли за решёткой дверцы топки: чёрные прутья, между ними жар с тёмными пятнами
    w, h = 256, 128
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    heat = noise(w, h, 10, 4)
    heat = np.clip((heat - 0.25) * 1.6, 0, 1) ** 1.3
    rods = (np.cos(yy / h * 2 * math.pi * 4.0) > 0.55).astype(np.float32)
    frame = ((xx < 10) | (xx > w - 11) | (yy < 8) | (yy > h - 9)).astype(np.float32)
    v = heat * (1 - rods) * (1 - frame)
    rgb = np.stack([np.clip(v * 1.0 + 0.02, 0, 1), np.clip(v ** 1.6 * 0.55 + 0.01, 0, 1), np.clip(v ** 3 * 0.18, 0, 1)], -1)
    Image.fromarray((rgb * 255).astype(np.uint8)).save(os.path.join(GEN, "firebox.png"))


if __name__ == "__main__":
    flash_cookie()
    steam_puff()
    hair_strands()
    skin()
    signs()
    price_list()
    honor_board()
    evac_plan()
    mosaic()
    child_drawing()
    mirror_code()
    old_photo()
    calendar()
    notes_textures()
    rules_board()
    footprint()
    age_maps()
    window_frost()
    hair_clump()
    puddle_soot()
    light_cookies()
    print("текстуры готовы")
