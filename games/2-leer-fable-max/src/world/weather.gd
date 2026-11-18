class_name Weather
extends Node3D
## Пурга: туман, снежные частицы вокруг камеры, порывы ветра, звук ветра.
## Ветер всегда дует с северо-запада на юго-восток — по нему можно ориентироваться.

signal gust_started(strength: float)
signal gust_ended

const WIND_DIR := Vector3(0.7071, 0.0, 0.7071)     # куда дует: +X восток, +Z юг

var env: Environment
var snow: Node3D = null        # метель (snow.gd): частицы, завесы, позёмка
var _hide: Array = []
var base := 0.55          # сила пурги 0..1 — задаёт режиссёр
var gust := 0.0           # текущий порыв 0..1
var auto_gusts := true
var gust_min := 18.0
var gust_max := 38.0
var clear := 0.0          # админ: убрать пургу 0..1
var bright := 0.0         # админ: полный свет 0..1
var indoor := 0.0         # 0 — на улице, 1 — в помещении
var vis := 14.0           # текущая дальность видимости, м
var lamp_on := false
var fire_light := 0.0     # фальшфейер/костры подсвечивают туман красным 0..1
var cam: Node3D = null

var _t_next := 12.0
var _g_phase := 0         # 0 нет, 1 нарастает, 2 держится, 3 спадает
var _g_time := 0.0
var _g_hold := 4.0
var _g_peak := 0.8
var _vis_s := 14.0
var _fog_col := Color(0.012, 0.015, 0.02)


func _ready() -> void:
	_build_env()
	_build_snow()
	_t_next = randf_range(8.0, 16.0)
	if Snd.streams.has("wind_low"):
		Snd.loop("wind_low", "wind_low", 0.0, 2.0, "Wind")
		Snd.loop("wind_howl", "wind_howl", 0.0, 2.0, "Wind")
		Snd.loop("wind_whistle", "wind_whistle", 0.0, 2.0, "Wind")
		Snd.loop("snow_hiss", "snow_hiss", 0.0, 2.0, "Wind")


func _exit_tree() -> void:
	for id in ["wind_low", "wind_howl", "wind_whistle", "snow_hiss"]:
		Snd.stop_loop(id, 0.6)
	RenderingServer.global_shader_parameter_set("g_gust", 0.0)
	RenderingServer.global_shader_parameter_set("g_clear", 0.0)


func _build_env() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.0, 0.0, 0.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.42, 0.6)
	env.ambient_light_energy = 0.11
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = _fog_col
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.0
	env.fog_density = 1.0
	env.fog_sky_affect = 1.0
	env.fog_depth_curve = 0.75
	env.fog_depth_begin = 1.0
	env.fog_depth_end = 14.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.9
	env.adjustment_contrast = 1.06
	# объёмный туман: снег в воздухе светится только там, где есть свет — луч фонаря, огни окон, маяк.
	# Рассеянный «небесный» свет туман не подхватывает (ambient_inject 0) — вне луча чернота.
	env.volumetric_fog_density = 0.03
	env.volumetric_fog_albedo = Color(0.88, 0.91, 0.96)
	env.volumetric_fog_emission_energy = 0.0
	env.volumetric_fog_anisotropy = 0.72
	env.volumetric_fog_length = 26.0
	env.volumetric_fog_detail_spread = 2.0
	env.volumetric_fog_ambient_inject = 0.0
	env.volumetric_fog_gi_inject = 0.0
	# и на фон тоже: иначе на горизонте жёсткая граница «освещённый туман над землёй / чёрное небо»
	env.volumetric_fog_sky_affect = 1.0
	env.volumetric_fog_temporal_reprojection_enabled = true
	env.volumetric_fog_temporal_reprojection_amount = 0.85
	env.volumetric_fog_enabled = Cfg.fx
	# мягкая тень в углах и под мебелью
	env.ssao_enabled = Cfg.fx
	env.ssao_radius = 0.9
	env.ssao_intensity = 1.6
	env.ssao_power = 1.3
	env.ssao_detail = 0.4
	env.ssao_light_affect = 0.15
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


## Коробки, внутри которых снег не рисуется (помещения). Задаёт мир после постройки; передаём метели.
func set_hide_boxes(boxes: Array) -> void:
	var mn := PackedVector3Array()
	var mx := PackedVector3Array()
	for bx in boxes:
		var bb: AABB = bx
		if mn.size() >= 12:
			break
		mn.append(bb.position)
		mx.append(bb.end)
	var n := mn.size()
	while mn.size() < 12:
		mn.append(Vector3.ZERO)
		mx.append(Vector3.ZERO)
	_hide = [mn, mx, n]
	if snow != null:
		snow.set_hide_boxes(mn, mx, n)


## Метель — сменный модуль: src/world/snow.gd. Для сравнения вариантов: положить src/world/snow_v<N>.gd с тем же договором
## (setup / set_hide_boxes / tick) и запускать с --snow=N (так выбиралась нынешняя метель).
func _build_snow() -> void:
	var path := "res://src/world/snow.gd"
	if Cfg.has_arg("snow"):
		var alt := "res://src/world/snow_v%s.gd" % Cfg.arg("snow")
		if ResourceLoader.exists(alt):
			path = alt
	snow = Node3D.new()
	snow.name = "Snow"
	snow.set_script(load(path))
	add_child(snow)
	snow.setup(self)
	if not _hide.is_empty():
		snow.set_hide_boxes(_hide[0], _hide[1], _hide[2])


## Запустить порыв вручную (сценарий): сила 0..1, сколько держится.
func force_gust(strength := 0.9, hold := 5.0) -> void:
	_g_phase = 1
	_g_time = 0.0
	_g_peak = strength
	_g_hold = hold
	gust_started.emit(strength)


## Порыв уже идёт (нарастает, держится или спадает).
func gusting() -> bool:
	return _g_phase != 0


func in_gust() -> bool:
	return gust > 0.45


## Сила ветра для игрока и существа 0..1.3
func intensity() -> float:
	return clampf(base + gust * 0.55, 0.0, 1.3)


func _process(dt: float) -> void:
	# расписание порывов
	if _g_phase == 0:
		if auto_gusts and base > 0.2:
			_t_next -= dt
			if _t_next <= 0.0:
				force_gust(randf_range(0.7, 1.0), randf_range(3.0, 6.5))
	elif _g_phase == 1:
		_g_time += dt
		gust = minf(_g_peak, gust + dt * 0.75)
		if gust >= _g_peak - 0.001:
			_g_phase = 2
			_g_time = 0.0
	elif _g_phase == 2:
		_g_time += dt
		gust = _g_peak * (0.9 + 0.1 * sin(_g_time * 5.0))
		if _g_time >= _g_hold:
			_g_phase = 3
	else:
		gust = maxf(0.0, gust - dt * 0.42)
		if gust <= 0.0:
			_g_phase = 0
			_t_next = randf_range(gust_min, gust_max)
			gust_ended.emit()

	var I := intensity()
	var out := 1.0 - indoor
	# видимость
	var target := lerpf(26.0, 10.0, clampf(base, 0.0, 1.0)) * lerpf(1.0, 0.3, gust)
	target = lerpf(target, 260.0, clear)
	_vis_s = lerpf(_vis_s, target, clampf(dt * 2.2, 0.0, 1.0))
	vis = _vis_s
	env.fog_depth_end = lerpf(vis, 60.0, indoor * (1.0 - clear))
	env.fog_depth_begin = lerpf(vis * 0.08, 8.0, indoor)
	# цвет тумана: чёрно-синий; фонарь даёт молочную засветку, огонь — красную
	var c := _fog_col
	if lamp_on:
		c = c.lerp(Color(0.05, 0.056, 0.066), 0.55 + 0.45 * I)
	c = c.lerp(Color(0.16, 0.035, 0.02), clampf(fire_light, 0.0, 1.0) * 0.8)
	c = c.lerp(Color(0.02, 0.03, 0.05), clear)
	c = c.lerp(Color(0.0, 0.0, 0.0), indoor)
	env.fog_light_color = env.fog_light_color.lerp(c, clampf(dt * 5.0, 0.0, 1.0))
	# в помещении рассеянного «неба» меньше — углы темнее (под фонарём и лампой видно как раньше)
	env.ambient_light_energy = (lerpf(0.11, 0.9, bright) + clear * 0.08) * lerpf(1.0, 0.6, indoor * (1.0 - bright))
	env.ambient_light_color = Color(0.32, 0.42, 0.6).lerp(Color(1, 1, 1), bright)
	# плотность объёмного тумана: пурга гуще в порыв; в помещении — только пыль в воздухе
	env.volumetric_fog_enabled = Cfg.fx and clear < 0.5
	env.ssao_enabled = Cfg.fx
	var vd := lerpf(0.012, 0.034, clampf(base, 0.0, 1.0)) * lerpf(1.0, 1.9, gust)
	env.volumetric_fog_density = lerpf(vd, 0.008, indoor) * (1.0 - clear)

	# метель едет за камерой
	if snow != null and cam != null and is_instance_valid(cam):
		snow.tick(self, cam.global_position, dt)

	RenderingServer.global_shader_parameter_set("g_wind", Vector4(WIND_DIR.x, WIND_DIR.z, clampf(base, 0.0, 1.0), 0.0))
	RenderingServer.global_shader_parameter_set("g_gust", gust)
	RenderingServer.global_shader_parameter_set("g_clear", clear)

	# звук: низ постоянно, вой и свист — с порывом
	var q := 1.0 - clear * 0.85
	Snd.loop_vol("wind_low", clampf(0.35 + base * 0.5 + gust * 0.25, 0.0, 1.0) * q, 0.4)
	Snd.loop_vol("wind_howl", clampf(base * 0.45 + gust * 0.75, 0.0, 1.0) * q, 0.4)
	Snd.loop_vol("wind_whistle", clampf((base - 0.3) * 0.4 + gust * 0.6, 0.0, 1.0) * q, 0.4)
	Snd.loop_vol("snow_hiss", clampf(0.2 + I * 0.5, 0.0, 1.0) * out * q, 0.3)
