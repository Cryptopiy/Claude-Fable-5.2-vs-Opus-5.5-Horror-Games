"""Скачивает сторонние ассеты (все CC0 / MIT / OFL) в tex/, mdl/, fonts/.

    python tools/fetch_assets.py            — скачать то, чего нет
    python tools/fetch_assets.py --force    — перекачать всё
    python tools/fetch_assets.py --fix      — только повторяемые правки FIX над уже скачанным и CREDITS.txt (без
                                              сети; POST не трогает — он применяется один раз, сразу после скачивания)

Источники и лицензии записываются в CREDITS.txt.
"""
import io
import json
import os
import sys
import urllib.request
import zipfile
from concurrent.futures import ThreadPoolExecutor

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FORCE = "--force" in sys.argv
UA = {"User-Agent": "Mozilla/5.0 (asset fetch for a hobby game)"}

# имя материала в игре: (источник, id)
TEX = {
    "tile_wall": ("acg", "Tiles141"),
    "tile_broken": ("acg", "Tiles133D"),
    "tile_pool": ("acg", "Tiles133A"),
    "tile_dark": ("acg", "Tiles140"),
    "tile_green": ("acg", "Tiles032"),
    "tile_floor": ("ph", "square_tiles_02"),
    "tile_floor2": ("ph", "brown_floor_tiles"),
    "terracotta": ("ph", "terracotta_floor_tiles"),
    "linoleum": ("ph", "old_linoleum_flooring_01"),
    "paint_green": ("acg", "PaintedPlaster003"),
    "paint_blue": ("acg", "PaintedPlaster002"),
    "plaster": ("ph", "worn_plaster_wall"),
    "plaster_dmg": ("ph", "damaged_plaster"),
    "peeling": ("ph", "peeling_painted_wall"),
    "wallpaper": ("ph", "decrepit_wallpaper"),
    "facade": ("ph", "yellow_plaster"),
    "concrete": ("ph", "concrete_floor_worn_001"),
    "concrete_dirty": ("ph", "dirty_concrete"),
    "brick_dark": ("ph", "dark_brick_wall"),
    "brick_red": ("ph", "red_brick"),
    "planks": ("ph", "old_planks_02"),
    "planks_dark": ("ph", "dark_wooden_planks"),
    "planks_weather": ("ph", "weathered_planks"),
    "logs": ("ph", "wood_trunk_wall"),
    "rust": ("ph", "rusty_metal_02"),
    "metal_green": ("ph", "green_metal_rust"),
    "grate": ("ph", "metal_grate_rusty"),
    "rust_paint": ("ph", "rusty_painted_metal"),
    "snow": ("ph", "snow_02"),
    "terry": ("ph", "terry_cloth"),
    "coal": ("acg", "Gravel024"),
    "cloth": ("acg", "Fabric032"),
}

PH_MODELS = [
    "crowbar_01", "pipe_wrench", "vintage_flashlight", "wooden_bucket_01", "wooden_bucket_02",
    "wooden_stool_01", "wooden_stool_02", "painted_wooden_bench", "painted_wooden_cabinet",
    "painted_wooden_chair_01", "painted_wooden_table", "BarberShopChair_01", "CashRegister_01",
    "wall_clock", "metal_office_desk", "metal_toolbox", "rusted_spade_01", "wooden_broom", "rubber_boots",
    "old_bed_frame", "wooden_candlestick", "vintage_oil_lamp", "vintage_radio_transceiver", "Television_01",
    "hanging_industrial_lamp", "power_box_01", "metal_trash_can",
    "wooden_crate_01", "cardboard_box_01", "rubber_duck_toy", "pot_enamel_01", "metal_jug",
    "standing_picture_frame_01", "wheelchair_01", "vintage_suitcase", "alarm_clock_01", "clipboard",
    "metal_stool_01", "wooden_ladder", "vintage_electric_kettle", "metal_tool_chest",
    "russian_food_cans_01", "cigarette_pack", "desk_lamp_arm_01", "wicker_basket_01",
    "WoodenTable_01", "WoodenChair_01", "wooden_crate_02", "cement_bag", "tea_set_01", "painted_wooden_chair_02",
    "cleaner_tin_01", "painted_wooden_stool",
]

RB = "https://raw.githubusercontent.com/microsoft/Microsoft-Rocketbox/master/Assets/"
RB_FILES = {
    "mdl/rb/hozyayka/hozyayka.fbx": "Avatars/Adults/Female_Adult_02/Export/Female_Adult_02_facial.fbx",
    "mdl/rb/hozyayka/body_color.tga": "Avatars/Adults/Female_Adult_02/Textures/f002_body_color.tga",
    "mdl/rb/hozyayka/body_normal.tga": "Avatars/Adults/Female_Adult_02/Textures/f002_body_normal.tga",
    "mdl/rb/hozyayka/head_color.tga": "Avatars/Adults/Female_Adult_02/Textures/f002_head_color.tga",
    "mdl/rb/hozyayka/head_normal.tga": "Avatars/Adults/Female_Adult_02/Textures/f002_head_normal.tga",
    "mdl/rb/hozyayka/opacity_color.tga": "Avatars/Adults/Female_Adult_02/Textures/f002_opacity_color.tga",
    "mdl/rb/man/man.fbx": "Avatars/Adults/Male_Adult_01/Export/Male_Adult_01.fbx",
    "mdl/rb/man/body_color.tga": "Avatars/Adults/Male_Adult_01/Textures/m002_body_color.tga",
    "mdl/rb/man/head_color.tga": "Avatars/Adults/Male_Adult_01/Textures/m002_head_color.tga",
    "mdl/rb/anim/walk_injured.fbx": "Animations/all_animations_max_motextr_xy/f_walk_injured.max.fbx",
    "mdl/rb/anim/walk_bruised.fbx": "Animations/all_animations_max_motextr_xy/f_walk_bruised.max.fbx",
    "mdl/rb/anim/walk_drunk.fbx": "Animations/all_animations_max_motextr_xy/f_walk_drunk.max.fbx",
    "mdl/rb/anim/run_injured.fbx": "Animations/all_animations_max_motextr_xy/f_run_injured.max.fbx",
    "mdl/rb/anim/idle_breathe.fbx": "Animations/all_animations_max_motextr_static/f_idle_breathe_01.max.fbx",
    "mdl/rb/anim/look_around.fbx": "Animations/all_animations_max_motextr_static/f_idle_look_around_01.max.fbx",
    "mdl/rb/anim/crouch_idle.fbx": "Animations/all_animations_max_motextr_static/f_crouch_idle.max.fbx",
    "mdl/rb/anim/crouch_in.fbx": "Animations/all_animations_max_motextr_static/f_crouch_in.max.fbx",
    "mdl/rb/anim/m_sit.fbx": "Animations/all_animations_max_motextr_static/m_sit_chair_idle_neutral_01.max.fbx",
}

GF = "https://raw.githubusercontent.com/google/fonts/main/ofl/"
FONTS = {
    "fonts/PTSans-Regular.ttf": "ptsans/PT_Sans-Web-Regular.ttf",
    "fonts/PTSans-Bold.ttf": "ptsans/PT_Sans-Web-Bold.ttf",
    "fonts/PTSansNarrow-Regular.ttf": "ptsansnarrow/PT_Sans-Narrow-Web-Regular.ttf",
    "fonts/PTSansNarrow-Bold.ttf": "ptsansnarrow/PT_Sans-Narrow-Web-Bold.ttf",
    "fonts/PTSerif-Regular.ttf": "ptserif/PT_Serif-Web-Regular.ttf",
    "fonts/PTSerif-Italic.ttf": "ptserif/PT_Serif-Web-Italic.ttf",
    "fonts/PTMono-Regular.ttf": "ptmono/PTM55FT.ttf",
    "fonts/MarckScript-Regular.ttf": "marckscript/MarckScript-Regular.ttf",
    "fonts/Neucha.ttf": "neucha/Neucha.ttf",
    "fonts/Caveat.ttf": "caveat/Caveat%5Bwght%5D.ttf",
    "fonts/RuslanDisplay.ttf": "ruslandisplay/RuslanDisplay-Regular.ttf",
    "fonts/Oswald.ttf": "oswald/Oswald%5Bwght%5D.ttf",
}


def get(url, tries=3):
    last = None
    for _ in range(tries):
        try:
            return urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=120).read()
        except Exception as e:  # noqa: BLE001
            last = e
    raise RuntimeError(f"{url}: {last}")


def save_img(data, path, size=1024, mode=None):
    im = Image.open(io.BytesIO(data))
    if mode:
        im = im.convert(mode)
    elif im.mode not in ("RGB", "L", "RGBA"):
        im = im.convert("RGB")
    if max(im.size) > size:
        im = im.resize((size, size), Image.LANCZOS)
    if path.endswith(".jpg") and im.mode == "RGBA":
        im = im.convert("RGB")
    im.save(path, quality=90)


def grade_brick(d):
    """Тёмный кирпич: жёлтые швы раствора светились под фонарём и огнём — притемнить и «закоптить» швы,
    чуть убрать насыщенность кирпича. Вызывается сразу после скачивания (повторно не применяется)."""
    import numpy as np
    p = os.path.join(d, "albedo.jpg")
    a = np.asarray(Image.open(p).convert("RGB"), np.float32) / 255.0
    lum = a @ np.array([0.3, 0.59, 0.11], np.float32)
    sat = a.max(-1) - a.min(-1)
    mortar = np.clip((lum - 0.22) / 0.18, 0, 1) * np.clip((sat - 0.05) / 0.15, 0, 1)
    grey = lum[..., None].repeat(3, -1)
    a = a * (1 - 0.25) + grey * 0.25                         # меньше насыщенность
    dirty = grey * np.array([0.55, 0.52, 0.48], np.float32)  # серо-бурый закопчённый раствор
    a = a * (1 - mortar[..., None] * 0.8) + dirty * (mortar[..., None] * 0.8)
    Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)).save(p, quality=90)



def calm_plaster(d):
    """Штукатурка: крупные тёмные проплешины давали «камуфляж» на стенах и потолках вестибюля и раздевален.
    Крупный масштаб сжимается к среднему тону, мелкая фактура остаётся; грязь сверху добавляет слой «возраста»."""
    import numpy as np
    from PIL import ImageFilter
    p = os.path.join(d, "albedo.jpg")
    im = Image.open(p).convert("RGB")
    a = np.asarray(im, np.float32) / 255.0
    blur = np.asarray(im.filter(ImageFilter.GaussianBlur(28)), np.float32) / 255.0
    mean = a.reshape(-1, 3).mean(0)
    detail = a - blur
    out = mean * 0.6 + blur * 0.4 + detail * 0.85
    Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8)).save(p, quality=90)



def logs_horizontal(d):
    """Сруб: в текстуре брёвна стоят вертикально, а сруб рубят горизонтально — повернуть на 90° (нормаль — с
    поворотом каналов: (nx, ny) -> (-ny, nx))."""
    import numpy as np
    for name in ("albedo.jpg", "rough.jpg"):
        p = os.path.join(d, name)
        if os.path.exists(p):
            Image.open(p).rotate(90).save(p, quality=90)
    p = os.path.join(d, "normal.jpg")
    if os.path.exists(p):
        a = np.asarray(Image.open(p).convert("RGB").rotate(90), np.float32)
        out = a.copy()
        out[..., 0] = 255.0 - a[..., 1]
        out[..., 1] = a[..., 0]
        Image.fromarray(out.astype(np.uint8)).save(p, quality=90)


POST = {"brick_dark": grade_brick, "plaster": calm_plaster, "logs": logs_horizontal}


# ---- правки, которые можно запускать повторно: каждая сама видит, что уже сделана (python tools/fetch_assets.py --fix)

def _load(p):
    import numpy as np
    return np.asarray(Image.open(p).convert("RGB"), np.float32)


def _store(a, p):
    import numpy as np
    Image.fromarray(np.clip(a + 0.5, 0, 255).astype(np.uint8)).save(p, quality=90)


def unband_plaster(d):
    """Штукатурка: в текстуре запечён вертикальный стык плит (u≈0.65–0.74, две тёмные линии и полоса между ними) —
    на стенах и потолках он ложился «балкой» каждые 3 м. Полоса вырезается из всех трёх карт, края сходятся
    плавным переходом, остаток растягивается обратно до исходной ширины (фактура шире на ~14 %, края тайла не
    тронуты — бесшовность цела). Стык ищется по нормали (две резкие линии); нет его — уже сделано."""
    import numpy as np
    pn = os.path.join(d, "normal.jpg")
    if not os.path.exists(pn):
        return
    nr = _load(pn)[..., 0].mean(0)
    w = nr.shape[0]
    l0, r0 = int(w * 0.637), int(w * 0.748)      # 652..766 при 1024: полоса с линиями и ореолом сжатия
    zone = nr[int(w * 0.61):int(w * 0.77)]
    if np.abs(zone - np.median(nr)).max() < 25:
        return
    fade = int(w * 0.02)
    for name in ("albedo.jpg", "normal.jpg", "rough.jpg"):
        p = os.path.join(d, name)
        if not os.path.exists(p):
            continue
        a = _load(p)
        t = np.linspace(0, 1, fade, dtype=np.float32)[None, :, None]
        seam = a[:, l0 - fade:l0] * (1 - t) + a[:, r0:r0 + fade] * t
        out = np.concatenate([a[:, :l0 - fade], seam, a[:, r0 + fade:]], 1)
        k = w / out.shape[1]
        im = Image.fromarray(np.clip(out + 0.5, 0, 255).astype(np.uint8)).resize((w, a.shape[0]), Image.LANCZOS)
        res = np.asarray(im, np.float32)
        if name == "normal.jpg":
            res[..., 0] = 127.5 + (res[..., 0] - 127.5) / k   # рельеф растянут по x — наклон по x меньше
        _store(res, p)


def even_boards(d):
    """Тёмные доски парилки: одна доска в тайле заметно темнее (на стенах — тёмный пояс на одной высоте по всей
    комнате) и одна поперечная стыковка (сетка стыков через 1.8 м). Яркость и тон каждой доски подтягиваются к
    средним, стыковка закрывается куском той же доски. Повторно: доски уже ровные, стыка нет — ничего не меняется."""
    import numpy as np
    pa, pn = os.path.join(d, "albedo.jpg"), os.path.join(d, "normal.jpg")
    if not (os.path.exists(pa) and os.path.exists(pn)):
        return
    nrm = _load(pn)
    h, w = nrm.shape[:2]
    # продольные швы между досками — резкие строки в зелёном канале нормали
    g = np.abs(nrm[..., 1].mean(1) - 127.5)
    rows = [y for y in range(h) if g[y] > 18 and g[y] >= g[max(0, y - 6):y + 7].max()]
    joints = []
    for y in rows:
        if not joints or y - joints[-1] > h // 20:
            joints.append(y)
    if len(joints) < 4:
        return
    alb = _load(pa)
    mean = alb.reshape(-1, 3).mean(0)
    gain = np.ones((h, 3), np.float32)
    for i, y0 in enumerate(joints):
        y1 = joints[(i + 1) % len(joints)] + (h if i + 1 == len(joints) else 0)
        idx = np.arange(y0 + 6, y1 - 6) % h
        if len(idx) < 10:
            continue
        # по каналам: тёмная доска ещё и серо-синяя рядом с бурыми — выравнивается и тон (на 85 %, разница остаётся)
        gk = np.clip(mean / np.maximum(alb[idx].reshape(-1, 3).mean(0), 1.0), 0.8, 1.25) ** 0.85
        gain[np.arange(y0 + 2, y1 - 1) % h] = gk
    if np.abs(gain - 1).max() > 0.04:
        _store(alb * gain[:, None, :], pa)
    # поперечный стык: короткая вертикальная линия в красном канале нормали внутри одной доски
    rr = np.abs(nrm[..., 0] - 127.5)
    for i, y0 in enumerate(joints):
        y1 = joints[(i + 1) % len(joints)] + (h if i + 1 == len(joints) else 0)
        if y1 > h:
            continue
        col = rr[y0 + 8:y1 - 8].mean(0)
        x = int(col.argmax())
        if col[x] < 16 or x < w // 6 or x > w - w // 6:
            continue
        x0, x1, f = x - w // 32, x + w // 32, w // 64
        src = x0 - w // 6
        t = np.ones(x1 - x0, np.float32)
        t[:f] = np.linspace(0, 1, f)
        t[-f:] = np.linspace(1, 0, f)
        t = t[None, :, None]
        for name in ("albedo.jpg", "normal.jpg", "rough.jpg"):
            p = os.path.join(d, name)
            if not os.path.exists(p):
                continue
            a = _load(p)
            a[y0 + 3:y1 - 2, x0:x1] = a[y0 + 3:y1 - 2, x0:x1] * (1 - t) + a[y0 + 3:y1 - 2, src:src + x1 - x0] * t
            _store(a, p)
        nrm = _load(pn)
        rr = np.abs(nrm[..., 0] - 127.5)


def fade_flecks(d, k=0.75):
    """Краска: белые круглые «сколы», рассыпанные почти решёткой, читались как снег/горошек на стене. Пятна светлее
    местного тона гасятся к нему на k (остаются едва заметные следы). Повторно — пятен нет, ничего не меняется."""
    import numpy as np
    from PIL import ImageFilter
    p = os.path.join(d, "albedo.jpg")
    if not os.path.exists(p):
        return
    im = Image.open(p).convert("RGB")
    a = np.asarray(im, np.float32)
    lum = a.mean(-1)
    # местный тон без пятен: медиана мелкой копии (окно ~140 px — шире самых крупных сколов), потом сглаживание
    small = im.resize((im.width // 16, im.height // 16), Image.BILINEAR).filter(ImageFilter.MedianFilter(9))
    base = np.asarray(small.resize(im.size, Image.BICUBIC).filter(ImageFilter.GaussianBlur(8)), np.float32)
    m = np.clip((lum - base.mean(-1) - 14) / 22, 0, 1)
    if (m > 0.5).mean() < 0.001:
        return
    m = np.asarray(Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(3))
                   .filter(ImageFilter.GaussianBlur(1.5)), np.float32)[..., None] / 255.0
    _store(a * (1 - m * k) + base * (m * k), p)


def soften_snow(d):
    """Снег: тёмные «каракули» (края наста) почти чёрные — на большом дворе через 3 м повторялись как волосы или
    трещины. Пиксель не темнее 90 % местного тона: наст остаётся мягкой тенью. Повторно — уже в пределах."""
    import numpy as np
    from PIL import ImageFilter
    p = os.path.join(d, "albedo.jpg")
    if not os.path.exists(p):
        return
    im = Image.open(p).convert("RGB")
    a = np.asarray(im, np.float32)
    small = im.resize((im.width // 8, im.height // 8), Image.BILINEAR).filter(ImageFilter.MedianFilter(5))
    base = np.asarray(small.resize(im.size, Image.BICUBIC).filter(ImageFilter.GaussianBlur(6)), np.float32) * 0.9
    m = np.clip((base - a).max(-1) / 20.0, 0, 1)
    if (m > 0.5).mean() < 0.0005:
        return
    _store(np.maximum(a, base), p)
    # в нормали каракули — резкие канавки: там, где альбедо было тёмным, рельеф прижать к плоскости
    pn = os.path.join(d, "normal.jpg")
    if os.path.exists(pn):
        mm = np.asarray(Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(5))
                        .filter(ImageFilter.GaussianBlur(2)), np.float32)[..., None] / 255.0
        n = _load(pn)
        n[..., :2] = 127.5 + (n[..., :2] - 127.5) * (1 - 0.75 * mm)
        _store(n, pn)


FIX = {"plaster": unband_plaster, "planks_dark": even_boards, "paint_green": fade_flecks,
       "paint_blue": lambda d: fade_flecks(d, 0.8), "snow": soften_snow}


def fix_existing():
    for name, fn in FIX.items():
        d = os.path.join(ROOT, "tex", name)
        if os.path.exists(os.path.join(d, "albedo.jpg")):
            fn(d)
            print("fix", name, flush=True)
    # список правок в CREDITS.txt — та же строковая сборка, сети не нужно (иначе build.py везёт старый список)
    credits()
    print("CREDITS.txt обновлён", flush=True)


def tex_job(name, src, aid):
    d = os.path.join(ROOT, "tex", name)
    if os.path.exists(os.path.join(d, "albedo.jpg")) and not FORCE:
        return f"tex {name}: есть"
    os.makedirs(d, exist_ok=True)
    if src == "ph":
        info = json.loads(get(f"https://api.polyhaven.com/files/{aid}"))
        for key, out in (("Diffuse", "albedo.jpg"), ("nor_gl", "normal.jpg"), ("Rough", "rough.jpg")):
            if key in info:
                save_img(get(info[key]["1k"]["jpg"]["url"]), os.path.join(d, out))
    else:
        z = zipfile.ZipFile(io.BytesIO(get(f"https://ambientcg.com/get?file={aid}_1K-JPG.zip")))
        for n in z.namelist():
            low = n.lower()
            out = None
            if low.endswith("_color.jpg"):
                out = "albedo.jpg"
            elif low.endswith("_normalgl.jpg"):
                out = "normal.jpg"
            elif low.endswith("_roughness.jpg"):
                out = "rough.jpg"
            if out:
                save_img(z.read(n), os.path.join(d, out))
    if name in POST:
        POST[name](d)
    if name in FIX:
        FIX[name](d)
    return f"tex {name}: {src}:{aid}"


def model_job(aid):
    d = os.path.join(ROOT, "mdl", "ph", aid)
    if os.path.exists(os.path.join(d, aid + ".gltf")) and not FORCE:
        return f"model {aid}: есть"
    os.makedirs(d, exist_ok=True)
    info = json.loads(get(f"https://api.polyhaven.com/files/{aid}"))
    g = info["gltf"]["1k"]["gltf"]
    with open(os.path.join(d, aid + ".gltf"), "wb") as f:
        f.write(get(g["url"]))
    for rel, inc in g["include"].items():
        p = os.path.join(d, rel)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        data = get(inc["url"])
        if rel.endswith(".jpg") or rel.endswith(".png"):
            im = Image.open(io.BytesIO(data))
            if max(im.size) > 512:  # предметы мелкие — хватит 512
                im = im.resize((512, 512), Image.LANCZOS)
            im.save(p, quality=88)
        else:
            with open(p, "wb") as f:
                f.write(data)
    return f"model {aid}"


def rb_job(dst, src):
    p = os.path.join(ROOT, dst)
    if dst.endswith(".tga"):
        p = p[:-4] + ".png"
    if os.path.exists(p) and not FORCE:
        return f"rb {dst}: есть"
    os.makedirs(os.path.dirname(p), exist_ok=True)
    data = get(RB + src)
    if dst.endswith(".tga"):
        save_img(data, p, 1024, "RGBA" if "opacity" in dst else "RGB")
    else:
        with open(p, "wb") as f:
            f.write(data)
    return f"rb {dst}"


def font_job(dst, src):
    p = os.path.join(ROOT, dst)
    if os.path.exists(p) and os.path.getsize(p) > 0 and not FORCE:
        return f"font {dst}: есть"
    os.makedirs(os.path.dirname(p), exist_ok=True)
    data = get(GF + src)
    with open(p, "wb") as f:
        f.write(data)
    return f"font {dst}"


def credits():
    lines = [
        "ТРЕТИЙ ПАР — источники сторонних ассетов", "",
        "Текстуры — ambientCG (ambientcg.com) и Poly Haven (polyhaven.com), лицензия CC0:",
    ]
    for name, (src, aid) in sorted(TEX.items()):
        lines.append(f"  {name}: {'ambientCG' if src == 'acg' else 'Poly Haven'} {aid}")
    lines += ["", "Модели предметов — Poly Haven, CC0:"]
    lines += ["  " + ", ".join(PH_MODELS)]
    lines += ["", "Люди и анимации — Microsoft Rocketbox (github.com/microsoft/Microsoft-Rocketbox), лицензия MIT:",
              "  Female_Adult_02 (основа Хозяйки, сильно изменена), Male_Adult_01, анимации f_walk_injured,",
              "  f_walk_bruised, f_walk_drunk, f_run_injured, f_idle_breathe_01, f_idle_look_around_01,",
              "  f_crouch_idle, f_crouch_in, m_sit_chair_idle_neutral_01.",
              "", "Шрифты — Google Fonts, SIL Open Font License 1.1:",
              "  PT Sans, PT Sans Narrow, PT Serif, PT Mono (ParaType), Marck Script, Neucha, Caveat, Ruslan Display, Oswald.",
              "", "Изменены при скачивании (tools/fetch_assets.py, POST и FIX): brick_dark — притемнены швы раствора,",
              "  plaster — сглажены крупные пятна и убран вертикальный стык плит, logs — повёрнута на 90° (брёвна",
              "  сруба горизонтально), planks_dark — выровнен тон досок и закрыт поперечный стык, paint_green и",
              "  paint_blue — погашены белые пятна-сколы, snow — смягчены тёмные края наста.",
              "", "Всё остальное (звук, голоса, таблички, записки, мозаика, волосы, здание, карты «возраста» стен,",
              "  иней на стёклах, следы, лужи, копоть, небо) сделано для игры кодом (tools/make_tex.py, шейдеры)."]
    with open(os.path.join(ROOT, "CREDITS.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")


def main():
    jobs = []
    with ThreadPoolExecutor(6) as ex:
        for name, (src, aid) in TEX.items():
            jobs.append(ex.submit(tex_job, name, src, aid))
        for aid in PH_MODELS:
            jobs.append(ex.submit(model_job, aid))
        for dst, src in RB_FILES.items():
            jobs.append(ex.submit(rb_job, dst, src))
        for dst, src in FONTS.items():
            jobs.append(ex.submit(font_job, dst, src))
        bad = 0
        for j in jobs:
            try:
                print(j.result(), flush=True)
            except Exception as e:  # noqa: BLE001
                bad += 1
                print("ОШИБКА", e, flush=True)
    credits()
    print("готово, ошибок:", bad)


if __name__ == "__main__":
    if "--fix" in sys.argv:
        fix_existing()
    else:
        main()
