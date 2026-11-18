extends Node3D
## Метель: штрихи по ветру и позёмка (часть snow.gd; в общей метели строятся слои mid и drift): ночная пурга, снятая на 16-мм плёнку при налобном фонаре.
## Слои (от дальнего к ближнему):
##  • дальняя пыль — мелкие тусклые точки, тают в тумане (только «Полные эффекты пурги»);
##  • завесы — редкие большие мягкие облака несомого снега, пряди вдоль ветра (только полные эффекты);
##  • пелена позёмки по самому насту + тонкие струйки позёмки у поверхности;
##  • средние и ближние хлопья — мягкие штрихи смаза: длина от скорости относительно камеры, яркость
##    от сохранения энергии (длинный штрих бледнее — в порыв не «светящиеся палки»), голова ярче хвоста;
##  • у самого объектива — редкие большие размытые пятна «боке» (только полные эффекты);
##  • объёмный туман (FogVolume): дымка позёмки у наста и стена порыва (только полные эффекты).
## Всё светится только в настоящем свете. Частицы не рождаются и не умирают: живут в коробках вокруг камеры
## и переносятся на другую сторону, а сколько их видно — решает поле плотности (база ночи, волны, порыв).
## Порыв приходит с наветренной стороны рваной стеной: впереди неё снега мало, за ней — гуще и быстрее.
## Договор с Weather: setup(w) — построить; set_hide_boxes(mn, mx, n) — коробки помещений (снег внутри
## не рисуется); tick(w, cam_pos, dt) — каждый кадр: за камерой, плотность и скорость от w.intensity(), w.gust,
## w.base, w.indoor, w.clear, w.vis, Cfg.fx.

const WIND_DIR := Vector3(0.7071, 0.0, 0.7071)
const WD := Vector2(0.7071, 0.7071)
const PERIOD := 400.0          # путь ветра берётся по модулю: все узоры вдоль ветра кратны этому периоду, м
const FRONT_START := 15.0      # с какого расстояния против ветра приходит стена порыва, м
const SHEET_R := 17.0          # полуширина пелены позёмки, м
const SHEET_STEP := 0.75       # шаг её сетки (едет за камерой этим шагом, иначе вершины «плывут»)
const FOG_HALF := 26.0         # полуширина объёма тумана пурги, м (дальше объёмный туман не считается)

var _layers: Array = []        # слои частиц: словари настроек + gp/pm/dm
var _sheet: MeshInstance3D = null
var _sheet_mat: ShaderMaterial = null
var _fog: FogVolume = null
var _fog_mat: ShaderMaterial = null
var _n_lo: Texture2D = null    # плавный шум (крупные узоры)
var _n_hi: Texture2D = null    # мелкий шум (пряди, струи)
var _box_mn := PackedVector3Array()
var _box_mx := PackedVector3Array()
var _box_n := 0
var _adv := 0.0                # путь ветра по модулю PERIOD, м
var _front_s := -10000.0       # передний край порыва (координата вдоль ветра), м
var _front_on := false
var _last_cp := Vector3.ZERO
var _has_last := false
var _cam_vel := Vector3.ZERO
# состав (задаётся до setup, когда модуль — часть общей метели): какие слои строить, нужны ли пелена позёмки и туман
var only_layers: Array = []    # пусто — все слои
var with_sheet := true
var with_fog := true


func setup(_w: Node3D) -> void:
	_n_lo = _noise_tex(5.0, 3, 4111)
	_n_hi = _noise_tex(14.0, 4, 4222)
	var move: Shader = load("res://src/shaders/snow_streaks_move.gdshader")
	var flake: Shader = load("res://src/shaders/snow_streaks_flake.gdshader")
	var veil: Shader = load("res://src/shaders/snow_streaks_veil.gdshader")
	# дальняя пыль: мелкие точки в глубине, тают в тумане (коробка выше камеры: верх кадра на 10–16 м — это 3–9 м над ней)
	_add_layer({"id": "far", "amount": 900, "half": Vector3(16.0, 4.5, 16.0), "y": 2.2, "look_k": 4.5, "fx_only": true,
		"dens0": 0.25, "dens1": 0.68, "near_b": 10.0, "far_a": 13.0, "far_b": 16.0, "prio": -5,
		"proc": {"fall_min": 0.4, "fall_max": 1.4, "speed_var": 0.3, "gust_dens": 1.0, "ridge_dens": 0.5, "band_k": 0.3},
		"draw": {"r_min": 0.006, "r_max": 0.013, "shutter": 0.0125, "aperture": 0.02, "focus": 4.0, "opacity": 2.2,
			"a_max": 0.5, "near_a": 8.5, "near_b": 10.0, "tail": 0.4, "twinkle": 1.0, "lit": 0.5}}, move, flake)
	# завесы несомого снега: редкие большие облака, пряди вдоль ветра; в порыв — стеной
	_add_layer({"id": "veil", "kind": "veil", "amount": 22, "half": Vector3(11.0, 2.2, 11.0), "y": -0.1, "look_k": 1.2, "fx_only": true,
		"dens0": 0.25, "dens1": 0.5, "near_b": 3.2, "far_a": 10.0, "far_b": 14.0, "prio": -4, "turb_k": 0.35, "speed_k": 0.95,
		"margin": 5.0,
		"proc": {"fall_min": 0.0, "fall_max": 0.3, "speed_var": 0.1, "gust_dens": 1.2, "ridge_dens": 0.6, "band_k": 0.35},
		"draw": {"n_lo": _n_lo, "n_hi": _n_hi, "wd": WD, "density": 0.035, "size_min": 1.0, "size_max": 1.7,
			"near_a": 1.2, "near_b": 3.2, "lit": 0.25}}, move, veil)
	# средние хлопья: штрихи 3–10 м — глубина пурги в луче (по высоте — до верхнего края кадра на 7–10 м)
	_add_layer({"id": "mid", "amount": 3350, "half": Vector3(10.0, 3.8, 10.0), "y": 1.5, "look_k": 2.4, "fx_off": 0.75,
		"dens0": 0.26, "dens1": 0.71, "near_b": 4.3, "far_a": 8.5, "far_b": 10.0, "prio": -3,
		"proc": {"fall_min": 0.4, "fall_max": 1.4, "speed_var": 0.3, "gust_dens": 1.0, "ridge_dens": 0.5, "band_k": 0.3},
		"draw": {"r_min": 0.003, "r_max": 0.008, "shutter": 0.0125, "aperture": 0.02, "focus": 4.0, "opacity": 2.0,
			"a_max": 0.6, "near_a": 3.3, "near_b": 4.3, "tail": 0.3, "twinkle": 1.0, "lit": 0.45}}, move, flake)
	# позёмка: тонкие струйки у самого наста, идут струями вдоль ветра
	_add_layer({"id": "drift", "amount": 1500, "half": Vector3(9.5, 2.0, 9.5), "ground": true, "fx_off": 0.7,
		"dens0": 0.3, "dens1": 0.75, "near_b": 1.6, "far_a": 7.5, "far_b": 9.5, "prio": -3, "turb_k": 0.6,
		"proc": {"ground": 1.0, "h_max": 0.45, "speed_var": 0.25, "gust_dens": 0.9, "ridge_dens": 0.3, "band_k": 0.0},
		"draw": {"r_min": 0.0012, "r_max": 0.003, "shutter": 0.03, "aperture": 0.02, "focus": 4.0, "opacity": 10.0,
			"a_max": 0.35, "near_a": 0.8, "near_b": 1.6, "tail": 0.2, "twinkle": 0.5, "lift": 1.0, "lit": 0.55}}, move, flake)
	# ближние хлопья: основной слой 1–4 м; в порыв их втрое больше — это и есть стена снега в луче
	_add_layer({"id": "near", "amount": 6000, "half": Vector3(4.6, 2.4, 4.6), "y": 0.35, "look_k": 0.9, "fx_off": 0.85,
		"near_hi": Vector2(0.9, 1.45), "near_lo": Vector2(0.45, 0.9),
		"dens0": 0.22, "dens1": 0.55, "near_b": 1.45, "far_a": 3.5, "far_b": 4.4, "prio": -2,
		"proc": {"fall_min": 0.4, "fall_max": 1.4, "speed_var": 0.3, "gust_dens": 1.0, "ridge_dens": 0.5, "band_k": 0.25},
		"draw": {"r_min": 0.0025, "r_max": 0.0075, "shutter": 0.0125, "aperture": 0.03, "focus": 4.0, "opacity": 1.0,
			"a_max": 0.45, "near_a": 0.9, "near_b": 1.45, "tail": 0.3, "twinkle": 0.6, "lit": 0.42}}, move, flake)
	# у самого объектива: редкие большие мягкие пятна «боке»
	_add_layer({"id": "bokeh", "amount": 220, "half": Vector3(1.8, 1.3, 1.8), "y": 0.0, "fx_only": true,
		"dens0": 0.25, "dens1": 0.55, "near_b": 0.32, "far_a": 1.15, "far_b": 1.6, "prio": -1,
		"proc": {"fall_min": 0.3, "fall_max": 1.0, "speed_var": 0.3, "gust_dens": 0.8, "ridge_dens": 0.35, "band_k": 0.2},
		"draw": {"r_min": 0.004, "r_max": 0.009, "shutter": 0.008, "aperture": 0.034, "focus": 4.0, "opacity": 1.0,
			"a_max": 0.35, "near_a": 0.16, "near_b": 0.32, "disc": 0.35, "tail": 0.5, "twinkle": 0.0, "lit": 0.3}}, move, flake)
	if with_sheet:
		_build_sheet(load("res://src/shaders/snow_streaks_sheet.gdshader"))
	if with_fog:
		_build_fog(load("res://src/shaders/snow_streaks_fog.gdshader"))
	if _box_n > 0:
		set_hide_boxes(_box_mn, _box_mx, _box_n)


func set_hide_boxes(mn: PackedVector3Array, mx: PackedVector3Array, n: int) -> void:
	_box_mn = mn
	_box_mx = mx
	_box_n = n
	for m in _all_mats():
		var sm: ShaderMaterial = m
		sm.set_shader_parameter("box_n", n)
		sm.set_shader_parameter("box_min", mn)
		sm.set_shader_parameter("box_max", mx)


func tick(w: Node3D, cp: Vector3, dt: float) -> void:
	dt = clampf(dt, 0.0, 0.1)
	var inten: float = w.intensity()
	var base: float = clampf(float(w.base), 0.0, 1.0)
	var gust: float = clampf(float(w.gust), 0.0, 1.0)
	var clear: float = clampf(float(w.clear), 0.0, 1.0)
	var indoor: float = clampf(float(w.indoor), 0.0, 1.0)
	var vis: float = float(w.vis)
	var fx: bool = Cfg.fx

	# скорость камеры: смаз считается относительно неё (идёшь против ветра — штрихи длиннее)
	if _has_last and dt > 0.0001:
		var mv := cp - _last_cp
		if mv.length() > 3.0:
			_cam_vel = Vector3.ZERO       # телепорт (этап, люк ледника)
		else:
			_cam_vel = _cam_vel.lerp(mv / dt, clampf(dt * 8.0, 0.0, 1.0))
	_last_cp = cp
	_has_last = true

	# ветер: скорость от силы пурги (с порывом); путь ветра — для узоров, которые он сносит
	var calm := 1.0 - clear * 0.5
	var wind_u := (4.5 + 5.5 * clampf(inten, 0.0, 1.3)) * calm
	_adv = fposmod(_adv + wind_u * dt, PERIOD)
	var turb := 1.0 + 0.3 * wind_u

	# стена порыва: рождается с наветренной стороны и бежит по ветру чуть быстрее ветра
	var s_cam := cp.x * WD.x + cp.z * WD.y
	if gust > 0.02:
		if not _front_on:
			_front_on = true
			# порыв только начался — стена впереди; модуль создан посреди порыва — она уже прошла
			_front_s = s_cam - (FRONT_START if gust < 0.35 else -80.0)
		_front_s += (wind_u * 1.15 + 2.0) * dt
		_front_s = maxf(_front_s, s_cam - FRONT_START - 4.0)
	else:
		_front_on = false
		_front_s = s_cam - 10000.0

	# плотность: в помещении снег за окнами и дверью идёт реже (внутри построек его прячут коробки)
	var out_s := maxf(1.0 - indoor, 0.5)
	var kill := 1.0 - clear * 0.92
	var gk := gust * kill
	# туман окружения (как в Weather): хлопья гасим сами, мягче — ближний снег в порыв не тонет
	var fog_e := lerpf(vis, 60.0, indoor * (1.0 - clear))
	var fog_b := lerpf(vis * 0.08, 8.0, indoor)
	var relief_k := 1.0 if (fx and indoor < 0.99) else 0.0
	var vph := 540.0
	var look_y := 0.0              # синус наклона взгляда: смотрим вверх — коробки поднимаются за взглядом
	var cn = w.cam
	if cn != null and is_instance_valid(cn):
		var cam: Camera3D = cn as Camera3D
		if cam != null and cam.is_inside_tree():
			vph = maxf(cam.get_viewport().get_visible_rect().size.y, 100.0)
			look_y = clampf(-cam.global_transform.basis.z.y, -0.9, 0.9)

	for L in _layers:
		var cfg: Dictionary = L
		var gp: GPUParticles3D = cfg["gp"]
		var pm: ShaderMaterial = cfg["pm"]
		var dm: ShaderMaterial = cfg["dm"]
		var fx_only: bool = cfg.get("fx_only", false)
		var ground: bool = cfg.get("ground", false)
		var is_veil: bool = String(cfg.get("kind", "flake")) == "veil"
		var near_b: float = cfg.get("near_b", 0.5)
		var far_a: float = cfg.get("far_a", 8.0)
		var far_b: float = cfg.get("far_b", 10.0)
		var on := fx or not fx_only
		# дальше видимости (туман глухой) не рисуем зря
		if indoor < 0.5:
			far_b = minf(far_b, fog_e + 1.0)
			far_a = minf(far_a, far_b * 0.8)
		# слой гаснет плавно, пока видимость падает, и только потом выключается (без хлопка)
		var lay_k := clampf((far_b - near_b - 0.3) / 1.2, 0.0, 1.0)
		if lay_k <= 0.001:
			on = false
		gp.visible = on
		if not on:
			continue
		var y_ofs: float = cfg.get("y", 0.0)
		var look_k: float = cfg.get("look_k", 0.0)
		var c := cp + Vector3(0.0, y_ofs + look_y * look_k, 0.0)
		if ground:
			c = Vector3(cp.x, 0.0, cp.z)
		gp.global_position = c
		var d0: float = cfg.get("dens0", 0.3)
		var d1: float = cfg.get("dens1", 0.6)
		var fx_off: float = cfg.get("fx_off", 1.0)
		var turb_k: float = cfg.get("turb_k", 1.0)
		var speed_k: float = cfg.get("speed_k", 1.0)
		var dens := lerpf(d0, d1, base) * out_s * kill * (1.0 if fx else fx_off)
		pm.set_shader_parameter("center", c)
		pm.set_shader_parameter("cam_vel", _cam_vel)
		pm.set_shader_parameter("wind_u", wind_u * speed_k)
		pm.set_shader_parameter("adv", _adv)
		pm.set_shader_parameter("turb", turb * turb_k)
		pm.set_shader_parameter("dens", dens)
		pm.set_shader_parameter("gust", gk)
		pm.set_shader_parameter("front_s", _front_s)
		dm.set_shader_parameter("far_a", far_a)
		dm.set_shader_parameter("far_b", far_b)
		dm.set_shader_parameter("fade_k", lay_k)
		# без «боке» (упрощённые эффекты) ближний слой подходит ближе к объективу — у лица не пусто
		if cfg.has("near_lo"):
			var nl: Vector2 = cfg["near_lo"] if not fx else cfg["near_hi"]
			dm.set_shader_parameter("near_a", nl.x)
			dm.set_shader_parameter("near_b", nl.y)
		if is_veil:
			dm.set_shader_parameter("adv", _adv)
		else:
			dm.set_shader_parameter("vp_h", vph)
			dm.set_shader_parameter("fog_b", fog_b)
			dm.set_shader_parameter("fog_e", fog_e)
			dm.set_shader_parameter("relief_k", relief_k)

	# пелена позёмки — по рельефу наста (он есть только с полными эффектами и не в закрытом помещении)
	if _sheet != null:
		var show_sheet := fx and indoor < 0.99 and clear < 0.98
		_sheet.visible = show_sheet
		if show_sheet:
			var sc := Vector3(snappedf(cp.x, SHEET_STEP), 0.0, snappedf(cp.z, SHEET_STEP))
			_sheet.global_position = sc
			_sheet_mat.set_shader_parameter("patch_c", Vector2(sc.x, sc.z))
			_sheet_mat.set_shader_parameter("adv", _adv)
			_sheet_mat.set_shader_parameter("gust", gk)
			_sheet_mat.set_shader_parameter("front_s", _front_s)
			_sheet_mat.set_shader_parameter("relief_k", relief_k)
			_sheet_mat.set_shader_parameter("density", 0.07 * clampf(0.35 + 0.75 * inten, 0.0, 1.3) * out_s * (1.0 - clear * 0.9))

	# объём пурги в объёмном тумане (он включён только с полными эффектами)
	if _fog != null:
		var show_fog := fx and clear < 0.5
		_fog.visible = show_fog
		if show_fog:
			var fk := out_s * (1.0 - clear)
			_fog.global_position = Vector3(cp.x, 5.0, cp.z)
			_fog_mat.set_shader_parameter("cam_pos", cp)
			_fog_mat.set_shader_parameter("adv", _adv)
			_fog_mat.set_shader_parameter("front_s", _front_s)
			_fog_mat.set_shader_parameter("gust", gk)
			_fog_mat.set_shader_parameter("drift_d", 0.05 * clampf(inten, 0.0, 1.2) * fk)
			_fog_mat.set_shader_parameter("wall_d", 0.035 * fk)
			_fog_mat.set_shader_parameter("band_d", 0.012 * fk)


## Слой частиц: коробка вокруг камеры, свой материал движения и рисования.
func _add_layer(cfg: Dictionary, move: Shader, draw_sh: Shader) -> void:
	if not only_layers.is_empty() and not String(cfg.id) in only_layers:
		return
	var half: Vector3 = cfg["half"]
	var margin: float = cfg.get("margin", 3.0)
	var gp := GPUParticles3D.new()
	gp.name = "Snow_" + String(cfg["id"])
	gp.amount = int(cfg["amount"])
	gp.lifetime = 3600.0              # частицы не умирают: живут в коробке и переносятся
	gp.explosiveness = 1.0
	gp.one_shot = false
	gp.preprocess = 0.0
	gp.local_coords = false
	gp.fixed_fps = 0
	gp.interpolate = false
	gp.transform_align = GPUParticles3D.TRANSFORM_ALIGN_DISABLED
	gp.draw_order = GPUParticles3D.DRAW_ORDER_INDEX
	gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mv := Vector3(margin, margin, margin)
	gp.visibility_aabb = AABB(-half - mv, half * 2.0 + mv * 2.0)
	var pm := ShaderMaterial.new()
	pm.shader = move
	pm.set_shader_parameter("noise_tex", _n_lo)
	pm.set_shader_parameter("half_ext", half)
	pm.set_shader_parameter("wd", WD)
	var pp: Dictionary = cfg.get("proc", {})
	for k in pp:
		pm.set_shader_parameter(k, pp[k])
	gp.process_material = pm
	var dm := ShaderMaterial.new()
	dm.shader = draw_sh
	dm.render_priority = int(cfg.get("prio", 0))
	var dp: Dictionary = cfg.get("draw", {})
	for k in dp:
		dm.set_shader_parameter(k, dp[k])
	var qm := QuadMesh.new()
	qm.size = Vector2.ONE
	qm.material = dm
	gp.draw_pass_1 = qm
	add_child(gp)
	cfg["gp"] = gp
	cfg["pm"] = pm
	cfg["dm"] = dm
	_layers.append(cfg)


func _build_sheet(sh: Shader) -> void:
	_sheet_mat = ShaderMaterial.new()
	_sheet_mat.shader = sh
	_sheet_mat.render_priority = -4
	_sheet_mat.set_shader_parameter("n_lo", _n_lo)
	_sheet_mat.set_shader_parameter("n_hi", _n_hi)
	# сторона сетки — ровно целое число шагов: иначе при сдвиге за камерой вершины встают в новые точки
	# рельефа и пелена «плывёт» на каждом шаге
	var nseg := int(round(SHEET_R * 2.0 / SHEET_STEP))
	var side := float(nseg) * SHEET_STEP
	_sheet_mat.set_shader_parameter("patch_r", side * 0.5)
	# под косым взглядом наст освещён слабо, а взвесь светит вся — струи видны впереди в луче
	_sheet_mat.set_shader_parameter("lit", 0.6)
	var pm := PlaneMesh.new()
	pm.size = Vector2(side, side)
	pm.subdivide_width = nseg - 1
	pm.subdivide_depth = nseg - 1
	_sheet = MeshInstance3D.new()
	_sheet.name = "SnowSheet"
	_sheet.mesh = pm
	_sheet.material_override = _sheet_mat
	_sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sheet.extra_cull_margin = 1.0
	add_child(_sheet)


func _build_fog(sh: Shader) -> void:
	_fog_mat = ShaderMaterial.new()
	_fog_mat.shader = sh
	_fog_mat.set_shader_parameter("n_lo", _n_lo)
	_fog_mat.set_shader_parameter("n_hi", _n_hi)
	_fog_mat.set_shader_parameter("wd", WD)
	_fog_mat.set_shader_parameter("half_w", FOG_HALF)
	_fog = FogVolume.new()
	_fog.name = "SnowFog"
	_fog.size = Vector3(FOG_HALF * 2.0, 16.0, FOG_HALF * 2.0)
	_fog.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	_fog.material = _fog_mat
	add_child(_fog)


func _all_mats() -> Array:
	var r: Array = []
	for L in _layers:
		var cfg: Dictionary = L
		r.append(cfg["pm"])
		r.append(cfg["dm"])
	if _sheet_mat != null:
		r.append(_sheet_mat)
	if _fog_mat != null:
		r.append(_fog_mat)
	return r


## Бесшовный шум 256×256 без сжатия: сжатая текстура на пороговых узорах даёт «ступеньки» блоков.
func _noise_tex(cycles: float, octaves: int, seed_v: int) -> Texture2D:
	var fn := FastNoiseLite.new()
	fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fn.seed = seed_v
	fn.frequency = cycles / 256.0
	fn.fractal_type = FastNoiseLite.FRACTAL_FBM
	fn.fractal_octaves = octaves
	fn.fractal_lacunarity = 2.0
	fn.fractal_gain = 0.5
	var img: Image = fn.get_seamless_image(256, 256, false, false, 0.1, true)
	if img == null or img.is_empty():
		return Kit.tex("res://tex/noise")
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
