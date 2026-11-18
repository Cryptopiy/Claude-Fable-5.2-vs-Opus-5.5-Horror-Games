class_name Scenario
extends Node
## Сюжет: состояние мира по флагам, сюжетные предметы, триггеры, сценарные пугалки, концовки.

const Y := Layout.BASE_Y

var w: World
var triggers := {}
var chain: Node3D
var phone_snd: AudioStreamPlayer3D
var sheet_man: Node3D
var pool_barrier: StaticBody3D
var drain_target := -99.0
var drain_speed := 0.0
var overheat_t := -1.0
var gauge: Node3D
var alarm: AudioStreamPlayer
var encounter := false
var enc_noise := false
var lobby_time := 0.0
var meter_spin := 0.0
var sacrifice_armed := 0.0
var hair_grate: Node3D
var unclog_scare := false
var ghost_mirror: HozBody
var mirror_scare_t := -1.0
var hatch_u: Usable
var exit_warned := false
var behind_try := 0.0
var banya_hint_t := 0.0


func setup(world: World) -> void:
	w = world
	_doors()
	_lines()
	var cp: Array = Texts.CHECKPOINTS.get(Game.checkpoint, Texts.CHECKPOINTS["c01_yard"])
	w.spawn_pos = cp[1]
	w.spawn_yaw = cp[2]
	_prologue_objects()
	_ch1_objects()
	_ch2_objects()
	_ch3_objects()
	_ch4_objects()
	_triggers()
	_restore_state()


## Состояние мира, которое не пересобиралось после перезагрузки точки.
func _restore_state() -> void:
	# затопленный вестибюль (с c08 и дальше выглядел сухим, хотя соль уже смыта)
	if Game.flag("lobby_flooded"):
		_apply_flood()
	# снимок сделан, пока звонил телефон, — после перезагрузки он «звонил» беззвучно
	if Game.flag("phone_ringing") and not Game.flag("phone_answered"):
		Game.set_flag("phone_ringing", false)
	# слив бассейна шёл в момент снимка — продолжить (иначе люк навсегда под водой)
	var lvl := float(Game.getf("pool_level", -0.25))
	if Game.flag("pool_drained") and lvl > Layout.POOL_DEEP - 0.04:
		drain_target = Layout.POOL_DEEP - 0.05
		drain_speed = 0.25
	elif Game.flag("pool_draining") and not Game.flag("pool_clogged") and not Game.flag("pool_drained") and lvl > Layout.POOL_SHALLOW + 0.01:
		drain_target = Layout.POOL_SHALLOW
		drain_speed = 0.03
	# точку c02 можно записать раньше, чем доиграло вступление (m03/r01 приходят на 16-й и 22-й с) —
	# после перезагрузки они пропадали из телефона насовсем: вступление уже не повторяется
	if Game.flag("intro_done") and Game.checkpoint != "c01_yard":
		for m in Texts.CP_STATE["c02_lobby"]["msgs"]:
			if not m in Game.messages:
				Game.messages.append(m)
	# мокрые следы — узлы сцены, в снимок не попадают; без них мысль «Следы босые…» звучала над чистым полом
	# c03 могла записаться раньше, чем через 4 с после звонка появляются следы, — после перезагрузки следы и мысль
	# о них пропадали насовсем
	if Game.flag("footprints"):
		_spawn_footprints()
	elif Game.flag("phone_answered"):
		Game.set_flag("footprints")
		_spawn_footprints()
	# m06 приходит через 25 с после записи c04 — перезагрузка раньше теряла его насовсем
	if Game.flag("first_encounter") and not "m06" in Game.messages and not "m07" in Game.messages:
		msg("m06", 25.0)
	# c03 пишется до того, как в мыльной включаются души и пар, а триггер раздевальни на спавне не срабатывает
	# (прогрев) — после перезагрузки сцена была сухой и включалась разом перед глазами у входа в мыльную
	if Game.checkpoint in ["c03_mlock", "c05_code"] and not Game.flag("first_encounter"):
		Game.set_flag("enc_prepared", false)
		_prepare_encounter()
	# c08 бегом от ключа пишется раньше, чем через ~10 с приходит m07 (или раньше потопа) — старая сцена умерла
	# вместе с миром, и после перезагрузки сообщение (или потоп) пропадали насовсем
	if Game.flag("pump_key") and not Game.flag("lobby_flooded"):
		_flood_lobby()
	elif Game.flag("lobby_flooded") and not "m07" in Game.messages:
		msg("m07", 4.0)
	# то же с поздними сообщениями после звонка (m04 через 7 с), спуска (m09 через 30 с) и задвижки (m10/m11):
	# точка (c03, c10/c11, c12/c13) успевала записаться раньше, и после перезагрузки их уже никто не присылал
	if Game.flag("phone_answered") and not "m04" in Game.messages:
		msg("m04", 7.0)
	if Game.flag("in_basement") and not "m09" in Game.messages:
		msg("m09", 30.0)
	if Game.flag("valve_closed"):
		if not "m10" in Game.messages:
			msg("m10", 6.0)
		if not "m11" in Game.messages:
			msg("m11", 14.0)


func start() -> void:
	if Game.flag("free_walk"):
		for id in w.doors:
			(w.doors[id] as Door).locked = false
		w.player.global_position = Vector3(26.0, 0.05, 28.0)
		w.player.set_look(0.0)
		Game.set_objective("Свободный обход: всё открыто. F1 — панель, F2 — полёт.")
		_ambience()
		return
	_show_obj()
	if Game.checkpoint == "c05_code" and Game.flag("first_encounter") and w.director:
		w.director.water_cool = 40.0
	if Game.checkpoint == "c01_yard" and not Game.flag("intro_done"):
		_intro()
	if Game.checkpoint == "c13_fire":
		_start_overheat(true)
	_ambience()


func obj(id: String) -> void:
	Game.set_flag("obj", id)
	Game.set_objective(Texts.OBJECTIVES[id])


## Текущая задача на экран. «Или сделать, как просил отец…» — только под «Выбраться наружу»: под «закрыть
## задвижку» она читалась как замена задвижке, и огонь без задвижки уводил в «Открытый кран».
func _show_obj() -> void:
	var o := String(Game.getf("obj", ""))
	if o == "":
		return
	var txt := String(Texts.OBJECTIVES.get(o, ""))
	if o == "o_exit" and (Game.flag("obj_fire") or Game.flag("last_entry")):
		txt += "\n" + Texts.OBJECTIVES["o_fire"]
	Game.set_objective(txt)


## Задача только вперёд по порядку Texts.OBJECTIVES: поздний подбор или взгляд в зеркало не откатывает её назад.
func obj_fwd(id: String) -> void:
	var k: Array = Texts.OBJECTIVES.keys()
	if k.find(id) > k.find(String(Game.getf("obj", ""))):
		obj(id)


func msg(id: String, delay := 0.0) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay, false).timeout
	if Game.world != w:
		return
	# повтор (второй спуск в люк, перезагрузка) — без пустого звонка и без шума для неё
	if id in Game.messages:
		return
	Game.add_message(id)
	if not Game.mute_phone:
		Snd.play("phone_ping", -4.0)
		if w.player:
			w.noise(w.player.global_position, 12.0, "phone")


func cp(id: String) -> void:
	var order := Texts.CHECKPOINTS.keys()
	if order.find(id) <= order.find(Game.checkpoint):
		return
	Game.reach_checkpoint(id)
	if Game.main and Game.main.has_method("toast"):
		Game.main.toast("Сохранено")


func wait(t: float) -> void:
	await get_tree().create_timer(t, false).timeout


## Сцену пора бросить: мир пересобран или игрок погиб посреди неё (смерть не ставит паузу — без проверки
## сцена телепортировала/разворачивала мёртвого посреди скримера и писала точку после смерти).
func _cut(pl: Player) -> bool:
	return Game.world != w or not is_instance_valid(pl) or pl.dead or (Game.main != null and bool(Game.main.get("dying")))


## Следующий кадр мира: process_frame приходит и под паузой — сцена, шагающая по кадрам, стоит вместе с миром.
func _frame() -> void:
	await get_tree().process_frame
	while get_tree().paused:
		await get_tree().process_frame


# ---------------------------------------------------------------- двери, водопровод

func _door(id: String) -> Door:
	return w.doors.get(id)


func _doors() -> void:
	# двери котельной в истопницкую, водомерный узел и сруб открываются только внутрь малой комнаты (от котельной):
	# иначе при выходе створка шла над сухими мостками котельной и резала их низом (мостки — тишина, их не трогаем)
	for sid in ["d_stoker", "d_meter", "d_banya"]:
		var sd := _door(sid)
		if sd:
			var boiler_mid := Vector3(24.0, sd.global_position.y + 1.0, -12.0)
			sd.swing_side = -1.0 if sd.to_local(boiler_mid).z > 0.0 else 1.0
	var d := _door("d_entrance")
	d.locked = true
	d.lock_text = "Заперто на цепь с замком."
	if Game.flag("chain_broken"):
		d.locked = false
	if Game.flag("entrance_jammed"):
		d.locked = true
		d.lock_text = "Не открывается. Заклинило — будто держат с той стороны."
	d.on_locked = func():
		if not Game.flag("chain_broken") and Game.has("crowbar"):
			Game.think("Цепь. Монтировкой сорву.", 2.5)
		else:
			Game.think(d.lock_text, 3.0)
	var f := _door("d_lobby_f")
	f.locked = true
	f.lock_text = "Заперто изнутри на засов. В женское отделение отсюда не попасть — только с той стороны."
	f.on_locked = func():
		if w.player.current_room == "f_lock":
			f.locked = false
			Snd.at("unlock", f.global_position + Vector3.UP, 0.0, 0.7)
			Game.think("Засов отодвинул. Теперь отсюда можно выйти в вестибюль.", 3.0)
			f.save_state()
		else:
			Game.think(f.lock_text, 3.0)
	# дверь мыльная → бассейн — засов со стороны бассейна (как у женской раздевальни): иначе сразу после первой
	# встречи можно было обойти чашу по бортику в женское отделение мимо подсобки, кода и технического коридора
	var pd := _door("d_pool_m")
	pd.locked = true
	# засов — для игрока: она ходит через этот проём по навмешу и открывает дверь, как раньше (иначе шла сквозь створку)
	pd.monster_ignores_lock = true
	pd.lock_text = "Двери в бассейн. Засов с той стороны — отсюда не открыть, только из бассейна."
	pd.on_locked = func():
		if w.player.current_room == "pool":
			pd.locked = false
			Snd.at("unlock", pd.global_position + Vector3.UP, 0.0, 0.7)
			Game.think("Засов отодвинул.", 2.0)
			pd.save_state()
		else:
			Game.think(pd.lock_text, 3.0)
	var u := _door("d_m_util")
	u.locked = true
	u.key = "key_util"
	u.lock_text = "Подсобка. Заперто. Ключи от служебных — у заведующей."
	var c := _door("d_code_m")
	c.locked = true
	c.code = "2112"
	c.lock_text = "Кнопочный кодовый замок. «Посторонним вход воспрещён»."
	c.on_open = func(): pass
	# строка над кнопками: без кода игрок не знал, откуда его взять (жалоба автора), с кодом — напоминание
	c.code_hint = func() -> String:
		if Game.flag("code_seen"):
			return "На зеркале в раздевальне было: «21·12 техн.»"
		if "father_note" in Game.notes:
			return "Код отец записал там, где брился. Видно только в пар."
		if Game.has("key_util"):
			return "Кода я не знаю. Может, в отцовской подсобке что-то есть — в раздевальне, за ожидальней."
		if "order" in Game.notes:
			return "Кода я не знаю. Его сменил отец. Ключи от служебных — в кабинете заведующей."
		return "Кода я не знаю. Отец здесь работал — может, у заведующей что-то осталось."
	for pid in ["d_pump_pool", "d_pump_service"]:
		var p := _door(pid)
		p.locked = true
		p.key = "key_pump"
		p.lock_text = "Насосная. Заперто. Ключ, наверное, у банщицы — её комната за женской раздевальней."
	var g := _door("d_grate")
	g.locked = true
	g.lock_text = "Решётка на висячем замке — замок с той стороны. Внизу горит топка."
	g.on_locked = func():
		if w.player.current_room == "b_stairs":
			g.locked = false
			Snd.at("unlock", g.global_position + Vector3.UP, 0.0, 0.8)
			Game.think("Замок изнутри открывается просто. Путь наверх свободен.", 3.0)
			g.save_state()
		else:
			Game.think(g.lock_text, 3.5)
			if not Game.flag("grate_seen"):
				Game.set_flag("grate_seen")
				obj("o_pumpkey")
	# полуоткрытые для атмосферы
	for oid in ["d_m_wash_b", "d_f_wash_a", "d_linen"]:
		var od := _door(oid)
		if Game.flags.get("door:" + oid) == null:
			od.set_open(0.3, true)
	for id in w.doors:
		(w.doors[id] as Door)._restore()


func _lines() -> void:
	for l in ["m_wash", "f_wash"]:
		if Game.flags.get("line:" + l) == null:
			Game.flags["line:" + l] = true


# ---------------------------------------------------------------- пролог

func _intro() -> void:
	Game.set_flag("intro_done")
	if Game.main and Game.main.has_method("fade_in"):
		Game.main.fade_in(3.0)
	Snd.play("van_door", -6.0)
	Game.show_hint("WASD — идти, мышь — смотреть, E — действие, F — фонарь, Tab — телефон, Shift — бежать, Ctrl — пригнуться", 9.0)
	# заявку он получил по дороге (23:24–23:28) — переписка уже в телефоне; раньше она приходила здесь же, после
	# мысли о часах и с более ранним временем, а «Справлюсь» он писал, уже стоя у бани
	for id in ["m01", "m02", "m03", "r01"]:
		Game.add_message(id)
	await wait(2.5)
	if Game.world != w:
		return
	Game.think("23:41. Коммунальная, 12.", 3.0)
	await wait(6.0)
	if Game.world != w:
		return
	if not Game.has("crowbar"):
		obj("o_crowbar")
	await wait(14.0)
	if Game.world != w:
		return
	# быстрый игрок к 22-й секунде уже в вестибюле — мысль про снег у дверей там не к месту
	if not Game.flag("inside"):
		Game.think("Пар из вентиляции… А снег у дверей нетронутый. Ни одного следа.", 5.0)


func _prologue_objects() -> void:
	var ext: Node3D = w.get_node("yard")
	# монтировка и телефонограмма — на снегу у задних дверей фургона. Фургон глухой (props_base.gd:
	# van(…, Vector3(32, 0, 41.5), 0.25), задний торец на локальном z +2.2): раньше монтировка висела стоймя
	# в воздухе у заднего угла, а бумага — в полуметре над снегом. Точки — в осях фургона, зоны «взять» не
	# заходят в его коллизию
	var vxf := Basis(Vector3.UP, 0.25)
	var vpos := Vector3(32.0, 0, 41.5)
	if not Game.has("crowbar"):
		var u := Items.pickup(ext, vpos + vxf * Vector3(-0.5, 0.15, 2.6), "item", "crowbar", "Взять монтировку", null, func():
			Game.think("Монтировка. А газовый ключ Гуськов так и не вернул… Ладно, на месте найду.", 4.5)
			obj("o_enter"))
		# лежит плашмя вдоль торца (модель вытянута по y, толщина по x — 4 см)
		var cb := Props.model(u, "crowbar_01", vpos + vxf * Vector3(-0.5, 0.02, 2.6), 0.25)
		cb.rotation.z = PI * 0.5
	if not "telegram" in Game.notes:
		var vis2 := Items.paper_visual("res://tex/gen/note_telegram.png", Vector2(0.21, 0.28))
		# бумага на 0.14 ниже зоны — ложится на снег (y 0.01)
		Items.pickup(ext, vpos + vxf * Vector3(0.4, 0.15, 2.6), "note", "telegram", "Прочитать телефонограмму", vis2)
	# цепь на двери
	if not Game.flag("chain_broken"):
		chain = Node3D.new()
		ext.add_child(chain)
		chain.global_position = Vector3(26.0, 1.1, 30.42)
		var m := Mat.flat(Color(0.3, 0.28, 0.26), 0.5, 0.9)
		for i in 9:
			var link := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.018
			tm.outer_radius = 0.032
			link.mesh = tm
			link.material_override = m
			link.position = Vector3(-0.32 + i * 0.08, sin(i * 0.4) * 0.03, 0.02)
			link.rotation = Vector3(PI * 0.5 if i % 2 == 0 else 0.0, 0, PI * 0.5)
			chain.add_child(link)
		Geo.mesh_box(chain, Vector3(0.07, 0.09, 0.03), Mat.flat(Color(0.5, 0.45, 0.3), 0.4, 0.9), Vector3(0.05, -0.08, 0.04))
		var u2 := Usable.make(ext, Vector3(26.0, 1.1, 30.6), Vector3(1.0, 0.6, 0.3), "Сорвать цепь монтировкой", func():
			Snd.at("chain_break", Vector3(26, 1.1, 30.5), 2.0)
			chain.queue_free()
			Game.set_flag("chain_broken")
			_door("d_entrance").locked = false
			_door("d_entrance").save_state()
			Game.think("Готово.", 1.5), 2.5)
		u2.once = true
		u2.hold_sound = "loop_pry"
		u2.cond = func(): return "" if Game.has("crowbar") else "Цепь с замком. Нужна монтировка — у фургона, на снегу."
		u2.prompt_fn = func(): return "Сорвать цепь монтировкой" if Game.has("crowbar") else "Цепь с замком"


# ---------------------------------------------------------------- глава 1

func _ch1_objects() -> void:
	var lob: Node3D = w.rooms["lobby"]["node"]
	# правила на стене у мужского отделения
	var rb := Props.picture(lob, "res://tex/gen/rules.png", Vector3(14.13, 1.6, 28.8), Vector3(1, 0, 0), Vector2(0.62, 0.82))
	var ru := Usable.make(lob, Vector3(14.2, 1.6, 28.8), Vector3(0.1, 0.8, 0.62), "Прочитать правила", func():
		Game.add_note("rules")
		Game.main.show_note("rules"))
	# план эвакуации
	var pu := Usable.make(lob, Vector3(29.6, 1.6, 23.2), Vector3(1.0, 0.6, 0.1), "Сфотографировать план эвакуации", func():
		Snd.play("camera_shutter", -2.0)
		Game.set_flag("map")
		Game.show_hint("План сохранён в телефоне: Tab → «План»", 4.0)
		if String(Game.getf("obj", "")) in ["o_way", "o_enter", ""]:
			obj("o_util"))
	pu.prompt_fn = func(): return "" if Game.flag("map") else "Сфотографировать план эвакуации"
	# доска почёта: фото отца
	var hu := Usable.make(lob, Vector3(24.45 + 0.7, 1.8, 23.22), Vector3(0.5, 0.6, 0.1), "Доска почёта", func():
		Game.set_flag("honor_seen")
		Game.think("«Ковалёв Николай Андреевич, истопник». Отец. Я его таким и не помню.", 5.0))
	hu.prompt_fn = func(): return "Посмотреть на фото" if not Game.flag("honor_seen") else ""
	# затопленная лестница
	Usable.make(lob, Vector3(34.5, 0.6, 26.2), Vector3(3.0, 1.0, 0.3), "Лестница в подвал", func():
		Game.think("Подвал под вестибюлем затоплен. Вода тёплая, над ней пар. Туда не пройти.", 4.0))
	# телефон в кассе
	var phone := Node3D.new()
	lob.add_child(phone)
	phone.global_position = Vector3(16.2, 0.875, 25.15)
	var pm := Mat.flat(Color(0.12, 0.1, 0.09), 0.4, 0.2)
	Geo.mesh_box(phone, Vector3(0.22, 0.09, 0.2), pm, Vector3(0, 0.045, 0))
	Geo.mesh_box(phone, Vector3(0.24, 0.05, 0.06), pm, Vector3(0, 0.11, 0))
	Geo.mesh_cyl(phone, 0.06, 0.01, Mat.flat(Color(0.7, 0.7, 0.65), 0.4, 0.6), Vector3(0, 0.095, 0.05)).rotation.x = 0.3
	var phu := Usable.make(lob, Vector3(16.2, 1.0, 25.15), Vector3(0.4, 0.3, 0.4), "Снять трубку", _answer_phone)
	phu.prompt_fn = func(): return "Снять трубку" if Game.flag("phone_ringing") else ("" if Game.flag("phone_answered") else "Телефон. Гудка нет")
	phu.cond = func(): return "" if Game.flag("phone_ringing") else "Мёртвая линия. Ни гудка."
	# кабинет: ключница, бумаги на столе
	var off: Node3D = w.rooms["office"]["node"]
	if not Game.has("key_util") and not Game.flag("took:key_util"):
		Items.pickup(off, Vector3(16.25, 1.58, 18.52), "item", "key_util", "Взять ключ «Подсобка муж. отд.»", Items.key_visual(), func():
			Game.think("Ключ от подсобки мужского отделения. На бирке карандашом: Ковалёв. Отцовская подсобка.", 4.5)
			obj_fwd("o_util2"))
	# высота подбираемого = поверхность + смещение картинки вниз (бумага и ключ −0.14, батарейки −0.12 − радиус 0.017):
	# стол metal_office_desk — 0.788, painted_wooden_table — 0.958, полки стеллажей — 0.70 / 1.266, пол — 0
	for n in [["complaints", Vector3(18.6, 0.93, 17.75)], ["order", Vector3(19.4, 0.93, 17.8)], ["clip_1979", Vector3(18.25, 0.93, 17.7)]]:
		if not n[0] in Game.notes:
			Items.pickup(off, n[1], "note", n[0], "Прочитать: " + Texts.note(n[0])["title"], Items.paper_visual("res://tex/gen/note_%s.png" % n[0]))
	# батарейки по зданию (на стеллажах — у переднего края полки: зона «взять» торчит из коллизии стеллажа;
	# стеллаж подсобки — коллизия x 0.35..0.85, поэтому bat3 на x 0.79). На столах — в стороне от ключа и журнала:
	# зоны «взять» не перекрываются, иначе луч к ключу/журналу сперва упирается в батарейки
	var bats := [["bat1", "linen", Vector3(24.0, 0.838, 17.65)], ["bat2", "buffet", Vector3(34.6, 1.14, 17.5)],
		["bat3", "m_util", Vector3(0.79, 1.404, 28.5)], ["bat4", "f_attend", Vector3(50.7, 1.096, 25.3)],
		["bat5", "stoker", Vector3(14.1, Y + 1.096, -8.9)], ["bat6", "pump", Vector3(37.4, 0.138, 5.6)]]
	for bt in bats:
		Items.pickup(w.rooms[bt[1]]["node"], bt[2], "battery", bt[0], "Взять батарейки", Items.battery_visual())


func _answer_phone() -> void:
	Game.set_flag("phone_ringing", false)
	Game.set_flag("phone_answered")
	if phone_snd:
		phone_snd.queue_free()
	Snd.play("phone_pickup", -2.0)
	w.player.scene_lock = true
	w.player.input_lock = true
	await wait(0.6)
	# голос в трубке — звук мира: замирает с паузой вместе с субтитрами и не доигрывает в главном меню
	Snd.play("phone_call", 0.0, 1.0, "Voice", true)
	Game.think("…капает вода. Кто-то дышит в трубку. Совсем близко.", 4.0)
	await wait(5.5)
	Game.think("«…пар… готов…»", 3.0)
	await wait(3.0)
	Snd.play("phone_hangup", -2.0)
	w.player.scene_lock = false
	w.player.input_lock = Game.main != null and (Game.main.overlay != null or Game.main.phone != null)
	Game.think("Гудки. Линия мёртвая уже двадцать лет.", 3.0)
	msg("m04", 7.0)
	# следы появляются после звонка
	_footprints_scare()


func _footprints_scare() -> void:
	await wait(4.0)
	if Game.world != w:
		return
	Game.set_flag("footprints")
	_spawn_footprints()
	Snd.at("hoz_step", Vector3(10.0, 0.3, 25.0), -8.0, 0.9, 25.0)


## Мокрые следы от входа к мужскому отделению (после звонка и при восстановлении точки).
func _spawn_footprints() -> void:
	var lob: Node3D = w.rooms["lobby"]["node"]
	if lob.has_node("footprints_lobby"):
		return
	Props.footprints(lob, Vector3(26.0, 0, 29.6), Vector3(14.6, 0, 26.5), "lobby")


func _ring_phone() -> void:
	if Game.flag("phone_answered") or Game.flag("phone_ringing"):
		return
	Game.set_flag("phone_ringing")
	var lob: Node3D = w.rooms["lobby"]["node"]
	var n := Node3D.new()
	lob.add_child(n)
	n.global_position = Vector3(16.2, 1.0, 25.15)
	phone_snd = Snd.attach("loop_phone_ring", n, 2.0, 40.0)
	Game.show_hint("Звонит телефон в кассе.", 3.0)


# ---------------------------------------------------------------- глава 2

func _ch2_objects() -> void:
	var ml: Node3D = w.rooms["m_lock"]["node"]
	# фигура под простынёй на скамье
	if not Game.flag("first_encounter"):
		sheet_man = _make_sheet_man(ml, Vector3(8.7, 0.0, 27.05), PI)
	else:
		var sheet := MeshInstance3D.new()
		sheet.mesh = _crumpled_sheet()
		var sm := _sheet_mat()
		sm.uv1_world_triplanar = true
		sm.cull_mode = BaseMaterial3D.CULL_DISABLED
		sheet.material_override = sm
		ml.add_child(sheet)
		sheet.global_position = Vector3(8.4, 0.008, 27.6)
		sheet.rotation.y = 0.4
	# ящик отца в подсобке
	var ut: Node3D = w.rooms["m_util"]["node"]
	Props.model(ut, "metal_toolbox", Vector3(2.2, 0.83, 29.6), PI)
	var tb := Usable.make(ut, Vector3(2.2, 0.95, 29.6), Vector3(0.6, 0.3, 0.35), "Открыть ящик с инструментом", func():
		Snd.at("toolbox", Vector3(2.2, 0.95, 29.6), -2.0)
		Game.give("wrench")
		Game.set_flag("wrench_taken")
		Game.add_note("father_note")
		Game.main.show_note("father_note")
		obj_fwd("o_code")
		cp("c05_code")
		# «где я бреюсь… видно только в пар» — живой игрок не связывал это с вентилем в двух шагах (автор застрял)
		if not Game.flag("lockhot_open"):
			_think_after_note("Где он брился? В мыльной бриться запрещено — значит, у зеркала в раздевальне. Пар — это горячая вода. Вентиль тут, на стене.", 7.0))
	tb.once = true
	if Game.flag("wrench_taken"):
		tb.queue_free()
	# вентиль горячей воды на раковины раздевальни
	var v := Items.valve(ut, Vector3(0.32, 1.3, 27.6), -PI * 0.5, 0.11, "Открыть горячую воду: «Раздевальня»", 3.0, func():
		Game.set_flag("line:m_lock", true)
		Game.set_flag("lockhot_open")
		Snd.play("pipe_bang", 0.0, 1.0, "Amb")
		Game.think("Трубы загудели. В раздевальне пошла горячая вода — сейчас зеркало запотеет.", 4.0)
		if not Game.flag("code_seen"):
			obj_fwd("o_mirror")
		for t in w.taps:
			if t.line == "m_lock":
				t.set_running(true)
		w.noise(Vector3(8, 1, 29), 20.0, "work"), Callable(), 12.0)
	v.cond = func(): return "" if Game.has("wrench") else "Вентиль прикипел намертво. Нужен газовый ключ."
	v.prompt_fn = func(): return "" if Game.flag("lockhot_open") else "Открыть горячую воду: «Раздевальня»"
	v.once = true
	if Game.flag("lockhot_open"):
		v.collision_layer = 0
	# мыльная: свечи на средней лавке
	var mw: Node3D = w.rooms["m_wash"]["node"]
	# мимо шайки на той же лавке (7.0, 13.3; радиус 0.2) — свеча больше не стоит в её краю
	for cz in [12.5, 12.9, 13.75, 14.15]:
		Items.candle(mw, Vector3(7.0 + randf_range(-0.15, 0.15), 0.51, cz))
	# шкафчик хлопает сам — внутри «подарок»
	# декоративный шкафчик справа от шкафчика-укрытия (10.8): раньше зона подарка совпадала с его дверцей и луч
	# взгляда случайно ловил то подарок, то укрытие — спрятаться в этот шкафчик было нельзя
	var gift := Usable.make(ml, Vector3(12.125, 1.1, 29.35), Vector3(0.4, 0.6, 0.3), "Заглянуть в шкафчик", func():
		Game.think("Сложенное полотенце и кусок мыла. Свежий, мокрый. Будто приготовили. Для гостя.", 4.0))
	gift.once = true
	_mirror_usable(ml)


## Код на запотевшем зеркале раздевальни (взгляд на зеркало в пару или «Посмотреть в зеркало»).
func _reveal_code() -> void:
	if Game.flag("code_seen"):
		return
	Game.set_flag("code_seen")
	Snd.play("sting_soft", -6.0)
	Game.think("На запотевшем зеркале проступило, пальцем: «21·12 техн.» — двадцать первое декабря.", 5.0)
	Game.show_hint("Код от технического коридора: 2112", 6.0)
	# код можно набрать и не видя зеркала — поздний взгляд не возвращает задачу главы 3 к двери
	obj_fwd("o_code2")


## Зеркало над раковинами раздевальни можно осмотреть: в пару — код, иначе мысль, чего не хватает. Без этого
## сухое зеркало молчало, а краны после её мытья (она закрывает воду сама) или закрытые игроком оставляли
## головоломку без подсказки: вентиль одноразовый, и казалось, что код больше не получить.
func _mirror_usable(parent: Node3D) -> void:
	if not w.has_meta("mirror_m_lock"):
		return
	var mm: Mirror = w.get_meta("mirror_m_lock")
	# стекло смотрит в комнату (−Z мира); зона чуть перед ним и выше кранов (их зона до y 1.17)
	var mu := Usable.make(parent, mm.global_position + Vector3(0, 0, -0.07), Vector3(1.2, 0.7, 0.12), "Посмотреть в зеркало", func():
		if Game.flag("code_seen"):
			Game.think("На стекле пальцем: «21·12 техн.» Код от технички — 2112.", 4.0)
		elif mm.fog > 0.55:
			_reveal_code()
		elif Game.flag("lockhot_open"):
			var running := false
			for t in w.taps:
				if t.line == "m_lock" and t.is_running():
					running = true
			if running:
				Game.think("Стекло только начинает потеть. Пусть пар наберётся.", 3.0)
			else:
				Game.think("Стекло высохло: краны закрыты, пар осел. Надо снова открыть краны над раковинами.", 4.5)
		elif "father_note" in Game.notes:
			Game.think("Сухое стекло. «Видно только в пар»… Нужна горячая вода, а в раковинах сухо.", 4.0)
		else:
			Game.think("Старое зеркало в пятнах. Сухое.", 2.5))
	mu.prompt_fn = func(): return "Посмотреть в зеркало"


## Мысль после того, как игрок закрыл записку (поверх записки её не видно, а записка ставит мир на паузу).
func _think_after_note(text: String, secs: float) -> void:
	var pl := w.player
	await get_tree().process_frame
	while Game.main != null and Game.main.get("overlay") != null:
		await get_tree().process_frame
		if _cut(pl):
			return
	await wait(0.4)
	if _cut(pl):
		return
	Game.think(text, secs)


func _make_sheet_man(parent: Node3D, pos: Vector3, yaw: float) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = pos
	root.rotation.y = yaw
	var ps: PackedScene = load("res://mdl/rb/man/man.fbx")
	var m: Node3D = ps.instantiate()
	root.add_child(m)
	m.rotation.y = HozBody.MODEL_YAW
	var mat := _sheet_mat()
	mat.grow = true
	mat.grow_amount = 0.06
	# голова поворачивается костью: трипланар считается по позе после скиннинга, и ткань скользила бы по голове.
	# Голове — та же ткань по UV модели (развёртка головы одним островом, шов сзади), она едет вместе с головой.
	# Один повтор на развёртку ≈ 0.45–0.65 м ткани — как трипланар 2.2/м на теле; целый масштаб — шов сзади сходится.
	var head_mat: StandardMaterial3D = mat.duplicate()
	head_mat.uv1_triplanar = false
	head_mat.uv1_scale = Vector3.ONE
	var sk: Skeleton3D = m.get_node("Skeleton3D")
	for c in sk.get_children():
		if c is MeshInstance3D:
			var cm: Mesh = (c as MeshInstance3D).mesh
			for s in cm.get_surface_count():
				var sname := ""
				if cm is ArrayMesh:
					sname = (cm as ArrayMesh).surface_get_name(s)
				var smat := cm.surface_get_material(s)
				if smat:
					sname += smat.resource_name
				(c as MeshInstance3D).set_surface_override_material(s, head_mat if "head" in sname.to_lower() else mat)
	var ap: AnimationPlayer = m.get_node("AnimationPlayer")
	var sit: Node = (load("res://mdl/rb/anim/m_sit.fbx") as PackedScene).instantiate()
	var a: Animation = (sit.get_node("AnimationPlayer") as AnimationPlayer).get_animation((sit.get_node("AnimationPlayer") as AnimationPlayer).get_animation_list()[0]).duplicate(true)
	sit.free()
	for t in range(a.get_track_count() - 1, -1, -1):
		if "Footsteps" in str(a.track_get_path(t)) or "Helper" in str(a.track_get_path(t)):
			a.remove_track(t)
	var lib := AnimationLibrary.new()
	lib.add_animation("sit", a)
	if ap.has_animation_library(""):
		ap.remove_animation_library("")
	ap.add_animation_library("", lib)
	ap.play("sit")
	ap.advance(0.0)
	ap.active = false
	var hi := sk.find_bone("Bip01 Head")
	sk.set_bone_pose_rotation(hi, sk.get_bone_pose_rotation(hi) * Quaternion(Vector3(0, 0, 1), 0.5))
	root.set_meta("sk", sk)
	return root


## Застиранная простыня: та же ткань на фигуре и на полу (новый материал — вызывающий его донастраивает).
func _sheet_mat() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://tex/gen/sheet.png")
	mat.albedo_color = Color(0.74, 0.75, 0.74)
	mat.roughness = 1.0
	mat.metallic_specular = 0.2
	var cloth_n: Texture2D = Mat.tex("res://tex/cloth/normal.jpg")
	if cloth_n:
		mat.normal_enabled = true
		mat.normal_texture = cloth_n
		mat.normal_scale = 1.4
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3.ONE * 2.2
	return mat


## Сброшенная на пол простыня: складки, ком посередине, неровный край (не плоская карточка).
func _crumpled_sheet() -> ArrayMesh:
	var pm := PlaneMesh.new()
	pm.size = Vector2(1.4, 1.1)
	pm.subdivide_width = 14
	pm.subdivide_depth = 11
	var arr := pm.get_mesh_arrays()
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	for i in vs.size():
		var v := vs[i]
		var e := maxf(absf(v.x) / 0.7, absf(v.z) / 0.55)          # 0 — центр, 1 — край
		var inner := 1.0 - smoothstep(0.7, 1.0, e)                 # края прижаты к полу
		var heap := 0.07 * exp(-(pow(v.x - 0.18, 2.0) / 0.06 + pow(v.z + 0.08, 2.0) / 0.05))
		var folds := 0.028 * absf(sin(v.x * 9.0 + v.z * 4.0 + 0.6)) + 0.012 * absf(sin(v.z * 13.0 - v.x * 5.0))
		v.y = 0.003 + heap + folds * inner
		# край не по линейке: углы и кромка подтянуты внутрь неравномерно
		var pull := 1.0 - 0.13 * smoothstep(0.55, 1.0, e) * (0.5 + 0.5 * sin(atan2(v.z, v.x) * 5.0 + 1.3))
		v.x *= pull
		v.z *= pull
		vs[i] = v
	arr[Mesh.ARRAY_VERTEX] = vs
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var st := SurfaceTool.new()
	st.create_from(am, 0)
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


func _first_encounter() -> void:
	if Game.flag("first_encounter") or encounter:
		return
	encounter = true
	var hoz: Hozyayka = w.monster
	var pl := w.player
	Game.set_flag("dir_hold")
	# сцена уже готова: души шумят, пар, она сидит и моет волосы
	hoz.visible = true
	hoz.set_state(Hozyayka.S.SCRIPT)
	hoz.global_position = Vector3(5.6, 0.0, 14.0)
	hoz.rotation.y = 0.0
	hoz.body.snap_hair()
	hoz.body.play("crouch", 0.0)
	hoz.body.rig.crawl = 0.3
	hoz.body.floor_y = 0.0
	var wash := Snd.attach("loop_hoz_wash", hoz, 0.0, 16.0)
	Game.show_hint("Не шуми.", 3.0)
	enc_noise = false
	var cb := func(p: Vector3, r: float, kind: String):
		if kind in ["step", "door", "throw", "breath", "work"] and r >= 4.0 and p.distance_to(hoz.global_position) < r + 2.0:
			enc_noise = true
	w.noise_made.connect(cb)
	# ждём, пока игрок подойдёт или пройдёт время
	var t := 0.0
	while t < 6.0 and pl.global_position.distance_to(hoz.global_position) > 5.5 and not enc_noise:
		await _frame()
		if Game.world != w:
			return
		t += get_process_delta_time()
	# телефон звякает — она замирает
	Game.add_message("m05")
	# «Без звука» (после смерти на встрече его включают по подсказке) — телефон только дрогнул в кармане
	if Game.mute_phone:
		Game.think("Телефон беззвучно дрогнул в кармане.", 2.5)
	else:
		Snd.play("phone_ping", -2.0)
	if wash:
		wash.queue_free()
	await wait(0.5)
	hoz.body.play("look", 0.4, 0.6)
	hoz.body.rig.twitch = 0.8
	Snd.at("hoz_sniff", hoz.global_position + Vector3.UP * 1.5, 2.0, 1.0, 16.0)
	Game.show_hint("Замри. Не двигайся. Можно только пригнуться (Ctrl).", 5.0)
	await wait(2.5)
	enc_noise = false
	# встаёт и идёт мимо игрока к дальнему трапу
	hoz.body.rig.crawl = 0.0
	var pp := Vector3(pl.global_position.x, 0.0, minf(pl.global_position.z, 18.7))
	var side := Vector3(1.2, 0, 0) if pp.x < 7.0 else Vector3(-1.2, 0, 0)
	# точка мимо игрока — в проходе у входа: каменные лавки кончаются на z 18.1, а идёт она без коллизии
	# (раньше при игроке между лавками заходила ногами в лавку)
	var mid := Vector3(clampf(pp.x + side.x, 0.6, 13.4), 0.0, maxf(pp.z - 0.4, 18.45))
	var waypoints := [Vector3(5.6, 0, 18.6), mid, Vector3(8.75, 0, 18.6), Vector3(8.75, 0, 10.6), Vector3(12.0, 0, 10.0)]
	for wp in waypoints:
		while hoz.global_position.distance_to(wp) > 0.3:
			if enc_noise and not Game.cheats.get("god", false):
				w.noise_made.disconnect(cb)
				encounter = false
				Game.set_flag("dir_hold", false)
				Game.set_flag("death_hint", 0)
				hoz.set_state(Hozyayka.S.RUSH)
				hoz.kill()
				return
			var dir: Vector3 = wp - hoz.global_position
			dir.y = 0
			var step := minf(dir.length(), 1.0 * get_process_delta_time())
			hoz.global_position += dir.normalized() * step
			hoz._face(wp, get_process_delta_time() * 3.0)
			hoz.body.play("walk", 0.5, 0.9)
			if hoz.global_position.distance_to(pl.global_position) < 2.5 and randf() < 0.01:
				Snd.at("hoz_sniff", hoz.global_position + Vector3.UP * 2.0, 0.0, 0.9, 10.0)
			await _frame()
			if Game.world != w:
				return
	w.noise_made.disconnect(cb)
	# уходит в трап
	hoz.set_state(Hozyayka.S.EMERGE)
	hoz.submerge()
	await wait(3.5)
	hoz.vanish()
	for tp in w.taps:
		if tp.line == "m_shower":
			tp.set_running(false, true)
	Game.set_flag("line:m_shower", false)
	Snd.play("pipe_knock", -6.0, 0.8, "Amb")
	Game.set_flag("first_encounter")
	Game.set_flag("danger", 1)
	Game.set_flag("dir_hold", false)
	# краны раздевальни (подсобку открыли до встречи) шумят — без паузы она сразу лезла из трапа у входа в мыльную,
	# рядом с замершим игроком
	if w.director:
		w.director.water_cool = 40.0
	encounter = false
	# «за спиной» — не сразу после встречи: игрок ещё стоит, как велели («Замри»), а стоять за спиной у неё — смерть
	behind_try = 30.0
	if sheet_man:
		sheet_man.queue_free()
	# точка — сразу, до пауз (смерть или смена мира посреди них не пишут её поверх экрана смерти). Подсобку открыли
	# раньше встречи: c05 уже записана, и cp("c04") молчал — смерть откатывала встречу назад
	if Game.checkpoint == "c05_code":
		Game.reach_checkpoint("c05_code")
		if Game.main and Game.main.has_method("toast"):
			Game.main.toast("Сохранено")
	else:
		cp("c04_mwash")
	msg("m06", 25.0)
	await wait(2.0)
	if _cut(pl):
		return
	Game.think("Что… это было.", 3.0)
	await wait(3.0)
	if _cut(pl):
		return
	Game.show_hint("Она слепая и идёт на звук. В телефоне (Tab) можно включить «Без звука».", 6.0)


func _prepare_encounter() -> void:
	if Game.flag("first_encounter") or Game.flag("enc_prepared"):
		return
	Game.set_flag("enc_prepared")
	Game.flags["line:m_shower"] = true
	for t in w.taps:
		if t.line == "m_shower":
			t.set_running(true, true)
	w.add_steam("m_wash", 0.3)
	w.add_steam("m_shower", 0.5)


func _behind_tutorial() -> void:
	if Game.flag("behind_tutorial"):
		return
	var hoz: Hozyayka = w.monster
	# она уже ходит — обучение не теряется, сработает на следующем проходе
	if hoz.state != Hozyayka.S.GONE:
		return
	Game.set_flag("behind_tutorial")
	# до хвата её не видно: раньше она секунду стояла на виду у последнего трапа (обычно прямо в этом проходе)
	# в ROAM — слышала, могла тронуть и убить, а хват потом ложился поверх сцены смерти
	Snd.play("pipe_knock", -8.0, 1.0, "Amb")
	await wait(1.0)
	if Game.world != w:
		return
	var pl := w.player
	if hoz.state != Hozyayka.S.GONE or pl == null or pl.dead or pl.hidden_in or Game.cheats.get("no_monster", false) \
			or encounter or Game.flag("dir_hold") or pl.input_lock or pl.scene_lock:
		Game.set_flag("behind_tutorial", false)
		return
	# та же точка, что ставит _do_behind (behind_ang = yaw + PI)
	hoz.global_position = pl.global_position + Vector3(sin(pl.yaw), 0, cos(pl.yaw)) * 0.55
	hoz.active_t = 0.0
	hoz.body.floor_y = hoz.global_position.y
	hoz.body.rig.crawl = 0.0
	hoz.body.model.position.y = 0.0
	hoz.body.set_clip(-1000.0)
	hoz.body.snap_hair()
	hoz.visible = true
	hoz.start_behind()


# ---------------------------------------------------------------- глава 3

func _ch3_objects() -> void:
	# гребёнки душевых в техническом коридоре — можно увести её водой
	var sv: Node3D = w.rooms["service"]["node"]
	for d in [["m_shower", Vector3(9.4, 1.3, 2.86), "Души мужского отделения"], ["f_shower", Vector3(42.6, 1.3, 2.86), "Души женского отделения"]]:
		var line: String = d[0]
		# что с линией — по кранам: она после мытья закрывает их сама, флаг линии остаётся «открыто», и гребёнка
		# звала «Перекрыть», а удержание ничего не делало
		var any_on := func() -> bool:
			for t in w.taps:
				if t.line == line and t.is_running():
					return true
			return false
		var u := Items.valve(sv, d[1], 0.0, 0.1, "", 1.2, func():
			if Game.flag("valve_closed"):
				Game.think("Сухо. Ввод перекрыт.", 2.5)
				return
			var on: bool = not any_on.call()
			Game.set_flag("line:" + line, on)
			for t in w.taps:
				if t.line == line:
					t.set_running(on)
			Snd.play("pipe_bang", -4.0, 1.1, "Amb"), Callable(), 8.0)
		u.prompt_fn = func(): return ("Перекрыть: " if any_on.call() else "Открыть: ") + String(d[2])
	# тетрадь банщицы и ключ от насосной
	var at: Node3D = w.rooms["f_attend"]["node"]
	# на столе painted_wooden_table: столешница на 0.958
	if not "attend_notebook" in Game.notes:
		Items.pickup(at, Vector3(49.6, 1.103, 24.95), "note", "attend_notebook", "Прочитать тетрадь банщицы", Items.paper_visual("res://tex/gen/note_attend_notebook.png"))
	if not Game.has("key_pump") and not Game.flag("took:key_pump"):
		Items.pickup(at, Vector3(50.2, 1.103, 25.1), "item", "key_pump", "Взять ключ «Насосная»", Items.key_visual(), func():
			Game.set_flag("pump_key")
			obj("o_drain")
			Game.think("Ключ от насосной. Спущу бассейн — в дне должен быть люк в коллектор, а оттуда до котельной.", 5.0)
			_flood_lobby())
	# вентиль спуска бассейна
	var pm: Node3D = w.rooms["pump"]["node"]
	# корпус задвижки на сливной трубе: труба выходит из пола, через корпус уходит в стену (под табличкой);
	# колесо отнесено от стены, шток входит в корпус
	var rust := Mat.m("rust", {"metal": 0.5, "scale": 1.0})
	var vb := Geo.Batch.new()
	Props.pipe(vb, [Vector3(37.79, 0.0, 4.3), Vector3(37.79, 1.14, 4.3)], 0.06, rust)
	Props.pipe(vb, [Vector3(37.79, 1.36, 4.3), Vector3(37.79, 1.6, 4.3), Vector3(37.95, 1.6, 4.3)], 0.06, rust)
	vb.box(rust, Vector3(37.79, 1.25, 4.3), Vector3(0.15, 0.24, 0.2))
	vb.cyl(rust, Vector3(37.79, 1.14, 4.3), Vector3(37.79, 1.16, 4.3), 0.085, 12, true)
	vb.cyl(rust, Vector3(37.79, 1.34, 4.3), Vector3(37.79, 1.36, 4.3), 0.085, 12, true)
	vb.commit(pm, "drain_valve")
	var dv := Items.valve(pm, Vector3(37.68, 1.25, 4.3), PI * 0.5, 0.18, "Открыть спуск бассейна", 4.0, func():
		Game.set_flag("pool_draining")
		Snd.play("pipe_bang", 0.0, 0.9, "Amb")
		Game.think("Пошла. Слышно, как уходит вода.", 3.0)
		drain_target = Layout.POOL_SHALLOW
		drain_speed = 0.03
		_pool_shape_scare(true), Callable(), 12.0)
	dv.cond = func(): return "" if Game.has("wrench") else "Не провернуть руками. Нужен газовый ключ."
	dv.prompt_fn = func(): return "" if Game.flag("pool_draining") or Game.flag("pool_drained") else "Открыть спуск бассейна"
	# барьер вокруг полной чаши
	pool_barrier = StaticBody3D.new()
	w.add_child(pool_barrier)
	var b := Layout.POOL_BASIN
	for e in [[Vector3(b.get_center().x, 0.6, b.position.y), Vector3(b.size.x, 1.2, 0.1)], [Vector3(b.get_center().x, 0.6, b.end.y), Vector3(b.size.x, 1.2, 0.1)],
			[Vector3(b.position.x, 0.6, b.get_center().y), Vector3(0.1, 1.2, b.size.y)], [Vector3(b.end.x, 0.6, b.get_center().y), Vector3(0.1, 1.2, b.size.y)]]:
		Geo.col_box(pool_barrier, e[0], e[1])
	_update_pool_barrier()
	# у края полной чаши — невидимая стена: сказать, почему в воду нельзя (узкая полоса вдоль края снаружи)
	var edges := [AABB(Vector3(b.position.x, 0, b.position.y - 0.35), Vector3(b.size.x, 2.0, 0.35)),
		AABB(Vector3(b.position.x, 0, b.end.y), Vector3(b.size.x, 2.0, 0.35)),
		AABB(Vector3(b.position.x - 0.35, 0, b.position.y), Vector3(0.35, 2.0, b.size.y)),
		AABB(Vector3(b.end.x, 0, b.position.y), Vector3(0.35, 2.0, b.size.y))]
	for i in edges.size():
		_trigger("pool_edge_%d" % i, edges[i], _pool_edge_hint, false)
	# решётка слива (забита волосами)
	var pl_node: Node3D = w.rooms["pool"]["node"]
	# зона — от дна до глади при забитом сливе (−1.2): решётку под метром чёрной воды не видно, луч до дна не доставал
	var gu := Usable.make(pl_node, Vector3(32.2, -1.7, 11.5), Vector3(0.9, 1.1, 0.9), "Вытащить волосы из решётки", func():
		_unclogged(), 6.0)
	gu.cond = func(): return "" if Game.flag("pool_clogged") else "Решётка слива. Под водой."
	gu.prompt_fn = func(): return "Вытащить волосы из решётки" if Game.flag("pool_clogged") and not Game.flag("pool_drained") else ""
	gu.hold_sound = "loop_hair_pull"
	gu.set_meta("unclog", true)
	if Game.flag("pool_drained"):
		gu.collision_layer = 0
	else:
		# волосы из решётки торчат над водой — видно, где она
		hair_grate = Node3D.new()
		pl_node.add_child(hair_grate)
		Props.hair_clump(hair_grate, Vector3(32.2, Layout.POOL_SHALLOW + 0.2, 11.5), 1.15, true)
	# лесенка из глубокой части
	var lad := Mat.m("rust", {"metal": 0.8, "tint": Color(1.2, 1.2, 1.2)})
	var lb := Geo.Batch.new()
	for dz in [-0.25, 0.25]:
		lb.cyl(lad, Vector3(32.95, Layout.POOL_DEEP, 13.6 + dz), Vector3(32.95, 0.9, 13.6 + dz), 0.022, 6)
		lb.cyl(lad, Vector3(32.95, 0.9, 13.6 + dz), Vector3(33.4, 0.9, 13.6 + dz), 0.022, 6)
	for k in 7:
		lb.cyl(lad, Vector3(32.92, Layout.POOL_DEEP + 0.3 + k * 0.3, 13.35), Vector3(32.92, Layout.POOL_DEEP + 0.3 + k * 0.3, 13.85), 0.016, 6)
	lb.commit(pl_node, "ladder")
	var lu := Usable.make(pl_node, Vector3(32.8, Layout.POOL_DEEP + 1.0, 13.6), Vector3(0.4, 1.4, 0.8), "Вылезти по лесенке", func():
		_climb(Vector3(33.6, 0.05, 13.6), -PI * 0.5))
	lu.prompt_fn = func(): return "Вылезти по лесенке" if w.player.global_position.y < -0.5 else ""
	# люк в дне
	var hatch := Node3D.new()
	pl_node.add_child(hatch)
	hatch.global_position = Vector3(30.5, Layout.POOL_DEEP + 0.01, 11.5)
	var hm := Mat.m("rust", {"metal": 0.6, "local": true})
	# под крышкой — шахта: чёрный проём (не освещается фонарём) в ржавой обечайке заподлицо с дном.
	# Всё ниже верха закрытой крышки (0…0.04) — пока люк закрыт, не видно; сдвинутая крышка обечайку не режет.
	var sb := Geo.Batch.new()
	sb.box(Mat.flat(Color(0.0, 0.0, 0.0), 1.0, 0.0, {"unshaded": true}), Vector3(0, 0.002, 0), Vector3(0.66, 0.004, 0.66))
	for s in [-1.0, 1.0]:
		sb.box(hm, Vector3(s * 0.355, 0.003, 0), Vector3(0.05, 0.006, 0.76))
		sb.box(hm, Vector3(0, 0.003, s * 0.355), Vector3(0.66, 0.006, 0.05))
	sb.commit(hatch, "shaft", false)
	var hmi := Geo.mesh_box(hatch, Vector3(0.8, 0.04, 0.8), hm, Vector3(0, 0.02, 0))
	hmi.name = "lid"
	if Game.flag("hatch_open"):
		hmi.position = Vector3(0.75, 0.02, 0)
	var hu := Usable.make(pl_node, Vector3(30.5, Layout.POOL_DEEP + 0.2, 11.5), Vector3(0.9, 0.4, 0.9), "Вскрыть люк монтировкой", func():
		if not Game.flag("hatch_open"):
			Game.set_flag("hatch_open")
			Snd.at("hatch_open", hatch.global_position, 2.0)
			var t := create_tween()
			t.tween_property(hmi, "position:x", 0.75, 0.6)
			hatch_u.hold = 0.0
			hatch_u.used = false
		else:
			_descend(), 2.5)
	hatch_u = hu
	hu.hold_sound = "loop_pry"
	hu.hold_noise = 8.0
	hu.cond = func(): return "" if Game.flag("pool_drained") else "Люк под водой."
	hu.prompt_fn = func():
		if not Game.flag("pool_drained"):
			return ""
		return "Вскрыть люк монтировкой" if not Game.flag("hatch_open") else "Спуститься в коллектор"
	# фиксируем «удержание» только для вскрытия
	hu.set_meta("hatch", true)
	if Game.flag("hatch_open"):
		hu.hold = 0.0


func _update_pool_barrier() -> void:
	if pool_barrier:
		pool_barrier.collision_layer = 1 if w.pool_level > -1.0 else 0


## У края полной чаши (невидимая стена до слива).
func _pool_edge_hint() -> void:
	if w.pool_level <= -1.0:
		return
	if Game.flag("pool_draining") and not Game.flag("pool_clogged"):
		if not Game.flag("pool_drain_hint"):
			Game.set_flag("pool_drain_hint")
			Game.think("Вода ещё уходит. Подожду, пока спадёт.", 3.0)
	elif not Game.flag("pool_full_hint"):
		Game.set_flag("pool_full_hint")
		Game.think("Вода чёрная, дна не видно. Полезу — она услышит. Сначала спустить воду.", 4.0)


func _flood_lobby() -> void:
	if Game.flag("lobby_flooded"):
		return
	await wait(6.0)
	# за 6 с потоп мог уже случиться (второй вызов) — второй слой воды и второй трап не нужны
	if Game.world != w or Game.flag("lobby_flooded"):
		return
	Game.set_flag("lobby_flooded")
	Game.set_flag("salt_gone_lobby")
	Snd.play("water_gush", 0.0, 1.0, "Amb")
	Game.think("Хлынула вода — в вестибюле. Подвал под ним переполнился: соль на пороге смоет, там не укрыться.", 6.5)
	_apply_flood()
	msg("m07", 4.0)


func _apply_flood() -> void:
	var r: Rect2 = w.rooms["lobby"]["rect"]
	var mat := w._water_mat(0.4, 0.45)
	var p := w._water_plane("lobby_flood", r.grow(-0.15), 0.035, mat)
	(w.waters["lobby_stairs"] as MeshInstance3D).global_position.y = 0.02
	w.drains.append({"pos": Vector3(34.5, 0.0, 24.6), "room": "lobby"})


func _pool_shape_scare(wait_player := false) -> void:
	# что-то тёмное проплывает под чёрной водой
	await wait(5.0)
	# от вентиля в насосной до бассейна — запертая дверь и ~4 м: через 5 с игрок обычно ещё в насосной,
	# и одна проверка теряла пугалку насовсем. Со слива ждём, пока он войдёт в бассейн, пока вода уходит
	while wait_player:
		if Game.world != w:
			return
		if not Game.flag("pool_draining") or Game.flag("pool_clogged") or Game.flag("pool_drained"):
			return
		if w.player.current_room == "pool":
			# вода уже у дна мелкой части — тень ушла бы под дно
			if w.pool_level < Layout.POOL_SHALLOW + 0.3:
				return
			break
		await wait(0.5)
	if Game.world != w or w.player.current_room != "pool":
		return
	var shape := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(0.8, 2.4)
	shape.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0, 0, 0, 0.75)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shape.material_override = m
	w.add_child(shape)
	shape.global_position = Vector3(20.5, w.pool_level - 0.25, 9.5)
	shape.rotation.y = -0.6
	Snd.at("water_swirl", Vector3(26, w.pool_level, 11.5), 0.0, 0.8, 20.0)
	var t := create_tween()
	t.tween_property(shape, "global_position", Vector3(31.0, w.pool_level - 0.35, 13.5), 4.0)
	t.tween_callback(shape.queue_free)
	# след на глади: тело не видно, только волна ломает отражение фонаря
	for k in 6:
		await wait(0.65)
		if is_instance_valid(shape):
			w.ripple(Vector3(shape.global_position.x, w.pool_level, shape.global_position.z), 4.5)


func _unclogged() -> void:
	Game.set_flag("pool_clogged", false)
	Game.set_flag("pool_drained")
	Snd.play("drain_whoosh", 2.0, 1.0, "Amb")
	drain_target = Layout.POOL_DEEP - 0.05
	drain_speed = 0.25
	if hair_grate:
		hair_grate.queue_free()
	Game.think("Пошла! Вода уходит. Люк — тут же, на дне.", 3.0)
	obj("o_hatch")
	var g := _find_unclog()
	if g:
		g.collision_layer = 0
	# точка сразу: из чаши выходят и по ступеням мелкой части, а люк в двух метрах — смерть у люка возвращала
	# в насосную, и слив проходили заново
	if not Game.flag("cp9"):
		Game.set_flag("cp9")
		Game.flags["pool_level"] = Layout.POOL_DEEP - 0.05
		cp("c09_drained")


func _climb(to: Vector3, yaw: float) -> void:
	var pl := w.player
	pl.scene_lock = true
	pl.input_lock = true
	Snd.play("ladder", -2.0)
	var t := create_tween()
	# погибшего на лесенке дальше не тянет вверх — скример ставит её лицо по камере
	var p0 := pl.global_position
	var top := to + Vector3(0, 0.3, 0)
	var lift := func(k: float) -> void:
		if is_instance_valid(pl) and not pl.dead:
			pl.global_position = p0.lerp(top, k)
	t.tween_method(lift, 0.0, 1.0, 1.2).set_trans(Tween.TRANS_SINE)
	await t.finished
	if _cut(pl):
		return
	pl.set_look(yaw, 0.0)
	pl.scene_lock = false
	pl.input_lock = Game.main != null and (Game.main.overlay != null or Game.main.phone != null)
	if Game.flag("pool_drained") and not Game.flag("cp9"):
		Game.set_flag("cp9")
		cp("c09_drained")


func _descend() -> void:
	var pl := w.player
	# люк остаётся «Спуститься в коллектор»: повторный спуск (вернулся наверх через решётку) не откатывает
	# задачу к уже закрытой задвижке и не повторяет мысль и m09
	var first: bool = not Game.flag("in_basement")
	pl.scene_lock = true
	pl.input_lock = true
	if Game.main and Game.main.has_method("fade_out"):
		Game.main.fade_out(0.8)
	Snd.play("ladder", -2.0)
	await wait(1.0)
	if _cut(pl):
		return
	pl.global_position = Vector3(31.0, Y + 0.1, 11.0)
	pl.set_look(0.0, 0.0)
	await wait(0.4)
	if _cut(pl):
		return
	if Game.main and Game.main.has_method("fade_in"):
		Game.main.fade_in(1.2)
	pl.scene_lock = false
	pl.input_lock = Game.main != null and (Game.main.overlay != null or Game.main.phone != null)
	Game.set_flag("in_basement")
	if not first:
		return
	Game.set_flag("danger", 3)
	obj("o_valve")
	cp("c10_collector")
	Game.think("Коллектор. Воды по щиколотку. Тут всё в волосах.", 4.0)
	msg("m09", 30.0)


# ---------------------------------------------------------------- глава 4

func _ch4_objects() -> void:
	var col: Node3D = w.rooms["collector"]["node"]
	var bu := Usable.make(col, Vector3(31.3, Y + 0.25, 3.2), Vector3(0.6, 0.5, 0.6), "Сапоги", func():
		Game.set_flag("boots_seen")
		Game.think("Резиновые сапоги. Сорок четвёртый, левый подклеен. Отцовские. Он в них на смену ходил.", 5.0))
	bu.prompt_fn = func(): return "" if Game.flag("boots_seen") else "Сапоги"
	# котельная
	var bo: Node3D = w.rooms["boiler"]["node"]
	# все записки — портрет 512×680 (0.75): квад той же пропорции, иначе текст сплющен
	Props.wall_note(bo, "mitrich", Vector3(29.0, Y + 1.5, -17.86), Vector3(0, 0, 1), Vector2(0.3, 0.4))
	# истопник: журнал на столе painted_wooden_table (столешница Y + 0.958), чуть крупнее листка
	var st: Node3D = w.rooms["stoker"]["node"]
	# вложенный листок — бумага на столе, выпадает из журнала. Раньше — пустая зона без модели левее журнала, без
	# мысли и подсказки, а без него закрыты обе концовки с полком и огнём
	var le_vis := Items.paper_visual("res://tex/gen/note_last_entry.png", Vector2(0.18, 0.24))
	var le := Usable.make(st, Vector3(13.2, Y + 1.103, -8.55), Vector3(0.3, 0.2, 0.3), "Вложенный листок", func():
		Game.set_flag("last_entry")
		Game.add_note("last_entry")
		Game.main.show_note("last_entry")
		Game.set_flag("obj_fire")
		le_vis.visible = false
		# строка про огонь — только после задвижки (_show_obj), задвижка её добавит сама
		_show_obj())
	le.add_child(le_vis)
	le_vis.rotation.y = 0.35
	le_vis.visible = Game.flag("logbook") and not Game.flag("last_entry")
	if not "logbook" in Game.notes:
		Items.pickup(st, Vector3(13.6, Y + 1.103, -8.7), "note", "logbook", "Прочитать журнал истопника", Items.paper_visual("res://tex/gen/note_logbook.png", Vector2(0.24, 0.32)), func():
			Game.set_flag("logbook")
			le_vis.visible = true
			_think_after_note("Из журнала выпал сложенный листок.", 3.5))
	le.cond = func(): return "" if Game.flag("logbook") else "Сначала журнал."
	le.prompt_fn = func(): return "" if Game.flag("last_entry") else ("Последняя запись в журнале" if Game.flag("logbook") else "")
	# детский рисунок: на стене сама картинка (512×400), без второй — текстовой — карточки в той же плоскости;
	# «посмотреть» открывает записку child_drawing, как Props.wall_note
	var dpos := Vector3(10.13, Y + 1.5, -10.0)
	Props.picture(st, "res://tex/gen/child_drawing.png", dpos, Vector3(1, 0, 0), Vector2(0.5, 0.39))
	var du := Usable.make(st, dpos + Vector3(1, 0, 0) * 0.05, Vector3(0.5, 0.39, 0.1), "Посмотреть рисунок", func():
		Game.add_note("child_drawing")
		if Game.main and Game.main.has_method("show_note"):
			Game.main.show_note("child_drawing"))
	du.rotation.y = Props.yaw_to(Vector3(-1, 0, 0))
	Props.wall_note(st, "clip_1996", Vector3(10.13, Y + 1.5, -11.2), Vector3(1, 0, 0), Vector2(0.28, 0.37))
	# варежка в бункере
	var co: Node3D = w.rooms["coal"]["node"]
	var mit := Node3D.new()
	Geo.mesh_box(mit, Vector3(0.09, 0.03, 0.12), Mat.flat(Color(0.6, 0.06, 0.05), 0.9), Vector3(0, -0.13, 0))
	Items.pickup(co, Vector3(37.3, Y + 0.3, -11.6), "item", "mitten", "Детская варежка", mit, _memory)
	# задвижка №1
	var me: Node3D = w.rooms["meter"]["node"]
	var vv := Items.valve(me, Vector3(12.0, Y + 1.82, -17.2), 0.0, 0.22, "Закрывать задвижку № 1", 4.0, _valve_step, Callable(), 14.0)
	vv.rotation = Vector3(-PI * 0.5, 0, 0)
	vv.cond = func(): return "" if Game.has("wrench") else "Закисла. Руками не провернуть — нужен газовый ключ."
	vv.prompt_fn = func():
		var s := int(Game.getf("valve_stage", 0))
		return "" if s >= 3 else "Закрывать задвижку № 1 (%d/3)" % (s + 1)
	# копия на стене узла (раньше лист лежал внутри корпуса водомера: подсказка была, бумаги не видно)
	if not "telegram" in Game.notes:
		Props.wall_note(me, "telegram", Vector3(14.9, Y + 1.6, -17.86), Vector3(0, 0, 1), Vector2(0.21, 0.28), "Прочитать телефонограмму")
	# котёл: клапан, шибер, топка
	var sv := Items.valve(bo, Vector3(18.6, Y + 1.6, -12.4), PI * 0.5, 0.13, "Перекрыть предохранительный клапан", 3.0, func():
		Game.set_flag("safety_closed")
		Snd.play("pipe_bang", -2.0, 0.8, "Amb")
		Game.think("Клапан перекрыт. Давлению теперь некуда деваться.", 3.0)
		_check_overheat(), Callable(), 10.0)
	# «Последний пар» по плану (docs/PLAN.md): закрыть ввод, прочитать последнюю запись — и только потом клапан,
	# шибер и уголь. Раньше котёл можно было разогнать при открытом вводе: c13 записывалась, а концовка «Задвижка»
	# пропадала, и уход через люк давал «Открытый кран» при взорванной бане. Пустая подсказка — предмет не трогается
	var fire_ok := func() -> bool: return Game.flag("valve_closed") and Game.flag("last_entry")
	# до задвижки клапан не молчит: прочитавший запись узнаёт, что сначала ввод (шибер и топка — скрыты)
	sv.prompt_fn = func():
		if Game.flag("safety_closed"):
			return ""
		if fire_ok.call():
			return "Перекрыть предохранительный клапан"
		return "Предохранительный клапан" if Game.flag("last_entry") else ""
	sv.cond = func(): return "" if fire_ok.call() else "Сначала ввод. Задвижка № 1 — как писал отец."
	var dm := Usable.make(bo, Vector3(23.5, Y + 2.2, -17.7), Vector3(0.6, 0.6, 0.3), "Открыть шибер", func():
		Game.set_flag("damper_open")
		Snd.at("damper", Vector3(23.5, Y + 2.2, -17.7), 0.0)
		Game.think("Шибер настежь. Тяга загудела.", 2.5)
		_check_overheat())
	dm.prompt_fn = func(): return "" if Game.flag("damper_open") or not fire_ok.call() else "Открыть шибер"
	var b2 := Geo.Batch.new()
	var drust := Mat.m("rust", {"metal": 0.6})
	var diron := Mat.flat(Color(0.2, 0.2, 0.2), 0.5, 0.8)
	b2.box(drust, Vector3(23.5, Y + 2.2, -17.8), Vector3(0.5, 0.06, 0.12))
	b2.box(diron, Vector3(23.5, Y + 2.0, -17.75), Vector3(0.04, 0.4, 0.04))
	# шибер стоит в дымоходе: чугунная коробка на стене, щель под задвижку, короб уходит к потолку
	b2.box(diron, Vector3(23.5, Y + 2.2, -17.84), Vector3(0.8, 0.6, 0.08))
	b2.box(Mat.flat(Color(0.02, 0.02, 0.02), 0.95), Vector3(23.5, Y + 2.2, -17.795), Vector3(0.56, 0.09, 0.01))
	b2.box(drust, Vector3(23.5, Y + 3.35, -17.77), Vector3(0.42, 1.7, 0.22))
	b2.commit(bo, "damper")
	var fu := Usable.make(bo, Vector3(20.0, Y + 0.7, -11.2), Vector3(0.9, 0.7, 0.4), "Подкинуть угля в топку", func():
		Game.set_flag("coal_added", int(Game.getf("coal_added", 0)) + 1)
		Snd.at("coal_shovel", Vector3(20, Y + 0.7, -11.2), 0.0)
		_check_overheat(), 2.0)
	fu.hold_sound = "loop_shovel"
	fu.hold_noise = 8.0
	fu.prompt_fn = func():
		var c := int(Game.getf("coal_added", 0))
		return "" if c >= 3 or not fire_ok.call() else "Подкинуть угля в топку (%d/3)" % (c + 1)
	# манометр котла: стрелка
	gauge = Node3D.new()
	bo.add_child(gauge)
	# циферблат смотрит на +X (props_base: диск 21.10…21.14) — стрелка вращается вокруг X в его плоскости
	gauge.global_position = Vector3(21.155, Y + 2.4, -11.9)
	var needle := Geo.mesh_box(gauge, Vector3(0.008, 0.1, 0.012), Mat.flat(Color(0.8, 0.05, 0.05), 0.4), Vector3(0, 0.04, 0))
	gauge.rotation.x = 0.8
	# люк углеподачи
	var ch := Usable.make(co, Vector3(35.0, Y + 3.0, -17.5), Vector3(1.4, 1.0, 0.8), "", _chute, 3.0)
	ch.hold_noise = 10.0
	ch.prompt_fn = func():
		if not Game.flag("chute_dug"):
			return "Отгрести уголь от люка"
		if not Game.flag("chute_open"):
			return "Вскрыть люк монтировкой"
		return "Всё равно вылезти (ввод открыт)" if exit_warned and not Game.flag("valve_closed") else "Вылезти наружу"
	ch.hold_sound = "loop_shovel"
	if Game.flag("chute_open"):
		_open_chute(false)
	# сруб: верхний полок
	var ba: Node3D = w.rooms["banya"]["node"]
	Items.pickup(ba, Vector3(33.2, Y + 1.6, -5.2), "note", "old_photo", "Старая фотография", null)
	Props.picture(ba, "res://tex/gen/old_photo.png", Vector3(33.2, Y + 1.6, -5.14), Vector3(0, 0, -1), Vector2(0.36, 0.28))
	var pu := Usable.make(ba, Vector3(35.0, Y + 1.1, -5.5), Vector3(4.0, 0.4, 0.5), "Сесть на верхний полок", _sacrifice)
	pu.prompt_fn = func():
		if not Game.flag("last_entry"):
			return ""
		return "Точно? Нажми ещё раз" if sacrifice_armed > 0.0 else "Сесть на верхний полок"
	# котёл без предохранительного уже рвёт — «баня спит» в концовке тут неправда
	pu.cond = func(): return "Поздно. Котёл сейчас рванёт — к люку!" if Game.flag("overheat") else ""


func _memory() -> void:
	Game.set_flag("mitten_memory")
	var pl := w.player
	# 10 с без управления — только пока её нет и выход не назначен: иначе «за спиной» или проходящая мимо
	# убивала замершего игрока без шанса. Когда она рядом, воспоминание идёт так же, но ноги свои
	var hoz: Hozyayka = w.monster
	var lock: bool = not Game.flag("overheat") and (hoz == null or (hoz.state == Hozyayka.S.GONE and (w.director == null or float(w.director.get("knock_t")) < 0.0)))
	var held: bool = Game.flag("dir_hold")
	if lock:
		pl.scene_lock = true
		pl.input_lock = true
		# режиссёр не выпускает её посреди сцены
		Game.set_flag("dir_hold")
	if Game.main and Game.main.has_method("flash_memory"):
		Game.main.flash_memory()
	Snd.play("memory", 0.0, 1.0, "Voice")
	await wait(1.0)
	if _cut(pl):
		return
	Game.think("…уголь колется. Темно. Папа сказал сидеть тихо, что бы ни услышал.", 4.5)
	await wait(4.5)
	if _cut(pl):
		return
	Game.think("Сверху, по крышке бункера, кто-то водит ногтями. Долго. До утра.", 4.5)
	await wait(4.5)
	if _cut(pl):
		return
	if lock:
		pl.scene_lock = false
		pl.input_lock = Game.main != null and (Game.main.overlay != null or Game.main.phone != null)
		if not held:
			Game.set_flag("dir_hold", false)
	Game.think("Я помню. Я сидел здесь.", 3.0)


func _valve_step() -> void:
	var s := int(Game.getf("valve_stage", 0)) + 1
	Game.set_flag("valve_stage", s)
	Snd.play("valve_creak_big", 0.0, 0.9 + s * 0.05, "Amb")
	if s < 3:
		Game.think(["Пошла… туго. Ещё.", "Ещё немного."][s - 1], 2.0)
		return
	Game.set_flag("valve_closed")
	Snd.play("pipe_groan", 2.0, 1.0, "Amb")
	var pl := w.player
	await wait(1.0)
	if _cut(pl):
		return
	Snd.play("hoz_scream", 4.0, 1.0, "Amb")
	if w.player:
		w.player.shake = 1.0
	Game.think("Закрыл. Счётчик встал. …Она кричит в трубах.", 4.0)
	if Game.flag("overheat"):
		# котёл уже рвёт (огонь раньше задвижки): задача остаётся «к люку», а снимок c13 переписываем
		# с закрытой задвижкой — c12 после c13 не пишется, и «Ещё раз» возвращал открытый ввод
		obj("o_run")
		if Game.checkpoint == "c13_fire":
			Game.reach_checkpoint("c13_fire")
			if Game.main and Game.main.has_method("toast"):
				Game.main.toast("Сохранено")
	else:
		obj("o_exit")
		_show_obj()
		cp("c12_valve")
	msg("m10", 6.0)
	msg("m11", 14.0)
	# она в ярости и идёт к нему
	await wait(5.0)
	if _cut(pl):
		return
	var hoz: Hozyayka = w.monster
	if hoz.state == Hozyayka.S.GONE:
		w.director.spawn_near_player(7.0, 22.0, 2.0)
	_rage(hoz)


## «Она в ярости» — 1.5. Режиссёр при выходе из трапа ставит обычную (0.8 + 0.2 × опасность) и затирал
## ярость: если выход уже назначен, ставим её ещё раз, когда она вышла (только на этот выход).
func _rage(hoz: Hozyayka) -> void:
	hoz.aggression = 1.5
	while hoz.state == Hozyayka.S.GONE and w.director != null and float(w.director.get("knock_t")) >= 0.0:
		await wait(0.2)
		if Game.world != w or not is_instance_valid(hoz):
			return
	if hoz.state != Hozyayka.S.GONE:
		hoz.aggression = 1.5


func _check_overheat() -> void:
	if Game.flag("safety_closed") and Game.flag("damper_open") and int(Game.getf("coal_added", 0)) >= 3 and not Game.flag("overheat"):
		_start_overheat(false)


func _start_overheat(restored: bool) -> void:
	Game.set_flag("overheat")
	overheat_t = 75.0
	if not restored:
		cp("c13_fire")
	obj("o_run")
	alarm = Snd.play("loop_boiler_whistle", -6.0, 1.0, "Amb")
	if Game.flag("chute_open"):
		Game.think("Манометр за красной чертой. Сейчас рванёт. К люку!", 4.0)
	else:
		Game.think("Манометр за красной чертой. Сейчас рванёт… А люк ещё не вскрыт. Быстрее!", 4.0)
	Game.set_flag("music_lock")
	Snd.music("mus_chase", -4.0, 1.0)
	var hoz: Hozyayka = w.monster
	if hoz.state == Hozyayka.S.GONE:
		# «Ещё раз» с c13: не выпускать её сразу у игрока — режиссёр выпустит сам через 15 с, вне взгляда
		if restored:
			w.director.rest = 15.0
			w.director.water_cool = 15.0
		else:
			w.director.spawn_near_player(6.0, 20.0, 1.5)
	_rage(hoz)


func _chute() -> void:
	if not Game.flag("chute_dug"):
		Game.set_flag("chute_dug")
		Game.think("Уголь отгрёб. Люк на засове снаружи? Нет — просто прикипел.", 3.0)
		return
	if not Game.flag("chute_open"):
		if not Game.has("crowbar"):
			Game.think("Нужна монтировка.", 2.0)
			return
		Game.set_flag("chute_open")
		Snd.at("hatch_open", Vector3(35, Y + 3.4, -17.8), 4.0)
		_open_chute(true)
		Game.think("Открыл! Снаружи снег и холод.", 2.5)
		return
	# выход при открытом вводе — концовка «Открытый кран» (и стёртое сохранение): сперва предупредить
	if not Game.flag("valve_closed") and not exit_warned:
		exit_warned = true
		Game.think("Ввод ещё открыт. Уйду — она по трубам пойдёт в город.", 4.0)
		return
	# выход
	var id := "open_tap"
	if Game.flag("valve_closed"):
		id = "last_steam" if Game.flag("overheat") else "valve"
	_finish(id)


## Открытый люк углеподачи. Закрытая крышка запечена в общий меш бункера (props_base), а откидывается она
## наружу — поверх тёмной вставки встаёт холодный проём (ночь, на кромке снег), прожектор из щелей разгорается.
func _open_chute(animate: bool) -> void:
	var co: Node3D = w.rooms["coal"]["node"]
	if co.has_node("chute_open"):
		return
	var n := Node3D.new()
	n.name = "chute_open"
	co.add_child(n)
	n.global_position = Vector3(35.0, Y + 3.45, -17.77)
	var sky := StandardMaterial3D.new()
	sky.albedo_color = Color(0.15, 0.18, 0.2)
	sky.roughness = 0.9
	sky.emission_enabled = true
	sky.emission = Items.MOON
	sky.emission_energy_multiplier = 0.0 if animate else 1.4
	var hole := Geo.mesh_box(n, Vector3(1.04, 0.84, 0.02), sky)
	hole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var snow := Geo.mesh_box(n, Vector3(1.04, 0.07, 0.07), Mat.flat(Color(0.8, 0.84, 0.88), 0.9, 0.0, {"emission": Items.MOON, "emission_energy": 0.4}), Vector3(0, -0.385, 0.035))
	snow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var leak: SpotLight3D = null
	for c in co.get_children():
		if c is SpotLight3D and (c as SpotLight3D).global_position.distance_to(Vector3(35.0, Y + 3.5, -17.5)) < 0.3:
			leak = c as SpotLight3D
	if animate:
		var t := create_tween().set_parallel(true)
		t.tween_property(sky, "emission_energy_multiplier", 1.4, 0.8).set_trans(Tween.TRANS_SINE)
		if leak:
			t.tween_property(leak, "light_energy", 1.8, 0.8)
	elif leak:
		leak.light_energy = 1.8


func _sacrifice() -> void:
	if sacrifice_armed <= 0.0:
		sacrifice_armed = 3.0
		return
	_finish("steam")


func _finish(id: String) -> void:
	overheat_t = -1.0
	if alarm:
		alarm.queue_free()
	if Game.main and Game.main.has_method("ending"):
		Game.main.ending(id)


# ---------------------------------------------------------------- триггеры

func _trigger(id: String, rect: AABB, fn: Callable, once := true) -> void:
	if once and Game.flag("trig:" + id):
		return
	var a := Area3D.new()
	a.collision_layer = 0
	a.collision_mask = 2
	a.monitorable = false
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = rect.size
	cs.shape = sh
	a.add_child(cs)
	w.add_child(a)
	a.global_position = rect.get_center()
	a.body_entered.connect(func(b: Node3D):
		if not (b is Player):
			return
		if Game.main and Game.main.get("prewarming"):
			return
		if once:
			if Game.flag("trig:" + id):
				return
			Game.set_flag("trig:" + id)
		if Game.bot:
			print("  [триггер] ", id)
		fn.call())
	triggers[id] = a


func _triggers() -> void:
	# вход в вестибюль
	_trigger("enter_lobby", AABB(Vector3(24.5, 0, 26.5), Vector3(3.0, 2.0, 3.0)), func():
		Game.set_flag("inside")
		obj_fwd("o_way")
		cp("c02_lobby")
		Game.think("Тепло. Влажно, как в парной. Кто-то топит котёл.", 4.0))
	# дверь заклинивает, как только игрок прошёл дальше полосы у входа: вся ширина вестибюля до z 27.6
	# (раньше — только середина x 22..30: вдоль южной стены к правилам, кассе и дверям отделений её обходили,
	# вход оставался открытым на всю игру, а двор без навмеша становился убежищем)
	_trigger("jam_entrance", AABB(Vector3(14.0, 0, 23.0), Vector3(24.0, 2.0, 4.6)), func():
		var d := _door("d_entrance")
		d.slam()
		d.locked = true
		d.lock_text = "Не открывается. Заклинило — будто держат с той стороны."
		Game.set_flag("entrance_jammed")
		d.save_state()
		w.player.shake = 0.5
		await wait(1.2)
		Game.think("Дверь… Сквозняк? Не открывается.", 3.0))
	# следы в вестибюле: подсказка
	_trigger("footprints_look", AABB(Vector3(14.6, 0, 25.5), Vector3(5.0, 2.0, 2.5)), func():
		if Game.flag("footprints") and not Game.flag("fp_thought") and not Game.flag("lobby_flooded"):
			Game.set_flag("fp_thought")
			Game.think("Следы босые. Мокрые, ещё не высохли. Пальцы длинные — слишком длинные.", 4.0), false)
	# мужская раздевальня
	# не одноразовый: если зайти сюда раньше, чем взят ключ от подсобки, точка c03 всё равно запишется позже
	_trigger("enter_mlock", AABB(Vector3(4.2, 0, 20.2), Vector3(9.6, 2.5, 9.6)), func():
		if Game.has("key_util"):
			cp("c03_mlock")
		_prepare_encounter(), false)
	# простыня: голова поворачивается
	_trigger("sheet_near", AABB(Vector3(6.8, 0, 25.5), Vector3(4.0, 2.0, 3.5)), func():
		if sheet_man and is_instance_valid(sheet_man):
			Snd.at("cloth_rustle", sheet_man.global_position + Vector3.UP, -4.0)
			var sk: Skeleton3D = sheet_man.get_meta("sk")
			var hi := sk.find_bone("Bip01 Head")
			var q0 := sk.get_bone_pose_rotation(hi)
			var q1 := q0 * Quaternion(Vector3(1, 0, 0), -0.9) * Quaternion(Vector3(0, 0, 1), -0.4)
			var tw := create_tween()
			tw.tween_method(func(v: float): sk.set_bone_pose_rotation(hi, q0.slerp(q1, v)), 0.0, 1.0, 2.5).set_trans(Tween.TRANS_SINE))
	# первая встреча: вход в мыльную
	_trigger("enc", AABB(Vector3(0.2, 0, 17.0), Vector3(13.6, 3.0, 2.8)), func():
		if not Game.flag("first_encounter"):
			_prepare_encounter()
			_first_encounter(), false)
	# «за спиной» — обучение: после кода, по дороге к душевой
	_trigger("behind", AABB(Vector3(8.5, 0, 9.4), Vector3(5.0, 3.0, 4.0)), func():
		if "father_note" in Game.notes and not Game.flag("behind_tutorial"):
			_behind_tutorial(), false)
	# технический коридор
	_trigger("service", AABB(Vector3(0.2, 0, 0.2), Vector3(51.6, 2.5, 2.6)), func():
		if String(Game.getf("obj", "")) in ["o_code2", "o_mirror", "o_code"]:
			obj("o_service")
		cp("c06_service")
		Game.think("Технический коридор. Топки каменок горят. Кто-то их топит прямо сейчас.", 4.0))
	# женское отделение
	_trigger("women", AABB(Vector3(38.2, 0, 3.2), Vector3(13.6, 3.0, 16.6)), func():
		Game.set_flag("danger", maxi(2, int(Game.getf("danger", 0))))
		if not Game.flag("grate_seen"):
			Game.set_flag("grate_seen")
			# решётку игрок мог и не трогать — задача без «решётка заперта снизу»
			obj_fwd("o_pumpkey2")
		cp("c07_women"))
	# насосная
	_trigger("pump", AABB(Vector3(30.2, 0, 3.2), Vector3(7.6, 2.5, 2.6)), func():
		cp("c08_pump"))
	# котельная
	_trigger("boiler", AABB(Vector3(16.2, Y, -18.0), Vector3(15.6, 3.5, 10.8)), func():
		Game.set_flag("boiler_seen")
		cp("c11_boiler")
		Snd.at("coal_shovel", Vector3(20, Y + 0.7, -11.0), 4.0)
		await wait(1.5)
		Snd.at("furnace_slam", Vector3(20, Y + 0.7, -11.3), 4.0)
		Game.think("Топка… захлопнулась. Здесь никого нет. Тут никого не должно быть.", 4.0))


func on_room(room: String) -> void:
	if room == "lobby" and not Game.flag("phone_answered"):
		lobby_time = 0.0


# ---------------------------------------------------------------- кадр

func _process(delta: float) -> void:
	if w == null or w.player == null:
		return
	# прогрев шейдеров водит игрока по точкам (одна — в 1.6 м перед зеркалом женской раздевальни, а c07 смотрит
	# прямо на него): одноразовое зеркало срабатывало под экраном загрузки. Как триггеры и режиссёр — ждём
	if Game.main and bool(Game.main.get("prewarming")):
		return
	var pl := w.player
	sacrifice_armed = maxf(0.0, sacrifice_armed - delta)
	# звонок телефона: после плана или через 35 с в вестибюле
	if Game.flag("inside") and not Game.flag("phone_answered") and not Game.flag("phone_ringing"):
		if pl.current_room in ["lobby", "admin", "office"]:
			lobby_time += delta
		if lobby_time > 35.0 or (Game.flag("map") and lobby_time > 8.0) or "complaints" in Game.notes:
			_ring_phone()
	# слив бассейна
	if drain_target > -50.0 and w.pool_level > drain_target:
		w.set_pool_level(maxf(drain_target, w.pool_level - drain_speed * delta))
		Game.flags["pool_level"] = w.pool_level
		if randf() < delta * 0.5:
			w.noise(Vector3(32.2, w.pool_level, 11.5), 22.0, "water")
		_update_pool_barrier()
		if w.pool_level <= drain_target + 0.001:
			if drain_target == Layout.POOL_SHALLOW and not Game.flag("pool_drained"):
				# слив встал: забит
				Game.set_flag("pool_clogged")
				Game.flags["pool_level"] = Layout.POOL_SHALLOW
				drain_target = -99.0
				Snd.play("drain_stop", 0.0, 1.0, "Amb")
				Game.think("Встала. Слив забит. Метр воды в глубокой части — у лесенки над решёткой всплыли волосы.", 5.0)
				obj("o_unclog")
				msg("m08", 3.0)
			else:
				drain_target = -99.0
				Game.flags["pool_level"] = w.pool_level
	# волосы из решётки при прочистке: что-то тянет с той стороны
	if Game.flag("pool_clogged") and not unclog_scare:
		var gu := _find_unclog()
		if gu and gu.progress > 4.0:
			unclog_scare = true
			Snd.play("hair_yank", 6.0)
			pl.shake = 1.2
			Game.think("Тянет обратно!", 1.5)
			var hoz: Hozyayka = w.monster
			if hoz.state == Hozyayka.S.GONE and not Game.cheats.get("no_monster", false):
				hoz.emerge(Vector3(21.0, Layout.POOL_SHALLOW, 11.5), pl.global_position, false)
	# над забитой решёткой подрагивает вода
	if Game.flag("pool_clogged") and not Game.flag("pool_drained") and randf() < delta * 0.7:
		w.ripple(Vector3(32.2, w.pool_level, 11.5), 2.0)
	# код на запотевшем зеркале
	if not Game.flag("code_seen") and Game.flag("lockhot_open") and w.has_meta("mirror_m_lock"):
		var m: Mirror = w.get_meta("mirror_m_lock")
		var to := m.global_position - pl.eye_pos()
		if m.fog > 0.55 and to.length() < 4.0 and pl.look_dir().dot(to.normalized()) > 0.8:
			_reveal_code()
	# краны закрыты (она помылась или игрок закрыл сам), пар осел — сказать, что воду надо пустить снова
	if Game.flag("lockhot_open") and not Game.flag("code_seen") and not Game.flag("hint_taps") and pl.current_room == "m_lock" and w.has_meta("mirror_m_lock"):
		var mm: Mirror = w.get_meta("mirror_m_lock")
		if mm.fog < 0.3 and pl.eye_pos().distance_to(mm.global_position) < 4.0:
			var tap_on := false
			for t in w.taps:
				if t.line == "m_lock" and t.is_running():
					tap_on = true
			if not tap_on:
				Game.set_flag("hint_taps")
				Game.think("Краны закрыты, пар осел. Пущу воду в раковинах — стекло снова запотеет.", 4.5)
	# «за спиной» — обучение по дороге к душевой. Триггер срабатывал только на входе в зону и только при ней в трубах:
	# пока она мылась у раковин после вентиля, игрок проходил зону, и обучения не было вовсе
	behind_try = maxf(0.0, behind_try - delta)
	if behind_try <= 0.0 and not Game.flag("behind_tutorial") and Game.flag("first_encounter") and "father_note" in Game.notes \
			and pl.current_room in ["m_wash", "m_shower"] and not Game.cheats.get("no_monster", false):
		behind_try = 3.0
		var bh: Hozyayka = w.monster
		if bh and bh.state == Hozyayka.S.GONE and w.director and float(w.director.get("knock_t")) < 0.0 and not Game.flag("dir_hold") \
				and not encounter and not pl.input_lock and not pl.scene_lock and not pl.hidden_in:
			_behind_tutorial()
	# зеркало в женской раздевальне: в отражении — она за спиной
	if not Game.flag("mirror_scare") and w.has_meta("mirror_f_lock") and pl.current_room == "f_lock":
		var fm: Mirror = w.get_meta("mirror_f_lock")
		var to2 := fm.global_position - pl.eye_pos()
		if to2.length() < 3.6 and pl.look_dir().dot(to2.normalized()) > 0.85:
			_mirror_scare(fm)
	if mirror_scare_t > 0.0:
		mirror_scare_t -= delta
		if mirror_scare_t <= 0.0 and ghost_mirror:
			ghost_mirror.queue_free()
			ghost_mirror = null
	# низкая дверь в сруб
	# у двери сруба, лицом к ней и стоя — каждый раз с перерывом (раньше один раз, при выходе из коллектора, когда
	# о срубе ещё ничего не известно)
	banya_hint_t = maxf(0.0, banya_hint_t - delta)
	if banya_hint_t <= 0.0 and not pl.crouching and pl.current_room == "boiler" and Vector2(pl.global_position.x - 31.4, pl.global_position.z + 8.0).length() < 1.2 and pl.look_dir().x > 0.6:
		banya_hint_t = 30.0
		Game.show_hint("Дверь в сруб низкая — пригнись (Ctrl), чтобы пройти.", 4.0)
	# водомер крутится, пока ввод открыт
	if w.has_meta("meter_hand") and not Game.flag("valve_closed"):
		(w.get_meta("meter_hand") as Node3D).rotation.y += delta * 6.0
	# котёл перегревается
	if overheat_t > 0.0:
		overheat_t -= delta
		if gauge:
			gauge.rotation.x = lerpf(0.8, -2.6, 1.0 - overheat_t / 75.0) + randf_range(-0.05, 0.05)
		if randf() < delta * 0.6:
			Snd.play("pipe_bang", -6.0, randf_range(0.8, 1.2), "Amb")
			pl.shake = maxf(pl.shake, 0.3)
		if overheat_t <= 0.0:
			overheat_t = -1.0
			if alarm:
				alarm.queue_free()
			if Game.main and Game.main.has_method("player_killed"):
				Game.set_flag("death_reason", "boom")
				Game.main.player_killed(null)


func _find_unclog() -> Usable:
	for c in w.rooms["pool"]["node"].get_children():
		if c is Usable and c.has_meta("unclog"):
			return c
	return null


func _mirror_scare(m: Mirror) -> void:
	Game.set_flag("mirror_scare")
	var pl := w.player
	ghost_mirror = HozBody.new()
	w.add_child(ghost_mirror)
	var back := -pl.look_dir()
	back.y = 0
	ghost_mirror.global_position = pl.global_position + back.normalized() * 1.1
	ghost_mirror.rotation.y = Props.yaw_to(-back)
	ghost_mirror.snap_hair()
	ghost_mirror.floor_y = pl.global_position.y
	ghost_mirror.play("idle", 0.0, 0.5)
	for c in ghost_mirror.find_children("*", "VisualInstance3D", true, false):
		(c as VisualInstance3D).layers = Mirror.GHOST_LAYER
	mirror_scare_t = 1.4
	Snd.play("sting_mirror", 0.0)
	await wait(1.4)
	m.force_fog = 1.0
	Snd.play("hoz_whisper", -4.0, 0.95, "Voice")
	await wait(4.0)
	m.force_fog = -1.0


func _ambience() -> void:
	var amb := Snd.play("loop_amb_building", -10.0, 1.0, "Amb")
	set_meta("amb", amb)
	var drips := Snd.play("loop_drips", -14.0, 1.0, "Amb")
	set_meta("drips", drips)


func _exit_tree() -> void:
	for k in ["amb", "drips"]:
		if has_meta(k):
			var p: Node = get_meta(k)
			if is_instance_valid(p):
				p.queue_free()
	if alarm and is_instance_valid(alarm):
		alarm.queue_free()
