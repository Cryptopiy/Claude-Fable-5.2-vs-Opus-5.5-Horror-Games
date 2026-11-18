extends SceneTree
## Проверки механик, которых бот не делает. Запуск (из папки проекта):
##   godot --headless --path . --script tools/dev/mech.gd -- --test --nocold --god --nogust
## Печатает MECH OK/FAIL <случай>; в конце MECH ALL OK или MECH FAIL n.

var g: Node
var t := 0.0
var started := false
var fails := 0


func _initialize() -> void:
	change_scene_to_file("res://src/main.tscn")


func _process(dt: float) -> bool:
	t += dt
	if started:
		return false
	if g == null:
		g = root.get_node_or_null("G")
		return false
	if t < 1.5:
		return false
	started = true
	_run.call_deferred()
	return false


func _check(name: String, ok: bool, info := "") -> void:
	if not ok:
		fails += 1
	print("MECH %s %s %s" % ["OK" if ok else "FAIL", name, info])


func _wait(sec: float) -> void:
	var end := Time.get_ticks_msec() + int(sec * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame


func _run() -> void:
	# 1. Канистру унесли в ночь 1 — в ночь 2 она снова в дизельной, а «взял канистру» не переносится
	g.call("start_stage", "n1_radio")
	await _wait(2.5)
	var d = g.get("director")
	var w = g.get("world")
	var p = g.get("player")
	d.act("jerry")
	_check("jerry_taken_n1", p.carrying == "jerry")
	d.go("n2_wake")
	await _wait(1.0)
	_check("jerry_back_n2", w.things["jerry"].visible and w.things["jerry_it"].enabled and p.carrying == "",
		"visible=%s enabled=%s carrying=%s" % [w.things["jerry"].visible, w.things["jerry_it"].enabled, p.carrying])
	_check("acted_cleared_n2", not d.acted.has("jerry_taken"))

	# 2. Ледник с контрольной точки: люк открывается
	g.call("start_stage", "n4_cellar")
	await _wait(2.5)
	d = g.get("director")
	_check("cellar_hatch_allowed", bool(d.allow.get("hatch", false)))

	# 3. Наблюдающая фигура вплотную просит порыв один раз
	g.call("start_stage", "n1_radio")
	await _wait(2.5)
	w = g.get("world")
	p = g.get("player")
	var e = g.get("entity")
	g.set("ai_off", false)
	var n := [0]
	w.weather.gust_started.connect(func(_s: float) -> void: n[0] += 1)
	w.weather.auto_gusts = false
	e.watch_at(p.global_position + Vector3(2.0, 0, 0), 0.0)
	await _wait(1.2)
	_check("watch_gust_once", n[0] <= 1, "порывов: %d" % n[0])

	# 4. Карточка смерти, брошенная выходом в меню, не держит мышь видимой
	var cards = g.get("cards")
	cards.death("ТЕСТ", "тест", false)
	await _wait(0.2)
	g.call("show_menu", "main")
	await _wait(0.6)
	_check("cards_mouse_reset", cards.mouse_filter == Control.MOUSE_FILTER_IGNORE)

	print("MECH ALL OK" if fails == 0 else "MECH FAIL %d" % fails)
	quit(0 if fails == 0 else 1)
