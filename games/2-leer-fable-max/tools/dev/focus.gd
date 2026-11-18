extends SceneTree
## Проверка: на что «смотрит» игрок (Player._pick_focus) из разных точек — предметы внутри коллизий берутся,
## а сквозь стену снаружи — нет. Запуск (из папки проекта):
##   godot --headless --path . --script tools/dev/focus.gd -- --place=main --test --nocold --god --nogust
## Печатает FOCUS OK/FAIL <случай>: <что под взглядом>; в конце FOCUS ALL OK или FOCUS FAIL n.
## --old: убрать reach_in, как было до правки, — тест должен упасть на кабеле, койке и записке.

var g: Node
var t := 0.0
var started := false


func _initialize() -> void:
	change_scene_to_file("res://src/main.tscn")


func _process(dt: float) -> bool:
	t += dt
	if started:
		return false
	if g == null:
		g = root.get_node_or_null("G")
		return false
	var p = g.get("player")
	if p == null or not is_instance_valid(p) or not p.is_inside_tree() or t < 2.0:
		if t > 60.0:
			print("FOCUS FAIL no player")
			quit(2)
		return false
	started = true
	_run.call_deferred()
	return false


## [имя, позиция ног, точка, куда смотреть, ожидаемая подсказка ("" — ничего / не эта)]
func _cases(w) -> Array:
	var bp: Vector3 = w.things["booth_pos"]
	return [
		["cable_on_rack", Vector3(-3.7, 0.03, 1.72), Vector3(-4.5, 1.05, 1.72), "Взять кабель"],
		["cable_from_side", Vector3(-3.9, 0.03, 0.9), Vector3(-4.45, 1.05, 1.65), "Взять кабель"],
		["bed_top", Vector3(3.3, 0.03, -1.15), Vector3(4.4, 0.75, -1.15), "Лечь спать"],
		["bed_middle", Vector3(3.3, 0.03, -0.6), Vector3(4.3, 0.6, -1.3), "Лечь спать"],
		["note_gr3_in_booth", bp + Vector3(0, 0, 1.0), bp + Vector3(-0.1, 1.34, 0.1), "Прочитать"],
		["thermometer", bp + Vector3(0, 0, 1.0), bp + Vector3(0, 1.75, 0.2), "Снять показания термометра"],
		["bar_through_wall", Vector3(6.0, 0.0, 2.6), Vector3(4.82, 1.05, 2.3), "!Задвинуть засов"],
		["memo_on_wall", Vector3(0.9, 0.03, 0.72), Vector3(1.936, 1.5, 0.72), "Прочитать"],
		["stove", Vector3(-0.4, 0.03, 0.0), Vector3(-1.5, 0.6, 0.0), "Подбросить дров"],
		["radio_desk", Vector3(-3.5, 0.03, -1.6), Vector3(-4.5, 1.0, -1.65), "Сесть за радио"],
	]


func _run() -> void:
	var w = g.get("world")
	var p = g.get("player")
	# записка в будке видна со второй ночи
	var n3 = w.things["note_gr3"]
	n3.enabled = true
	if "--old" in OS.get_cmdline_user_args():
		# как было до правки: без reach_in — кабель, койка (по центру) и записка в будке недоступны
		for k in ["cable_it", "bed", "note_gr3"]:
			w.things[k].reach_in = 0.0
	var fails := 0
	for c in _cases(w):
		var name: String = c[0]
		var at: Vector3 = c[1]
		var look: Vector3 = c[2]
		var want: String = c[3]
		p.teleport(at, 0.0)
		await physics_frame
		await physics_frame
		var eye: Vector3 = p.cam.global_position
		var d: Vector3 = look - eye
		p.yaw = atan2(-d.x, -d.z)
		p.pitch = atan2(d.y, Vector2(d.x, d.z).length())
		p._apply_look()
		await process_frame
		await physics_frame
		var f = p._pick_focus()
		var got := "" if f == null else String(f.prompt)
		var ok := (got != want.substr(1)) if want.begins_with("!") else (got == want)
		if not ok:
			fails += 1
		print("FOCUS %s %s: «%s» (ждали %s)" % ["OK" if ok else "FAIL", name, got, want])
	print("FOCUS ALL OK" if fails == 0 else "FOCUS FAIL %d" % fails)
	quit(0 if fails == 0 else 1)
