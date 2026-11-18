class_name Mat
## Материалы: текстуры из tex/<имя>/ (albedo, normal, rough) с мировой трипланарной проекцией.

static var _cache := {}
static var _tex := {}

## метров на один повтор текстуры. Крупнее, чем «по фактуре», там, где у текстуры есть заметные приметы и они
## вставали в ряд на длинных стенах: peeling (крупная проплешина уходит из видимой полосы стены), plaster_dmg
## (кирпичные прогалы; 3.3 — компромисс: при 4.0 кирпич в прогалах вдвое крупнее настоящего и рядом с brick_red
## читался «великанским», при 3.3 — ряд ~0.14 м), plaster (пятна; 3.6 — не кратно сетке комнат в 1 м), wallpaper (тёмное пятно),
## paint_blue (сколы). Текстуры plaster, planks_dark, paint_*, snow ещё и поправлены (fetch_assets.py, FIX).
## brick_red 1.5 — ряд 75 мм, как у настоящего кирпича и у brick_dark (было 60 мм — «игрушечный»).
const SIZE := {
	"tile_wall": 1.3, "tile_broken": 1.3, "tile_pool": 1.0, "tile_dark": 1.6, "tile_green": 1.0,
	"tile_floor": 1.4, "tile_floor2": 1.8, "terracotta": 2.4, "linoleum": 2.2, "paint_green": 2.5,
	"paint_blue": 3.5, "plaster": 3.6, "plaster_dmg": 3.3, "peeling": 4.0, "wallpaper": 3.2, "facade": 3.0,
	"concrete": 3.0, "concrete_dirty": 3.0, "brick_dark": 0.9, "brick_red": 1.5, "planks": 1.8,
	"planks_dark": 1.8, "planks_weather": 2.0, "logs": 1.6, "rust": 2.0, "metal_green": 1.6, "grate": 1.2,
	"rust_paint": 2.0, "snow": 4.0, "terry": 0.6, "coal": 1.2, "cloth": 1.0,
}


## приглушить слишком яркие краски. paint_blue — нейтральный множитель (синий множитель на сиреневой текстуре
## давал насыщенный «королевский» синий); coal — гравий Gravel024 серый, уголь почти чёрный, чуть холодный
const TINTS := {
	"paint_blue": Color(0.53, 0.52, 0.46), "paint_green": Color(0.55, 0.62, 0.55), "tile_green": Color(0.6, 0.7, 0.62),
	"facade": Color(0.8, 0.72, 0.6), "terracotta": Color(0.75, 0.68, 0.62), "linoleum": Color(0.75, 0.7, 0.6),
	"peeling": Color(0.7, 0.72, 0.72), "brick_red": Color(0.78, 0.74, 0.72), "coal": Color(0.48, 0.47, 0.5),
}


## слой «возраста»: метров на повтор по горизонтали. Потолок — крупнее (пятна протечек не повторяются рядом на
## больших потолках), фасад — 17 м (на стене 52 м иначе одни и те же потёки каждые 6 м)
const AGE_W := {"wall": 6.0, "floor": 6.0, "ceil": 11.0}
const AGE_W_MAT := {"facade": 17.0}


static func tex(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex[path]


## Основной материал. opts: tint (Color), wet (0..1), scale (метров на повтор), rough (множитель),
## emission (Color), emission_energy, uv (true = обычные UV вместо трипланара), cull_off, metal,
## age ("wall" / "floor" / "ceil") — слой «возраста» (копоть, потёки, сырость у пола, протечки) поверх текстуры,
## age_y / age_h — пол и высота помещения: потёки начинаются у потолка, сырая полоса — у пола.
## age_w — метров на повтор слоя по горизонтали (по умолчанию AGE_W / AGE_W_MAT); age_ox — сдвиг слоя по
## горизонтали в долях повтора: трипланар одинаков для противоположных стен (запад/восток, север/юг читают одно
## и то же место карты зеркально) — стене одной из пары можно дать age_ox 0.5.
## uv_ox — то же для основной текстуры (трипланар), в долях её повтора: например 0.37 у стен «e» и «s»,
## чтобы проплешины и пятна не повторялись зеркально на противоположной стене.
## local — трипланар в координатах объекта, а не мира: для того, что двигается (створки, дверцы, крышки),
## иначе текстура «плывёт» по поверхности при повороте.
static func m(name: String, opts := {}) -> StandardMaterial3D:
	var key := name + str(opts)
	if opts.has("age"):
		key += str(Settings.quality >= 1)
	if _cache.has(key):
		return _cache[key]
	var mat := StandardMaterial3D.new()
	var base := "res://tex/%s/" % name
	var alb := tex(base + "albedo.jpg")
	if alb:
		mat.albedo_texture = alb
	var nrm := tex(base + "normal.jpg")
	if nrm:
		mat.normal_enabled = true
		mat.normal_texture = nrm
		mat.normal_scale = float(opts.get("normal", 1.0))
	var rgh := tex(base + "rough.jpg")
	if rgh:
		mat.roughness_texture = rgh
	var wet := float(opts.get("wet", 0.0))
	mat.roughness = lerpf(1.0, 0.28, wet) * float(opts.get("rough", 1.0))
	var tint: Color = opts.get("tint", Color(1, 1, 1))
	if not opts.has("tint") and TINTS.has(name):
		tint = TINTS[name]
	mat.albedo_color = tint.darkened(wet * 0.25)
	if opts.has("metal"):
		mat.metallic = float(opts["metal"])
		mat.metallic_specular = 0.6
	if not bool(opts.get("uv", false)):
		var s := float(opts.get("scale", SIZE.get(name, 2.0)))
		mat.uv1_triplanar = true
		mat.uv1_world_triplanar = not bool(opts.get("local", false))
		mat.uv1_triplanar_sharpness = 8.0
		mat.uv1_scale = Vector3.ONE / s
		if opts.has("uv_ox"):
			# сдвиг по горизонтали (x и z) в долях повтора, высота не трогается
			var ox := float(opts["uv_ox"])
			mat.uv1_offset = Vector3(ox, 0.0, ox)
	if opts.has("emission"):
		mat.emission_enabled = true
		mat.emission = opts["emission"]
		mat.emission_energy_multiplier = float(opts.get("emission_energy", 1.0))
	if bool(opts.get("cull_off", false)):
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if opts.has("age") and Settings.quality >= 1:
		var kind := String(opts["age"])
		# ширина по материалу — только для стен: фасадной штукатуркой кроются и побелённые потолки (builder),
		# им нужна потолочная ширина AGE_W["ceil"], а не фасадные 17 м (иначе пятна протечек втрое крупнее)
		var aw: float = AGE_W.get(kind, 6.0)
		if kind == "wall":
			aw = AGE_W_MAT.get(name, aw)
		aw = float(opts.get("age_w", aw))
		_age(mat, kind, float(opts.get("age_y", 0.0)), float(opts.get("age_h", 4.5)), aw, float(opts.get("age_ox", 0.0)))
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_cache[key] = mat
	return mat


## Детальный слой «возраста»: крупная карта (w м по горизонтали, высота помещения по вертикали) в мировых
## координатах умножается на основную текстуру — ломает повтор плитки и кирпича, даёт копоть и потёки.
## Низкое качество — без слоя (минус три выборки текстуры на пиксель).
static func _age(mat: StandardMaterial3D, kind: String, y0: float, h: float, w := 6.0, ox := 0.0) -> void:
	var t := tex("res://tex/age/%s.png" % kind)
	if t == null:
		return
	mat.detail_enabled = true
	mat.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	mat.detail_uv_layer = BaseMaterial3D.DETAIL_UV_2
	mat.detail_albedo = t
	mat.uv2_triplanar = true
	mat.uv2_world_triplanar = true
	mat.uv2_triplanar_sharpness = 6.0
	var sy := 1.0 / maxf(h, 1.0)
	# в трипланаре Godot v = -(y·scale + offset): при offset = -y0·scale нижний край картинки ложится на пол,
	# верхний — на потолок помещения
	var sw := 1.0 / maxf(w, 1.0)
	mat.uv2_scale = Vector3(sw, sy, sw)
	mat.uv2_offset = Vector3(ox, -y0 * sy, ox)


## Однотонный материал без текстуры.
static func flat(col: Color, rough := 0.8, metal := 0.0, opts := {}) -> StandardMaterial3D:
	var key := "flat" + str(col) + str(rough) + str(metal) + str(opts)
	if _cache.has(key):
		return _cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = rough
	mat.metallic = metal
	if opts.has("emission"):
		mat.emission_enabled = true
		mat.emission = opts["emission"]
		mat.emission_energy_multiplier = float(opts.get("emission_energy", 1.0))
	if col.a < 0.999:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if bool(opts.get("unshaded", false)):
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if bool(opts.get("cull_off", false)):
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache[key] = mat
	return mat


## Материал с картинкой (табличка, записка, плакат) на обычных UV.
static func picture(path: String, opts := {}) -> StandardMaterial3D:
	var key := "pic" + path + str(opts)
	if _cache.has(key):
		return _cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex(path)
	mat.roughness = float(opts.get("rough", 0.85))
	mat.albedo_color = opts.get("tint", Color(1, 1, 1))
	if bool(opts.get("alpha", false)):
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = 0.4
	if opts.has("emission_energy"):
		mat.emission_enabled = true
		mat.emission_texture = mat.albedo_texture
		mat.emission_energy_multiplier = float(opts["emission_energy"])
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_cache[key] = mat
	return mat


static func clear() -> void:
	_cache.clear()
