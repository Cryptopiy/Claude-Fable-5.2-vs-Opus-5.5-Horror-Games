extends Node
## «Золотой набор»: снимает кадры из golden_points.gd одним запуском (мир пересоздаётся на каждой контрольной точке).
##   tools/dev.sh shot --golden [--golden=12_m,pool] [--out=shots/golden] [--quality=0|1|2]
## Рядом с кадрами пишет stats.txt: время кадра на GPU (мс), draw calls, примитивы, объекты — для сверки бюджета.
## Окно ограничено 30 кадрами/с (видеокарта не греется), запуск ждёт свободный GPU (tools/dev.sh gpu_guard).
## Триггеры сценария на время съёмки выключены (как при прогреве шейдеров), Хозяйка — только в кадрах с "hoz".

var main: Node
var out_dir := "res://shots/golden"
var only: PackedStringArray = []
var stats: Array[String] = []
var audit := false   # --audit: каждое помещение с 6 сторон при полном свете (поиск багов текстур), без физики игрока


func _ready() -> void:
	main = get_parent()
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--golden="):
			only = s.substr(9).split(",", false)
		elif s.begins_with("--out="):
			out_dir = "res://" + s.substr(6).trim_prefix("res://")
		elif s == "--audit":
			audit = true
			out_dir = "res://shots/audit"
		elif s.begins_with("--quality="):
			Settings.quality = int(s.substr(10))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	# видеокарту не гоняем: окно рендерит не чаще 30 кадров/с, а в stats.txt пишется время кадра на GPU (мс) —
	# оно не зависит от ограничения кадров и честнее, чем fps без vsync
	Engine.max_fps = 30
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_run.call_deferred()


func _wanted(name: String) -> bool:
	if only.is_empty():
		return true
	for o in only:
		if name.contains(o):
			return true
	return false


func _run() -> void:
	var pts: Array = _audit_points() if audit else load("res://tools/dev/golden_points.gd").POINTS
	var cur_cp := ""
	for p: Dictionary in pts:
		var name: String = p["name"]
		if not _wanted(name):
			continue
		var cp: String = p["cp"]
		if cp != cur_cp or p.has("hoz") or p.has("steam") or p.has("ui") or p.has("event"):
			await _load_cp(cp)
			cur_cp = cp if not (p.has("hoz") or p.has("steam") or p.has("ui") or p.has("event")) else ""
		await _shot(p)
	var f := FileAccess.open(out_dir + "/stats.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(stats) + "\n")
	print("golden: готово, кадров ", stats.size())
	get_tree().quit()


func _load_cp(cp: String) -> void:
	main.started = false
	main.start_checkpoint(cp, true)
	while main.world == null or not main.started:
		await get_tree().process_frame
	# сценарий молчит, Хозяйки нет, пока её не позовут
	main.prewarming = true
	Game.cheats["no_monster"] = true
	Game.cheats["god"] = true
	if audit:
		Game.cheats["fullbright"] = true
		main.world._apply_quality()
		main.world.player.set_noclip(true)
		for pn in main.world.player.cam.find_children("*", "GPUParticles3D", true, false):
			(pn as GPUParticles3D).visible = false
	await get_tree().create_timer(1.4).timeout


func _shot(p: Dictionary) -> void:
	var w: World = main.world
	var pl: Player = w.player
	if DisplayServer.window_get_size().x < 1000:
		DisplayServer.window_set_size(Vector2i(1280, 720))
	pl.input_lock = true
	pl.global_position = p["pos"]
	pl.velocity = Vector3.ZERO
	var look: Array = p["look"]
	pl.set_look(deg_to_rad(float(look[0])), deg_to_rad(float(look[1])))
	pl.battery = 100.0
	pl.toggle_light(1 if bool(p.get("light", false)) else 0)
	pl.fear = 0.0
	var steam: Dictionary = p.get("steam", {})
	for room in steam:
		w.steam[room] = float(steam[room])
	if p.has("event") and w.scenario.has_method(String(p["event"])):
		w.scenario.call(String(p["event"]))
	if p.has("hoz"):
		Game.cheats["no_monster"] = false
		var hoz: Hozyayka = w.monster
		hoz.emerge(p["hoz"], pl.global_position, true)
		hoz.set_state(Hozyayka.S.SEARCH)
		hoz.search_t = 99.0
	# кадры физики: камера, тени, объёмный туман (временное накопление)
	for i in 4:
		await get_tree().physics_frame
	await get_tree().create_timer(0.9).timeout
	match String(p.get("ui", "")):
		"phone":
			main.open_phone()
		"note":
			main.show_note("last_entry")
		"pause":
			main.open_pause()
		"code":
			main.open_code(w.doors["d_code_m"])
	if p.has("ui"):
		await get_tree().create_timer(0.8).timeout
	# без надписей админ-режима, задач и мыслей — только картинка. Таймеры обнулять мало: сообщение сценария
	# может прийти в окне замера и снова зажечь «✉ Сообщение» — сами надписи прячем до снятия кадра
	var hud: Hud = main.hud
	for k in ["toast_t", "obj_t", "hint_t", "thought_t", "notif_t", "bat_t"]:
		hud.set(k, 0.0)
	var labels: Array[CanvasItem] = [hud.toast_l, hud.objective, hud.hint, hud.thought, hud.notif, hud.battery_l]
	for l in labels:
		l.visible = false
	await get_tree().process_frame
	# цифры кадра
	var gpu_ms := 0.0
	var cpu_ms := 0.0
	var vp := get_viewport().get_viewport_rid()
	for i in 6:
		await get_tree().process_frame
		gpu_ms += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		cpu_ms += RenderingServer.viewport_get_measured_render_time_cpu(vp)
	var draw := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var prims := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	var objs := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
	var img := get_viewport().get_texture().get_image()
	for i in 4:
		if img.get_width() >= 1000:
			break
		DisplayServer.window_set_size(Vector2i(1280, 720))
		await get_tree().create_timer(0.6).timeout
		img = get_viewport().get_texture().get_image()
	if img.get_width() > 1280:
		img.resize(1280, int(img.get_height() * 1280.0 / img.get_width()), Image.INTERPOLATE_LANCZOS)
	img.save_png("%s/%s.png" % [out_dir, p["name"]])
	for l in labels:
		l.visible = true
	var line := "%-20s gpu %5.2f ms  draw %5d  prims %8d  objs %5d  cpu %5.2f ms" % [p["name"], gpu_ms / 6.0, draw, prims, objs, cpu_ms / 6.0]
	stats.append(line)
	print("golden ", line)
	# убрать интерфейс и Хозяйку
	if main.phone:
		main.phone.queue_free()
		main.phone = null
	main._close_overlay()
	get_tree().paused = false
	if p.has("hoz"):
		(w.monster as Hozyayka).vanish()
		Game.cheats["no_monster"] = true


## Точки аудита: из каждого помещения — 4 стены (камера отведена к противоположной стене), пол и потолок; двор.
func _audit_points() -> Array:
	var out := []
	for id in Layout.ROOMS:
		var d: Dictionary = Layout.ROOMS[id]
		var r: Array = d["r"]
		var rect := Rect2(r[0], r[1], r[2] - r[0], r[3] - r[1])
		var y := float(d["y"])
		var h := float(d["h"])
		var cp := "c11_boiler" if y < -1.0 else "c07_women"
		var c := rect.get_center()
		var eye_y := y + clampf(h * 0.5 - 1.62, -0.6, 0.6) + 0.05
		for k in 4:
			var yaw := k * 90.0
			var dir := Vector2(-sin(deg_to_rad(yaw)), -cos(deg_to_rad(yaw)))
			var half := (rect.size.x if k % 2 == 1 else rect.size.y) * 0.5
			var p := c - dir * half * 0.6
			# угольный бункер: куча угля занимает всё севернее z ≈ −11.9 — камеры на полосе у южной стены,
			# иначе w2 внутри кучи, а w1/w3 вровень с её верхом
			if id == "coal":
				if k == 2:
					out.append({"name": "coal_w2", "cp": cp, "pos": Vector3(35.0, y + 2.3, -16.2), "look": [180.0, -22.0], "light": true})
					continue
				p.y = maxf(p.y, -12.6)
			out.append({"name": "%s_w%d" % [id, k], "cp": cp, "pos": Vector3(p.x, _eye_y(d, rect, p.y, eye_y), p.y), "look": [yaw, -8.0], "light": true})
		if id == "coal":
			c.y = maxf(c.y, -12.6)
		out.append({"name": "%s_floor" % id, "cp": cp, "pos": Vector3(c.x, _eye_y(d, rect, c.y, eye_y), c.y), "look": [30.0, -62.0], "light": true})
		out.append({"name": "%s_ceil" % id, "cp": cp, "pos": Vector3(c.x, _eye_y(d, rect, c.y, eye_y), c.y), "look": [-30.0, 60.0], "light": true})
	var yard := [[Vector3(26, 0.05, 44), 0.0, 6.0], [Vector3(26, 0.05, 44), 90.0, 0.0], [Vector3(26, 0.05, 44), -90.0, 0.0],
		[Vector3(26, 0.05, 44), 180.0, 0.0], [Vector3(-5, 0.05, 36), -14.0, 10.0], [Vector3(57, 0.05, 36), 14.0, 10.0],
		[Vector3(19, 0.05, 32.2), 0.0, 8.0], [Vector3(31, 0.05, 39), -70.0, -5.0], [Vector3(26, 0.05, 33), 0.0, 25.0]]
	for i in yard.size():
		var yd: Array = yard[i]
		out.append({"name": "yard_%d" % i, "cp": "c01_yard", "pos": yd[0], "look": [yd[1], yd[2]], "light": false})
	return out


## Высота ног для точки аудита: на лестнице — от ступени под точкой z (как в builder._stairs_room: верхняя
## площадка 0.6 м, нижняя 1.2 м, 18 ступеней по 0.25), иначе от пола помещения. Раньше на лестнице камера
## стояла от нижнего пола и оказывалась внутри ступеней.
func _eye_y(d: Dictionary, rect: Rect2, z: float, room_eye: float) -> float:
	if not d.get("stairs", false):
		return room_eye
	var top_z := rect.end.y - 0.6
	var bot_z := rect.position.y + 1.2
	var fy := Layout.BASE_Y
	if z >= top_z:
		fy = 0.0
	elif z > bot_z:
		var run := (top_z - bot_z) / 18.0
		fy = maxf(Layout.BASE_Y, -0.25 * (floorf((top_z - z) / run) + 1.0))
	return fy + 0.05
