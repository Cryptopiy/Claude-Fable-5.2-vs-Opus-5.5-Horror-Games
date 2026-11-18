extends Node
## Регрессия механик (без окна):  godot --headless --path . -- --qatest
## Каждая проверка — баг, найденный и исправленный при полировке (docs/POLISH_AUDIT.md):
##  1) пауза и записка замораживают мир (Хозяйка не двигается, игрок жив); пауза в кат-сцене не отпускает ввод;
##  2) все укрытия: из точки выхода можно уйти, выход в том же помещении, в шкафчике взгляд — в щели дверцы,
##     под полок можно залезть (луч взгляда попадает в зону укрытия);
##  3) удержание E на том, что пока нельзя (нет ключа), не плодит петли звука;
##  4) E, закрывшее записку, не открывает её снова;
##  5) приглушённый звук из укрытия не переживает перезагрузку точки;
##  6) после перезагрузки c08 вестибюль затоплен, после c09 с недоспущенной водой слив доходит до дна;
##  7) админ-режим и проверки не пишут сохранение игрока;
##  8) движение мыши в центре экрана доходит до игрока (интерфейс его не съедает), взгляд не заблокирован;
##  9) каждая контрольная точка грузится и перезагружается (игрок на полу), меню → новая игра дважды,
##     подсказка управления и задача видны после загрузки;
## 10) музыка зациклена;
## 11) кодовый замок переживает потерю фокуса; засов бассейна держит игрока, а Хозяйку пропускает и закрывается за ней.

var fails := 0
var m: Node


func _ready() -> void:
	m = Game.main
	_run()


func log_(t: String) -> void:
	print("[QA] ", t)


func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(ok: bool, what: String) -> void:
	if ok:
		log_("  ок: " + what)
	else:
		fails += 1
		log_("  ОШИБКА: " + what)


func _load(cp: String, extra := {}) -> World:
	m.start_checkpoint(cp, true)
	for k in extra:
		Game.flags[k] = extra[k]
	if not extra.is_empty():
		Game.snapshot = Game.make_snapshot()
		m.reload_checkpoint()
	while m.world == null or not m.started:
		await get_tree().process_frame
	await wait(0.3)
	Game.set_flag("dir_hold")
	return m.world


func _run() -> void:
	var save_path := ProjectSettings.globalize_path(Game.SAVE_PATH)
	var save_before := FileAccess.get_modified_time(save_path) if FileAccess.file_exists(save_path) else 0
	var save_text := FileAccess.get_file_as_string(save_path) if FileAccess.file_exists(save_path) else ""
	if "--qa-mouse" in OS.get_cmdline_user_args():
		# только проверка мыши (её имеет смысл гонять и с окном: tools/dev.sh shot --qatest --qa-mouse)
		await _t_mouse()
		log_("ИТОГ: ошибок %d" % fails)
		get_tree().quit(1 if fails > 0 else 0)
		return
	await _t_pause()
	await _t_hides()
	await _t_hold_sound()
	await _t_note_reopen()
	await _t_muffle()
	await _t_restore()
	await _t_mouse()
	await _t_checkpoints()
	await _t_code_and_bolt()
	# 7. сохранение игрока не тронуто
	log_("7. админ-режим и проверки не пишут сохранение")
	var save_after := FileAccess.get_modified_time(save_path) if FileAccess.file_exists(save_path) else 0
	var text_after := FileAccess.get_file_as_string(save_path) if FileAccess.file_exists(save_path) else ""
	_check(save_after == save_before and text_after == save_text, "save.json не менялся")
	log_("ИТОГ: ошибок %d" % fails)
	get_tree().quit(1 if fails > 0 else 0)


# ---------------------------------------------------------------- 1. пауза
func _t_pause() -> void:
	log_("1. пауза и записка замораживают мир")
	var w := await _load("c11_boiler")
	var pl := w.player
	var hoz: Hozyayka = w.monster
	pl.global_position = Vector3(25.25, -4.32, -8.5)
	hoz.emerge(Vector3(23.5, -4.5, -14.0), pl.global_position, true)
	hoz.no_kill = true
	await wait(0.5)
	hoz.set_state(Hozyayka.S.ROAM)
	w.noise(pl.global_position, 30.0, "step")
	await wait(0.6)
	for kind in ["pause", "note"]:
		if kind == "pause":
			m.open_pause()
		else:
			m.show_note("last_entry")
		await frames(2)
		var p0 := hoz.global_position
		await wait(1.5)
		_check(hoz.global_position.distance_to(p0) < 0.02 and not pl.dead, "%s: Хозяйка стоит (сдвиг %.2f м), игрок жив" % [kind, hoz.global_position.distance_to(p0)])
		m._close_overlay()
		await frames(2)
	_check(not get_tree().paused and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or DisplayServer.get_name() == "headless", "после закрытия пауза снята")
	# пауза посреди кат-сцены не снимает блокировку ввода
	pl.scene_lock = true
	pl.input_lock = true
	m.open_pause()
	await frames(2)
	m._close_overlay()
	await frames(2)
	_check(pl.input_lock, "закрытие паузы во время кат-сцены не отпускает ввод")
	pl.scene_lock = false
	pl.input_lock = false
	hoz.no_kill = false
	hoz.vanish()


# ---------------------------------------------------------------- 2. укрытия
func _t_hides() -> void:
	log_("2. укрытия: вход, взгляд, выход")
	var w := await _load("c07_women")
	Game.cheats["no_monster"] = true
	var pl := w.player
	for h: HideSpot in w.hides:
		var room := w.room_at(h.global_position + Vector3.UP * 0.5)
		var name := "%s/%s" % [h.kind, room]
		# луч взгляда находит укрытие: встать перед ним и посмотреть
		var front := h.global_position + h.global_transform.basis * (Vector3(0, 0, -1.3) if h.kind == "locker" else Vector3(0, 0, 1.4))
		front.y = h.global_position.y + 0.05
		pl.global_position = front
		pl.velocity = Vector3.ZERO
		var to := h.global_position + Vector3.UP * (1.0 if h.kind == "locker" else 0.2) - (front + Vector3.UP * 1.62)
		pl.set_look(Props.yaw_to(Vector3(to.x, 0, to.z)), atan2(to.y, Vector2(to.x, to.z).length()))
		pl.yaw = pl.rotation.y
		pl.pitch = pl.head.rotation.x
		await frames(3)
		_check(pl._focus == h, name + ": видно и можно использовать")
		if pl._focus != h:
			var hit: Object = pl.ray.get_collider()
			log_("    луч упирается в: %s (%s) в %s, укрытие в %s" % [hit, (hit as Node).get_parent().name if hit is Node else "-", pl.ray.get_collision_point(), h.global_position])
		h.use(pl)
		await wait(0.5)
		_check(pl.hidden_in == h, name + ": спрятался")
		var look := pl.look_dir()
		var out_dir := -h.global_transform.basis.z if h.kind == "locker" else h.global_transform.basis.z
		_check(Vector2(look.x, look.z).normalized().dot(Vector2(out_dir.x, out_dir.z).normalized()) > 0.9, name + ": смотрит наружу")
		h.use(pl)
		await wait(0.6)
		_check(pl.hidden_in == null and not h.inside, name + ": вылез")
		_check(w.room_at(pl.global_position + Vector3.UP * 0.5) == room, name + ": вылез в том же помещении")
		var free_dirs := 0
		for d in [Vector3(0.5, 0, 0), Vector3(-0.5, 0, 0), Vector3(0, 0, 0.5), Vector3(0, 0, -0.5)]:
			if not pl.test_move(pl.global_transform, d):
				free_dirs += 1
		_check(free_dirs >= 2, name + ": не застрял (свободно направлений: %d)" % free_dirs)
	# двойное нажатие на шкафчик не рассинхронизирует его
	var lk: HideSpot = null
	for h: HideSpot in w.hides:
		if h.kind == "locker":
			lk = h
			break
	lk.use(pl)
	lk.use(pl)
	await wait(0.6)
	_check(lk.inside == (pl.hidden_in == lk), "двойное нажатие: состояние шкафчика согласовано")
	if pl.hidden_in:
		lk.use(pl)
		await wait(0.6)
	Game.cheats["no_monster"] = false


# ---------------------------------------------------------------- 3. звук удержания
func _t_hold_sound() -> void:
	log_("3. удержание E без инструмента не плодит звуки")
	var w := await _load("c03_mlock")
	Game.items.erase("wrench")
	var pl := w.player
	pl.global_position = Vector3(1.2, 0.05, 27.6)
	pl.set_look(deg_to_rad(90), deg_to_rad(-20))
	await frames(3)
	_check(pl._focus != null, "вентиль горячей воды под взглядом")
	var before := _count_players(w)
	Input.action_press("use")
	await wait(1.0)
	var during := _count_players(w)
	Input.action_release("use")
	await wait(0.3)
	var after := _count_players(w)
	_check(during - before <= 1 and after <= before, "звуков удержания: до %d, при удержании %d, после %d" % [before, during, after])


func _count_players(w: Node) -> int:
	var n := 0
	for c in w.find_children("*", "AudioStreamPlayer3D", true, false):
		if is_instance_valid(c) and not c.is_queued_for_deletion():
			n += 1
	return n


# ---------------------------------------------------------------- 4. записка не открывается снова
func _t_note_reopen() -> void:
	log_("4. E закрывает записку и не открывает её снова")
	var w := await _load("c11_boiler")
	var pl := w.player
	# детский рисунок на стене комнаты истопника
	pl.global_position = Vector3(11.2, -4.32, -10.0)
	pl.set_look(deg_to_rad(90), deg_to_rad(-5))
	await frames(3)
	var target := pl._focus
	_check(target != null, "рисунок под взглядом")
	if target == null:
		return
	target.use(pl)
	await frames(2)
	_check(m.overlay != null, "записка открыта")
	var ev := InputEventAction.new()
	ev.action = "use"
	ev.pressed = true
	Input.parse_input_event(ev)
	Input.action_press("use")
	await frames(4)
	_check(m.overlay == null, "E закрыло записку и она не открылась снова")
	Input.action_release("use")
	var ev2 := InputEventAction.new()
	ev2.action = "use"
	ev2.pressed = false
	Input.parse_input_event(ev2)
	await frames(2)
	if m.overlay:
		m._close_overlay()


# ---------------------------------------------------------------- 5. глушение звука
func _t_muffle() -> void:
	log_("5. приглушённый звук не переживает перезагрузку")
	var w := await _load("c07_women")
	var pl := w.player
	var lk: HideSpot = null
	for h: HideSpot in w.hides:
		if h.kind == "locker":
			lk = h
			break
	lk.use(pl)
	await wait(0.5)
	_check(float(Snd.get("_muffle_target")) < 5000.0, "в шкафчике звук приглушён")
	m.reload_checkpoint()
	while m.world == null or not m.started:
		await get_tree().process_frame
	_check(float(Snd.get("_muffle_target")) > 15000.0, "после перезагрузки звук обычный")


# ---------------------------------------------------------------- 6. состояние после перезагрузки
func _t_restore() -> void:
	log_("6. затопление и слив восстанавливаются после перезагрузки")
	var w := await _load("c08_pump")
	_check(w.waters.has("lobby_flood"), "c08: вестибюль затоплен")
	w = await _load("c09_drained", {"pool_level": -1.9})
	await wait(3.0)
	_check(w.pool_level <= Layout.POOL_DEEP + 0.02, "c09 с недоспущенной водой: слив дошёл до дна (%.2f)" % w.pool_level)


# ---------------------------------------------------------------- 8. мышь
class _MouseProbe extends Node:
	var got := 0

	func _unhandled_input(e: InputEvent) -> void:
		if e is InputEventMouseMotion:
			got += 1


func _t_mouse() -> void:
	log_("8. движение мыши доходит до игрока (интерфейс не перехватывает его в центре экрана)")
	# как у игрока: не бот (пауза по потере фокуса включена), но сохранение не пишем
	Game.bot = false
	Game.no_save = true
	var w: World
	if "--qa-menu" in OS.get_cmdline_user_args():
		# путь игрока: главное меню → «Новая игра»
		m.show_menu()
		await wait(1.0)
		m.new_game()
		while m.world == null or not m.started:
			await get_tree().process_frame
		w = m.world
	else:
		w = await _load("c01_yard")
	var pl := w.player
	await wait(0.5)
	# окно проверки без фокуса: игра на старте ставит паузу (Alt+Tab под загрузкой) — закрыть, как игрок
	if DisplayServer.get_name() != "headless" and not get_window().has_focus():
		_check(m.overlay != null and get_tree().paused, "окно без фокуса на старте — игра на паузе")
		m._close_overlay()
		await wait(0.2)
	var vp := get_viewport()
	var center := vp.get_visible_rect().size * 0.5
	log_("  окно %s, пауза %s, look_lock %s, input_lock %s, scene_lock %s, mouse_mode %d" % [vp.get_visible_rect().size, get_tree().paused, pl.look_lock, pl.input_lock, pl.scene_lock, Input.mouse_mode])
	var probe := _MouseProbe.new()
	add_child(probe)
	for pos in [center, center + Vector2(37, 23)]:
		probe.got = 0
		var ev := InputEventMouseMotion.new()
		ev.position = pos
		ev.global_position = pos
		ev.relative = Vector2(30, 0)
		ev.screen_relative = Vector2(30, 0)
		vp.push_input(ev)
		var hov := vp.gui_get_hovered_control()
		_check(probe.got > 0, "движение мыши в точке %s доходит до игрока (перехватил: %s)" % [pos, (hov.get_path() if hov else "никто")])
	probe.queue_free()
	_check(not get_tree().paused and not pl.look_lock, "в начале игры взгляд не заблокирован")
	var dot: Control = m.hud.dot
	var dc := dot.get_global_rect().get_center()
	log_("  точка прицела: видна %s, центр %s, центр экрана %s" % [dot.is_visible_in_tree(), dc, center])
	_check(dot.is_visible_in_tree() and dc.distance_to(center) < 3.0, "точка прицела видна и стоит в центре экрана")
	# телефон: после клика по кнопке внутри (у неё фокус) Tab всё равно закрывает телефон
	m.open_phone()
	await wait(0.3)
	var btns: Array = m.phone.find_children("*", "Button", true, false)
	if btns.size() > 0:
		(btns[0] as Button).grab_focus()
	await get_tree().process_frame
	for pressed in [true, false]:
		var tab := InputEventKey.new()
		tab.keycode = KEY_TAB
		tab.physical_keycode = KEY_TAB
		tab.pressed = pressed
		Input.parse_input_event(tab)
		await get_tree().process_frame
	await wait(0.2)
	_check(m.phone == null, "Tab закрывает телефон и после клика по кнопке в нём (кнопок %d)" % btns.size())
	# залипшая блокировка взгляда без экранов поверх снимается сама
	pl.look_lock = true
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not pl.look_lock, "залипший look_lock без экранов поверх снимается сам")
	# весь путь до поворота камеры — только с окном (без окна режим мыши не бывает «захвачен»)
	if DisplayServer.get_name() == "headless":
		log_("  без окна: поворот камеры не проверяется (режим захвата мыши недоступен)")
		return
	for i in 15:
		var y0 := pl.yaw
		var p0 := pl.pitch
		var ev := InputEventMouseMotion.new()
		ev.position = center
		ev.global_position = center
		ev.relative = Vector2(40, 12)
		ev.screen_relative = Vector2(40, 12)
		Input.parse_input_event(ev)
		await get_tree().process_frame
		await get_tree().process_frame
		var turned := absf(pl.yaw - y0) > 0.01 and absf(pl.pitch - p0) > 0.001
		log_("  t=%2d с: mouse_mode %d, пауза %s, look_lock %s, overlay %s, phone %s, yaw %.3f->%.3f" % [i, Input.mouse_mode, get_tree().paused, pl.look_lock, m.overlay != null, m.phone != null, y0, pl.yaw])
		_check(turned, "t=%d с: движение мыши поворачивает камеру" % i)
		await wait(1.0)
	# окно потеряло фокус → пауза → Esc: взгляд снова работает
	m._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	await wait(0.3)
	_check(m.overlay != null and get_tree().paused, "потеря фокуса ставит паузу")
	var esc := InputEventAction.new()
	esc.action = "pause"
	esc.pressed = true
	Input.parse_input_event(esc)
	await wait(0.3)
	var y1 := pl.yaw
	var mv := InputEventMouseMotion.new()
	mv.position = center
	mv.relative = Vector2(40, 0)
	mv.screen_relative = Vector2(40, 0)
	Input.parse_input_event(mv)
	await get_tree().process_frame
	await get_tree().process_frame
	log_("  после Esc: mouse_mode %d, пауза %s, look_lock %s, overlay %s" % [Input.mouse_mode, get_tree().paused, pl.look_lock, m.overlay != null])
	_check(m.overlay == null and absf(pl.yaw - y1) > 0.01, "после Esc из паузы мышь снова поворачивает камеру")


# ---------------------------------------------------------------- 9. все точки
func _t_checkpoints() -> void:
	log_("9. каждая контрольная точка грузится и перезагружается: игрок на полу, в своём помещении")
	for cp in Texts.CHECKPOINTS.keys():
		var w := await _load(String(cp))
		for round in 2:
			if round == 1:
				m.reload_checkpoint()
				while m.world == null or not m.started:
					await get_tree().process_frame
				w = m.world
				Game.set_flag("dir_hold")
			var pl := w.player
			var start := pl.global_position
			await wait(1.5)
			var room: String = w.room_at(pl.global_position + Vector3.UP * 0.5)
			var fell := pl.global_position.y < start.y - 0.6
			_check(not fell and pl.is_on_floor() and room != "" and room != "outside" or String(cp) == "c01_yard",
				"%s%s: стоит на полу (%s, y %.2f→%.2f, комната «%s»)" % [cp, " после перезагрузки" if round == 1 else "", pl.is_on_floor(), start.y, pl.global_position.y, room])
	log_("   меню → новая игра → меню → новая игра")
	for i in 2:
		m.show_menu()
		await wait(0.5)
		m.new_game()
		while m.world == null or not m.started:
			await get_tree().process_frame
		await wait(1.0)
		_check(m.world.player.is_on_floor(), "новая игра %d: игрок на полу во дворе" % (i + 1))
		_check(m.hud.hint.text.begins_with("WASD"), "новая игра %d: на экране подсказка управления («%s»)" % [i + 1, m.hud.hint.text.left(30)])
	await _load("c05_code")
	_check(Game.objective != "" and m.hud.objective.text == "Задача: " + Game.objective, "после загрузки точки задача на экране («%s»)" % m.hud.objective.text.left(40))
	log_("10. музыка зациклена (погоня 15 с не обрывается в тишину)")
	for mus in ["mus_menu", "mus_chase", "mus_tension", "mus_ending"]:
		var st = Snd.stream(mus)
		_check(st != null and bool(st.get("loop")), "%s зациклена" % mus)


# ---------------------------------------------------------------- 11. кодовый замок и засов бассейна
func _t_code_and_bolt() -> void:
	log_("11. кодовый замок переживает Alt+Tab; засов бассейна держит игрока, а её пропускает")
	var was_bot := Game.bot
	Game.bot = false
	Game.no_save = true
	var w := await _load("c05_code")
	var d: Door = w.doors["d_code_m"]
	m.open_code(d)
	await wait(0.2)
	var pad: Control = m.overlay
	m._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	await get_tree().process_frame
	_check(m.overlay == pad and is_instance_valid(pad) and get_tree().paused, "Alt+Tab при открытом замке: замок на месте, мир на паузе")
	m._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	await get_tree().process_frame
	_check(m.overlay == pad and not get_tree().paused, "фокус вернулся: замок на месте, мир идёт")
	m._close_overlay()
	await wait(0.2)
	var pd: Door = w.doors["d_pool_m"]
	_check(pd.locked, "засов: дверь мыльная → бассейн заперта со стороны мыльной")
	pd.last_by_monster = -99.0
	pd.monster_pass(Vector3(8.0, 1.0, 14.5))
	await wait(0.4)
	_check(pd.target > 0.5, "она открывает запертую на засов дверь")
	await wait(3.3)
	_check(pd.target < 0.5 and pd.locked and String(Game.getf("door:d_pool_m", "")) != "open", "за ней дверь закрылась и осталась на засове")
	Game.bot = was_bot
