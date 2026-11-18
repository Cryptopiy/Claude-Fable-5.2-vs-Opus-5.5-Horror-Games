class_name PropsGround
## Обстановка первого этажа. Сюжетные предметы (ключи, телефон, записки-находки) ставит Scenario.


static func build(w: World) -> void:
	lobby(w)
	admin(w)
	men(w)
	pool(w)
	service(w)
	women(w)


static func _n(w: World, id: String) -> Node3D:
	return w.rooms[id]["node"]


static func _b(w: World, id: String) -> StaticBody3D:
	return w.rooms[id]["body"]


# ---------------------------------------------------------------- вестибюль

static func lobby(w: World) -> void:
	var n := _n(w, "lobby")
	var body := _b(w, "lobby")
	var b := Geo.Batch.new()
	var wood := Mat.m("planks_weather", {"tint": Color(0.7, 0.55, 0.4)})
	var glass := Mat.flat(Color(0.25, 0.3, 0.28, 0.35), 0.1)
	# касса: будка в северо-западном углу
	b.box(wood, Vector3(16.6, 0.55, 25.55), Vector3(3.2, 1.1, 0.08))
	b.box(glass, Vector3(16.6, 1.65, 25.55), Vector3(3.2, 1.1, 0.02))
	b.box(wood, Vector3(16.6, 2.4, 25.55), Vector3(3.2, 0.4, 0.08))
	b.box(wood, Vector3(18.15, 1.3, 25.0), Vector3(0.08, 2.6, 1.1))
	b.box(wood, Vector3(18.15, 2.4, 23.9), Vector3(0.08, 0.4, 1.1))
	b.box(wood, Vector3(16.6, 2.63, 24.4), Vector3(3.2, 0.06, 2.4))
	b.box(wood, Vector3(16.6, 0.85, 25.2), Vector3(3.0, 0.05, 0.6))
	b.box(wood, Vector3(16.6, 0.42, 25.42), Vector3(3.0, 0.84, 0.05))
	Geo.col_box(body, Vector3(16.6, 1.3, 25.55), Vector3(3.2, 2.6, 0.1))
	Geo.col_box(body, Vector3(18.15, 1.3, 25.0), Vector3(0.1, 2.6, 1.1))
	Geo.col_box(body, Vector3(16.6, 0.45, 25.2), Vector3(3.0, 0.9, 0.6))
	Props.picture(n, "res://tex/gen/sign_kassa.png", Vector3(16.6, 2.4, 25.6), Vector3(0, 0, 1), Vector2(0.9, 0.28))
	# прейскурант — по центру боковой стенки (z 24.45–25.55), а не над проходом в будку
	Props.picture(n, "res://tex/gen/prices.png", Vector3(18.2, 1.6, 25.0), Vector3(1, 0, 0), Vector2(0.5, 0.62))
	Props.model(n, "CashRegister_01", Vector3(17.5, 0.875, 25.15), PI)
	Props.model(n, "painted_wooden_chair_01", Vector3(16.6, 0.0, 24.3), 0.0)
	var lamp := Props.model(n, "vintage_oil_lamp", Vector3(15.6, 0.875, 25.15), 0.3)
	var fire := Items.Fire.new()
	fire.base = 1.1
	fire.omni_range = 7.0
	fire.light_color = Items.CANDLE
	n.add_child(fire)
	fire.global_position = Vector3(15.6, 1.15, 25.0)
	w.set_meta("lobby_lamp", fire)
	# гардероб: стойка и вешалки у южной стены справа
	b.box(wood, Vector3(35.0, 0.55, 28.2), Vector3(3.2, 1.1, 0.5))
	Geo.col_box(body, Vector3(35.0, 0.55, 28.2), Vector3(3.2, 1.1, 0.5))
	var rail := Mat.flat(Color(0.35, 0.33, 0.3), 0.4, 0.8)
	b.cyl(rail, Vector3(33.5, 1.75, 29.4), Vector3(36.6, 1.75, 29.4), 0.02)
	for i in 9:
		var x := 33.7 + i * 0.34
		b.box(rail, Vector3(x, 1.68, 29.4), Vector3(0.01, 0.14, 0.01))
		if i in [1, 4, 5, 7]:
			var coat := Mat.m("cloth", {"tint": Color(0.25 + randf() * 0.1, 0.22, 0.2), "scale": 0.6})
			b.box(coat, Vector3(x, 1.1, 29.4), Vector3(0.38, 1.1, 0.16), Basis(Vector3.UP, randf_range(-0.2, 0.2)))
	Props.picture(n, "res://tex/gen/sign_garderob.png", Vector3(35.0, 2.6, 29.88), Vector3(0, 0, -1), Vector2(0.9, 0.25))
	# скамьи
	Props.model(n, "painted_wooden_bench", Vector3(25.5, 0, 23.5), PI, 1.0, true)
	Props.model(n, "painted_wooden_bench", Vector3(21.0, 0, 29.4), 0.0, 1.0, true)
	Props.model(n, "painted_wooden_bench", Vector3(30.5, 0, 29.4), 0.0, 1.0, true)
	# доска почёта
	var board := Mat.m("planks_dark", {"tint": Color(0.55, 0.2, 0.15)})
	b.box(board, Vector3(25.5, 1.95, 23.16), Vector3(2.6, 1.3, 0.06))
	# sign_bani.png 4:1 — квад той же пропорции, иначе шрифт растянут вширь
	Props.picture(n, "res://tex/gen/sign_bani.png", Vector3(25.5, 2.48, 23.2), Vector3(0, 0, 1), Vector2(0.8, 0.2), {"tint": Color(1.2, 1.0, 0.7)})
	var photos := ["honor_1", "honor_father", "honor_0", "honor_2"]
	for i in 4:
		Props.picture(n, "res://tex/gen/%s.png" % photos[i], Vector3(24.45 + i * 0.7, 1.8, 23.2), Vector3(0, 0, 1), Vector2(0.46, 0.6))
	# план эвакуации
	Props.picture(n, "res://tex/gen/evac_plan.png", Vector3(29.6, 1.6, 23.14), Vector3(0, 0, 1), Vector2(1.04, 0.64))
	# таблички над дверями отделений
	Props.picture(n, "res://tex/gen/sign_male.png", Vector3(14.14, 2.65, 26.5), Vector3(1, 0, 0), Vector2(0.9, 0.45))
	Props.picture(n, "res://tex/gen/sign_female.png", Vector3(37.86, 2.65, 26.5), Vector3(-1, 0, 0), Vector2(0.9, 0.45))
	Props.picture(n, "res://tex/gen/sign_rules_short.png", Vector3(37.86, 1.6, 24.4), Vector3(-1, 0, 0), Vector2(0.6, 0.3))
	# над наличником входной двери (проём до 2.4, наличник до 2.48), а не поперёк створок
	Props.picture(n, "res://tex/gen/sign_water_save.png", Vector3(26.0, 2.72, 29.86), Vector3(0, 0, -1), Vector2(0.6, 0.35))
	# часы стоят на 23:40. У модели циферблат смотрит в +Z (задник — z = 0): yaw 0 — лицом в зал, задник у стены
	var clock := Props.model(n, "wall_clock", Vector3(21.5, 2.9, 23.13), 0.0, 1.0)
	# стрелки в модели — на 10:10, ось вращения — центр циферблата; повернуть на 23:40 (+Z смотрит на зрителя)
	var mh := clock.find_child("wall_clock_minute_hand", true, false) as Node3D
	if mh:
		mh.rotation.z = deg_to_rad(-183.0)
	var hh := clock.find_child("wall_clock_hours_hand", true, false) as Node3D
	if hh:
		hh.rotation.z = deg_to_rad(-43.2)
	# соль на порогах — отдельным пакетом: после потопа (salt_gone_lobby) её смыло, и белые полосы под водой
	# не должны говорить игроку, что вестибюль ещё безопасен (is_safe уже false)
	var sb := Geo.Batch.new()
	Props.salt(sb, Vector3(14.35, 0, 26.5), false, 1.3)
	Props.salt(sb, Vector3(37.65, 0, 26.5), false, 1.3)
	Props.salt(sb, Vector3(20.0, 0, 23.3), true, 1.1)
	var salt: Array = sb.commit(n, "salt", false)
	var wash := func(fname: String, _value: Variant) -> void:
		if fname != "salt_gone_lobby":
			return
		for mi in salt:
			if is_instance_valid(mi):
				(mi as MeshInstance3D).visible = not Game.flag("salt_gone_lobby")
	wash.call("salt_gone_lobby", null)
	Game.flag_changed.connect(wash)
	n.tree_exiting.connect(func():
		if Game.flag_changed.is_connected(wash):
			Game.flag_changed.disconnect(wash))
	# мусор: опрокинутый стул, коробки
	Props.model(n, "cardboard_box_01", Vector3(36.8, 0, 24.0), 0.4)
	Props.model(n, "painted_wooden_chair_02", Vector3(29.0, 0, 26.0), 1.9)
	b.commit(n, "props")


# ---------------------------------------------------------------- коридор персонала и комнаты

static func admin(w: World) -> void:
	var n := _n(w, "admin")
	var b := Geo.Batch.new()
	Props.model(n, "painted_wooden_bench", Vector3(30.0, 0, 22.6), 0.0, 1.0, true)
	Props.picture(n, "res://tex/gen/sign_water_save.png", Vector3(23.0, 1.7, 22.86), Vector3(0, 0, -1), Vector2(0.55, 0.32))
	Props.picture(n, "res://tex/gen/sign_bufet.png", Vector3(34.0, 2.35, 20.14), Vector3(0, 0, 1), Vector2(0.6, 0.17))
	# огнетушитель
	var red := Mat.flat(Color(0.55, 0.06, 0.04), 0.5, 0.3)
	b.cyl(red, Vector3(16.6, 0.0, 22.6), Vector3(16.6, 0.6, 22.6), 0.09, 12, true)
	# горловина, головка с рычагом, раструб на шланге вдоль корпуса, бумажная этикетка
	var blk := Mat.flat(Color(0.08, 0.08, 0.08), 0.4, 0.6)
	b.cyl(blk, Vector3(16.6, 0.6, 22.6), Vector3(16.6, 0.66, 22.6), 0.032, 8, true)
	b.box(blk, Vector3(16.6, 0.685, 22.6), Vector3(0.05, 0.05, 0.08))
	b.box(blk, Vector3(16.64, 0.72, 22.6), Vector3(0.13, 0.014, 0.03), Basis(Vector3(0, 0, 1), 0.15))
	b.cyl(blk, Vector3(16.6, 0.67, 22.555), Vector3(16.6, 0.6, 22.495), 0.012, 6)
	b.cyl(blk, Vector3(16.6, 0.6, 22.495), Vector3(16.61, 0.26, 22.497), 0.012, 6)
	b.cyl(blk, Vector3(16.61, 0.26, 22.497), Vector3(16.61, 0.2, 22.497), 0.022, 8, true)
	b.cyl(Mat.flat(Color(0.78, 0.76, 0.68), 0.7), Vector3(16.6, 0.28, 22.6), Vector3(16.6, 0.44, 22.6), 0.092, 12)
	b.commit(n, "props")

	# кабинет заведующей
	var o := _n(w, "office")
	var ob := _b(w, "office")
	var ob2 := Geo.Batch.new()
	# стол ящиками в комнату (у модели ящики — в +Z), стул — с южной стороны, сиденьем к столу:
	# между столом и северной стеной всего 0.15 м, стул там врезался и в стену, и в столешницу.
	# Габарит стола по z (17.28–18.23) тот же — бумаги сценария на нём остаются
	Props.model(o, "metal_office_desk", Vector3(19.0, 0, 17.75), 0.0, 1.0, true)
	Props.model(o, "painted_wooden_chair_02", Vector3(19.0, 0, 18.6), PI)
	Props.model(o, "painted_wooden_cabinet", Vector3(21.4, 0, 18.4), -PI * 0.5, 1.0, true)
	# лампа на струбцине — на восточном краю столешницы (0.788, край x 20.0), а не посреди стола: у модели скоба
	# струбцины — в +Z (z 0.018…0.044), губки — в −Z, нижняя губка до −0.088. yaw π/2: скоба за краем (x 20.0…20.03),
	# губки и плафон — над столом. У северного края нельзя: нижнее плечо отклонено на 0.32 назад и ушло бы в стену (z 17.12)
	Props.model(o, "desk_lamp_arm_01", Vector3(19.983, 0.788, 17.5), PI * 0.5)
	Props.picture(o, "res://tex/gen/calendar.png", Vector3(21.86, 1.6, 19.3), Vector3(-1, 0, 0), Vector2(0.32, 0.45))
	# ключница на западной стене
	var kb := Mat.m("planks_dark", {"tint": Color(0.6, 0.45, 0.3)})
	ob2.box(kb, Vector3(16.15, 1.55, 18.6), Vector3(0.04, 0.5, 0.7))
	var hook := Mat.flat(Color(0.5, 0.45, 0.3), 0.4, 0.9)
	for r in 2:
		for c in 4:
			var hp := Vector3(16.19, 1.7 - r * 0.25, 18.35 + c * 0.17)
			ob2.box(hook, hp, Vector3(0.03, 0.01, 0.01))
			if not (r == 0 and c == 1) and not (r == 1 and c == 3):
				ob2.box(hook, hp + Vector3(0.02, -0.06, 0), Vector3(0.004, 0.07, 0.025))
				ob2.box(Mat.flat(Color(0.75, 0.7, 0.55), 0.8), hp + Vector3(0.02, -0.12, 0), Vector3(0.005, 0.04, 0.03))
	# сейф: крашеная сталь, дверца на восточной грани (лицом в кабинет), ручка, лимб, петли
	var sm := Mat.m("metal_green", {"metal": 0.1, "tint": Color(0.75, 0.82, 0.78), "scale": 0.8})
	ob2.box(sm, Vector3(16.5, 0.4, 19.6), Vector3(0.5, 0.8, 0.5))
	ob2.box(sm, Vector3(16.756, 0.42, 19.6), Vector3(0.012, 0.64, 0.4))
	ob2.box(hook, Vector3(16.775, 0.45, 19.47), Vector3(0.03, 0.12, 0.025))
	ob2.cyl(hook, Vector3(16.762, 0.6, 19.6), Vector3(16.782, 0.6, 19.6), 0.035, 12, true)
	for hy in [0.22, 0.62]:
		ob2.box(hook, Vector3(16.765, hy, 19.81), Vector3(0.03, 0.08, 0.02))
	Geo.col_box(ob, Vector3(16.5, 0.4, 19.6), Vector3(0.5, 0.8, 0.5))
	ob2.commit(o, "props")

	# бельевая
	var l := _n(w, "linen")
	var lb := Geo.Batch.new()
	Props.shelves(lb, _b(w, "linen"), Vector3(23.4, 0, 17.45), 1.6, 0.5, 1.9, 4, true)
	Props.shelves(lb, _b(w, "linen"), Vector3(25.6, 0, 17.45), 1.6, 0.5, 1.9, 4, true)
	# полотенца — небелёное полотно: альбедо tex/terry насыщенно-синее, умножением на беж его не перекрасить
	var towel := Mat.m("cloth", {"tint": Color(0.6, 0.57, 0.5)})
	# стопки по три сложенных полотенца лежат на полках стеллажа: доски Props.shelves — y = 0.12 + i·1.7/3,
	# толщина 0.025. Нижние три полки; верхняя пустая
	for sx in [23.4, 25.6]:
		for i in 3:
			var top := 0.12 + i * (1.9 - 0.2) / 3.0 + 0.0125
			for k in 3:
				for layer in 3:
					var jit := Vector3(randf_range(-0.015, 0.015), 0.0, randf_range(-0.012, 0.012))
					lb.box(towel, Vector3(sx - 0.35 + k * 0.35, top + 0.0322 + layer * 0.0645, 17.45) + jit, Vector3(0.3, 0.0625, 0.35))
	# тележка для белья: ящик на стойках с колёсиками и ручкой. Металл — ровно те же opts, что у Props.shelves
	# (кэш Mat.m по имени и opts): тот же материал, без лишнего вызова отрисовки; металл 0.5 с тёмным оттенком был чёрным
	var cart := Mat.m("metal_green", {"metal": 0.15, "tint": Color(0.8, 0.85, 0.8), "scale": 1.0})
	lb.box(cart, Vector3(25.8, 0.55, 19.2), Vector3(0.9, 0.5, 0.55))
	for dx in [-0.41, 0.41]:
		for dz in [-0.24, 0.24]:
			lb.box(cart, Vector3(25.8 + dx, 0.18, 19.2 + dz), Vector3(0.035, 0.24, 0.035))
			lb.cyl(cart, Vector3(25.8 + dx, 0.035, 19.2 + dz - 0.02), Vector3(25.8 + dx, 0.035, 19.2 + dz + 0.02), 0.035, 8, true)
	for dz in [-0.2, 0.2]:
		lb.cyl(cart, Vector3(26.25, 0.75, 19.2 + dz), Vector3(26.38, 0.95, 19.2 + dz), 0.012, 6)
	lb.cyl(cart, Vector3(26.38, 0.95, 18.98), Vector3(26.38, 0.95, 19.42), 0.015, 8)
	lb.box(Mat.m("cloth", {"tint": Color(0.55, 0.52, 0.46)}), Vector3(25.8, 0.85, 19.2), Vector3(0.85, 0.2, 0.5))
	# тележка твёрдая — вместе с ручкой (x до 26.38); до двери (x ≤ 25.0) и южной стены остаётся проход
	Geo.col_box(_b(w, "linen"), Vector3(25.86, 0.5, 19.2), Vector3(1.06, 1.0, 0.6))
	lb.commit(l, "props")

	# парикмахерская
	var p := _n(w, "barber")
	var pb := Geo.Batch.new()
	Props.model(p, "BarberShopChair_01", Vector3(31.0, 0, 18.1), 0.0, 1.0, true)
	# зеркало-«стекло» без камеры (Mirror.make — лишний проход рендера): не металл — отражать ему нечего
	# (отражений окружения нет), с металлом 0.9 оно было чёрной дырой. Тёмное глянцевое стекло ловит блик фонаря.
	var dark_glass := Mat.flat(Color(0.13, 0.14, 0.14), 0.15, 0.0)
	pb.box(dark_glass, Vector3(31.0, 1.55, 17.15), Vector3(1.2, 0.9, 0.02))
	# рама
	var bframe := Mat.flat(Color(0.25, 0.22, 0.18), 0.6, 0.0)
	for sy in [-1.0, 1.0]:
		pb.box(bframe, Vector3(31.0, 1.55 + sy * 0.48, 17.16), Vector3(1.32, 0.06, 0.04))
	for sx in [-1.0, 1.0]:
		pb.box(bframe, Vector3(31.0 + sx * 0.63, 1.55, 17.16), Vector3(0.06, 0.9, 0.04))
	pb.box(Mat.m("tile_wall"), Vector3(31.0, 0.8, 17.3), Vector3(1.6, 0.06, 0.3))
	pb.commit(p, "props")
	# срезанные волосы на полу — слишком много и слишком длинные
	for i in 6:
		Props.hair_clump(p, Vector3(30.6 + randf_range(-0.8, 0.8), 0.0, 18.6 + randf_range(-0.5, 0.8)), randf_range(0.4, 0.9), false)

	# буфет
	var f := _n(w, "buffet")
	var fb := Geo.Batch.new()
	var wood := Mat.m("planks_weather", {"tint": Color(0.65, 0.5, 0.38)})
	# стойка: корпус, столешница другой доской с напуском и утопленный цоколь — иначе трипланарные швы
	# переходят с фасада на верх и стойка читается ящиком. Верх столешницы — 1.0, как и был
	fb.box(wood, Vector3(34.0, 0.51, 17.5), Vector3(3.5, 0.86, 0.55))
	fb.box(Mat.m("planks_dark", {"tint": Color(0.6, 0.48, 0.36)}), Vector3(34.0, 0.97, 17.5), Vector3(3.7, 0.06, 0.66))
	fb.box(Mat.flat(Color(0.08, 0.06, 0.05), 0.8), Vector3(34.0, 0.04, 17.47), Vector3(3.4, 0.08, 0.5))
	Geo.col_box(_b(w, "buffet"), Vector3(34.0, 0.5, 17.5), Vector3(3.6, 1.0, 0.6))
	fb.commit(f, "props")
	Props.model(f, "tea_set_01", Vector3(33.3, 1.0, 17.5), 0.3)
	Props.model(f, "vintage_electric_kettle", Vector3(34.8, 1.0, 17.45), 2.0)
	Props.model(f, "WoodenTable_01", Vector3(35.15, 0, 18.85), PI * 0.5, 1.0, true)
	# у модели сиденье смотрит в +Z: yaw +π/2 — лицом к столу (на восток)
	Props.model(f, "painted_wooden_chair_01", Vector3(34.5, 0, 19.0), PI * 0.5)


# ---------------------------------------------------------------- мужское отделение

static func men(w: World) -> void:
	_locker_room(w, "m_lock", false)
	_wash(w, "m_wash", false)
	_steam(w, "m_steam", false)
	_showers(w, "m_shower", false)
	# ожидальня
	var n := _n(w, "m_wait")
	Props.model(n, "painted_wooden_chair_01", Vector3(0.5, 0, 21.0), -PI * 0.5)
	Props.model(n, "painted_wooden_chair_01", Vector3(0.5, 0, 21.8), -PI * 0.5)
	Props.model(n, "painted_wooden_chair_02", Vector3(0.5, 0, 24.9), -PI * 0.5)
	# в модели Poly Haven два бака рядом (чистый и ржавый, по ±0.5 м по x, крышки прислонены сбоку):
	# оставить ржавый и поставить его в точку модели. yaw −π/2 — крышка к северу, бак не заходит в стены (x ≤ 3.83, z ≤ 25.84)
	var tc := Props.model(n, "metal_trash_can", Vector3(3.55, 0, 25.53), -PI * 0.5)
	for c in tc.get_children():
		var c3 := c as Node3D
		if c3 == null:
			continue
		if String(c3.name).contains("rust"):
			c3.position.x += 0.5
		else:
			c3.queue_free()
	Props.picture(n, "res://tex/gen/sign_wash_feet.png", Vector3(3.86, 1.7, 21.0), Vector3(-1, 0, 0), Vector2(0.6, 0.3))
	# подсобка
	var u := _n(w, "m_util")
	var ub := _b(w, "m_util")
	var shb := Geo.Batch.new()
	# стеллаж отодвинут от стены на 0.15: задние стойки проходили сквозь подоконник (x ≤ 0.315), гребёнка — сквозь полки.
	# Коллизия своя и только до третьей доски (её низ — 1.241): батарейки сценария (bat3) лежат на этой доске, и их зона
	# «взять» (y от 1.254) не должна оказаться внутри коробки стеллажа (x 0.35–0.85) — иначе луч взгляда упирается в её
	# грань. Выше коллизия не нужна: капсулу игрока и навмеш останавливает нижняя часть
	Props.shelves(shb, null, Vector3(0.6, 0, 28.6), 1.5, 0.5, 1.9, 4, false)
	Geo.col_box(ub, Vector3(0.6, 0.61, 28.6), Vector3(0.5, 1.22, 1.5))
	shb.commit(u, "shelves")
	Props.model(u, "wooden_bucket_01", Vector3(3.2, 0, 29.4), 0.0)
	# метла прислонена к восточной стене: щётка у модели ниже начала координат (до −0.122), черенок касается стены
	var broom := Props.model(u, "wooden_broom", Vector3(3.53, 0.132, 27.0), PI * 0.5)
	broom.rotation.x = 0.25
	# на полках (доски — 0.12 / 0.687 / 1.253 / 1.82, верх доски +0.0125); у моделей начало координат — дно
	Props.model(u, "metal_jug", Vector3(0.6, 0.70, 28.2), 0.0)
	Props.model(u, "cleaner_tin_01", Vector3(0.6, 1.266, 28.9), 0.0)
	var ubb := Geo.Batch.new()
	# стол под ящик с инструментом: тумба — доска потемнее, а не однотонная заглушка
	ubb.box(Mat.m("planks_weather", {"tint": Color(0.6, 0.5, 0.4)}), Vector3(2.2, 0.8, 29.6), Vector3(1.4, 0.05, 0.5))
	ubb.box(Mat.m("planks_dark", {"tint": Color(0.55, 0.5, 0.45)}), Vector3(2.2, 0.4, 29.6), Vector3(1.3, 0.8, 0.45))
	Geo.col_box(ub, Vector3(2.2, 0.42, 29.6), Vector3(1.4, 0.84, 0.5))
	# гребёнка на западной стене — вся мимо окна (z 27.5–28.5) и подоконника (z 27.45–28.55), стояки уходят в потолок
	var rust := Mat.m("rust", {"metal": 0.5})
	Props.pipe(ubb, [Vector3(0.2, 0.0, 27.0), Vector3(0.2, 1.3, 27.0), Vector3(0.2, 1.3, 28.7), Vector3(0.2, 3.02, 28.7)], 0.045, rust)
	Props.pipe(ubb, [Vector3(0.2, 1.3, 27.15), Vector3(0.2, 3.02, 27.15)], 0.03, rust)
	Props.pipe(ubb, [Vector3(0.2, 1.3, 27.3), Vector3(0.2, 3.02, 27.3)], 0.03, rust)
	ubb.commit(u, "props")


static func _locker_room(w: World, id: String, female: bool) -> void:
	var n := _n(w, id)
	var body := _b(w, id)
	var r: Rect2 = w.rooms[id]["rect"]
	var x0 := r.position.x
	var x1 := r.end.x
	var b := Geo.Batch.new()
	var tint := Color(0.85, 0.75, 0.78) if female else Color(0.75, 0.82, 0.78)
	# шкафчики вдоль южной стены (оставляем место для раковин и окна)
	Props.lockers(b, body, Vector3(x0 + 0.3, 0, 29.6), 6, Vector3(1, 0, 0), Vector3(0, 0, -1), tint)
	Props.lockers(b, body, Vector3(x1 - 0.3 - 0.45 * 4, 0, 29.6), 4, Vector3(1, 0, 0), Vector3(0, 0, -1), tint)
	# ряды скамей со спинками; доска крупнее (2.4 м на повтор) — на 6.5-метровой спинке сучки не повторяются через 1.2 м
	var wood := Mat.m("planks_weather", {"tint": Color(0.8, 0.68, 0.5), "scale": 2.4})
	# доски сиденья — вдоль скамьи (planks_dark даёт швы по x), спинка — прежним деревом
	var seat := Mat.m("planks_dark", {"tint": Color(1.25, 1.08, 0.82), "scale": 2.4})
	Props.bench(b, body, Vector3((x0 + x1) * 0.5, 0, 23.4), 6.5, true, true, wood, seat)
	Props.bench(b, body, Vector3((x0 + x1) * 0.5 - (0.6 if not female else -0.6), 0, 26.6), 5.0, true, true, wood, seat)
	# крючки и полотенца на спинках
	var hook := Mat.flat(Color(0.4, 0.38, 0.33), 0.5, 0.8)
	for i in 10:
		var x := (x0 + x1) * 0.5 - 3.0 + i * 0.65
		b.box(hook, Vector3(x, 1.35, 23.62), Vector3(0.02, 0.02, 0.08))
		if randf() < 0.35:
			# небелёное полотно (у tex/terry синее альбедо); два оттенка — два материала на комнату, а не по одному
			# на полотенце. Висит вплотную к спинке (задняя грань спинки — z 23.62)
			var tt := Color(0.8, 0.77, 0.7) if randf() < 0.5 else Color(0.8, 0.83, 0.7)
			b.box(Mat.m("cloth", {"tint": tt}), Vector3(x, 1.0, 23.635), Vector3(0.3, 0.7, 0.025))
	# служебные шкафчики-укрытия
	var hx := x1 - 0.5 if not female else x0 + 0.5
	w.hides.append(HideSpot.make_locker(n, Vector3(hx, 0, 21.1), PI * 0.5 if not female else -PI * 0.5))
	w.hides.append(HideSpot.make_locker(n, Vector3((x0 + x1) * 0.5 + 1.8, 0, 29.55), 0.0))
	# раковины и зеркала у южной стены (между шкафчиками). Зеркало с рамой — x0 + 3.21…4.59: окно раздевальни
	# в Layout.WINDOWS уже и сдвинуто (x0 + 4.75…6.35, подоконник с x0 + 4.70), подоконник зеркало не режет
	var sink_x := [x0 + 3.4, x0 + 4.4]
	# эмалированная раковина: дно, четыре борта, тёмная мокрая чаша со сливом, фаянсовая ножка
	var enamel := Mat.flat(Color(0.8, 0.8, 0.76), 0.3)
	var bowl := Mat.flat(Color(0.3, 0.31, 0.29), 0.12)
	for sx in sink_x:
		b.box(enamel, Vector3(sx, 0.775, 29.62), Vector3(0.5, 0.03, 0.4))
		b.box(bowl, Vector3(sx, 0.795, 29.62), Vector3(0.42, 0.01, 0.32))
		b.box(hook, Vector3(sx, 0.801, 29.62), Vector3(0.04, 0.004, 0.04))
		for side in [-1.0, 1.0]:
			b.box(enamel, Vector3(sx, 0.835, 29.62 + side * 0.18), Vector3(0.5, 0.09, 0.04))
			b.box(enamel, Vector3(sx + side * 0.23, 0.835, 29.62), Vector3(0.04, 0.09, 0.32))
		b.box(enamel, Vector3(sx, 0.38, 29.72), Vector3(0.14, 0.76, 0.12))
		var t := Props.wall_tap(w, id, Vector3(sx, 1.02, 29.86), Vector3(0, 0, -1), id)
		w.taps.append(t)
	var mirror := Mirror.make(n, Vector3((sink_x[0] + sink_x[1]) * 0.5, 1.6, 29.87), PI, Vector2(1.3, 0.8), id,
		"res://tex/gen/mirror_code.png" if not female else "res://tex/gen/mirror_word.png")
	w.set_meta("mirror_" + id, mirror)
	# медицинские весы: крашеная сталь, резиновый коврик на площадке, циферблат со стрелкой на головке
	var scale_m := Mat.m("metal_green", {"metal": 0.2, "tint": Color(0.85, 0.85, 0.8), "scale": 1.0})
	b.box(scale_m, Vector3(x0 + 0.6, 0.05, 20.6), Vector3(0.45, 0.1, 0.45))
	b.box(Mat.flat(Color(0.05, 0.05, 0.05), 0.8), Vector3(x0 + 0.6, 0.106, 20.62), Vector3(0.4, 0.012, 0.38))
	b.box(scale_m, Vector3(x0 + 0.6, 0.8, 20.3), Vector3(0.06, 1.5, 0.06))
	b.box(scale_m, Vector3(x0 + 0.6, 1.55, 20.38), Vector3(0.3, 0.25, 0.08))
	b.cyl(Mat.flat(Color(0.85, 0.83, 0.74), 0.6), Vector3(x0 + 0.6, 1.55, 20.42), Vector3(x0 + 0.6, 1.55, 20.428), 0.09, 16, true)
	b.box(hook, Vector3(x0 + 0.61, 1.57, 20.431), Vector3(0.006, 0.075, 0.003), Basis(Vector3(0, 0, 1), -0.5))
	# телевизор на полке-кронштейне: низ модели — её начало координат, полка под всей глубиной корпуса, с косынкой
	var wall_x := x1 - 0.12 if not female else x0 + 0.12
	var si := -1.0 if not female else 1.0
	Props.model(n, "Television_01", Vector3(x1 - 0.4 if not female else x0 + 0.4, 2.32, 22.0), -PI * 0.5 if not female else PI * 0.5, 0.9)
	b.box(hook, Vector3(wall_x + si * 0.21, 2.3, 22.0), Vector3(0.5, 0.04, 0.4))
	b.box(hook, Vector3(wall_x + si * 0.15, 2.155, 22.0), Vector3(0.39, 0.03, 0.03), Basis(Vector3(0, 0, 1), atan2(0.25, si * 0.3)))
	Props.picture(n, "res://tex/gen/sign_rules_short.png", Vector3(x0 + 0.14, 1.9, 27.5), Vector3(1, 0, 0), Vector2(0.6, 0.3))
	if female:
		# валенки Сомовой под скамьёй
		var felt := Mat.m("cloth", {"tint": Color(0.3, 0.28, 0.26)})
		b.box(felt, Vector3(42.0, 0.15, 26.85), Vector3(0.1, 0.3, 0.12))
		b.box(felt, Vector3(42.2, 0.15, 26.8), Vector3(0.1, 0.3, 0.12))
	b.commit(n, "props")


static func _wash(w: World, id: String, female: bool) -> void:
	var n := _n(w, id)
	var body := _b(w, id)
	var r: Rect2 = w.rooms[id]["rect"]
	var x0 := r.position.x
	var x1 := r.end.x
	var b := Geo.Batch.new()
	for k in 3:
		var bx := x0 + 3.5 + k * 3.5
		Props.stone_bench(b, body, Vector3(bx, 0, 14.8), 6.6, false)
	# краны вдоль обеих длинных стен
	var line := id
	var mid := (x0 + x1) * 0.5
	for wall in [x0 + 0.13, x1 - 0.13]:
		var nrm := Vector3(1, 0, 0) if wall < mid else Vector3(-1, 0, 0)
		var ledge := Mat.m("tile_dark", {"wet": 0.7})
		var lx: float = wall + nrm.x * 0.15
		# на стене с двустворчатой дверью в бассейн (проём z 12.2–13.8, наличник до ±0.08) — полка двумя кусками,
		# иначе она шла поперёк проёма на высоте пояса и сквозь створки
		var door_wall: bool = (not female and wall > mid) or (female and wall < mid)
		if door_wall:
			b.box(ledge, Vector3(lx, 0.72, 11.275), Vector3(0.3, 0.06, 1.55))
			b.box(ledge, Vector3(lx, 0.72, 16.525), Vector3(0.3, 0.06, 5.15))
		else:
			b.box(ledge, Vector3(lx, 0.72, 14.8), Vector3(0.3, 0.06, 8.6))
		for i in 6:
			var z := 11.0 + i * 1.5
			if door_wall and absf(z - 13.0) < 1.0:
				continue
			# кран сразу за дверью — не вплотную к наличнику
			if door_wall and absf(z - 14.0) < 0.1:
				z = 14.25
			var t := Props.wall_tap(w, id, Vector3(wall, 1.0, z), nrm, line)
			w.taps.append(t)
	# лужи у каменных лавок и под кранами (мокрый пол блестит — по нему шаги слышнее)
	for i in 7:
		Props.puddle(n, Vector3(randf_range(x0 + 1.2, x1 - 1.2), 0, randf_range(10.4, 18.6)), randf_range(0.9, 1.7))
	for wall in [x0 + 0.6, x1 - 0.6]:
		for i in 3:
			Props.puddle(n, Vector3(wall, 0, 11.5 + i * 3.0), randf_range(0.7, 1.1))
	# шайки
	for i in 5:
		var basin := Items.Basin.new()
		n.add_child(basin)
		basin.global_position = Vector3(x0 + 3.5 + (i % 3) * 3.5, 0.6, 12.0 + i * 1.3)
	# трапы
	Props.drain(w, b, Vector3(x0 + 2.0, 0, 10.0), id)
	Props.drain(w, b, Vector3(x1 - 2.0, 0, 10.0), id)
	Props.drain(w, b, Vector3((x0 + x1) * 0.5, 0, 19.0), id)
	# на глухой стене между дверями в раздевальню (в мужской — левее двери a), а не по центру — там проём
	Props.picture(n, "res://tex/gen/sign_wet.png", Vector3(x0 + 4.7, 1.8, 19.86), Vector3(0, 0, -1), Vector2(0.55, 0.28))
	if female:
		# детская ванночка (оцинковка) стоит на полу: дно и четыре стенки; и ком волос у трапа
		var zinc := Mat.flat(Color(0.62, 0.64, 0.62), 0.45, 0.2)
		var tc := Vector3(x1 - 2.0, 0.0, 18.5)
		b.box(zinc, tc + Vector3(0, 0.01, 0), Vector3(0.76, 0.02, 0.41))
		for side in [-1.0, 1.0]:
			b.box(zinc, tc + Vector3(0, 0.1, side * 0.215), Vector3(0.8, 0.2, 0.02))
			b.box(zinc, tc + Vector3(side * 0.39, 0.1, 0), Vector3(0.02, 0.2, 0.41))
		Props.hair_clump(n, Vector3(x1 - 2.0, 0.0, 10.4), 0.6, false)
		Props.hair_clump(n, Vector3(x1 - 2.3, 0.0, 10.2), 0.4, false)
	b.commit(n, "props")


static func _steam(w: World, id: String, female: bool) -> void:
	var n := _n(w, id)
	var body := _b(w, id)
	var r: Rect2 = w.rooms[id]["rect"]
	var b := Geo.Batch.new()
	var wood := Mat.m("planks_dark", {"tint": Color(0.9, 0.75, 0.55)})
	# полки ступенями вдоль боковой стены
	var wall_x := r.position.x if not female else r.end.x
	var s := 1.0 if not female else -1.0
	var tiers := [[0.45, 2.0], [0.9, 1.35], [1.35, 0.75]]
	# настил полков — доской вдоль полка: мировой трипланар клал швы поперёк (вдоль x, как на полу).
	# Отдельный пакет в узле, повёрнутом на 90° вокруг Y, с трипланаром в осях объекта: локальный x = мировой −z.
	# Узел в (0, 0, 6): мировая точка (x, y, 6) — локальная (0, y, x)
	var top_wood := Mat.m("planks_dark", {"tint": Color(0.9, 0.75, 0.55), "local": true})
	var tn := Node3D.new()
	n.add_child(tn)
	tn.global_position = Vector3(0, 0, 6.0)
	tn.rotation.y = PI * 0.5
	var tb := Geo.Batch.new()
	for t in tiers:
		var depth: float = t[1]
		var cx := wall_x + s * (0.12 + depth * 0.5)
		tb.box(top_wood, Vector3(0.0, t[0], cx), Vector3(5.2, 0.06, depth))
		if t[0] < 0.5:
			# нижний полок: подзор не до пола — снизу щель, из-под полка видно пол парилки и чьи-то ноги
			b.box(wood, Vector3(wall_x + s * (0.12 + depth), 0.34, 6.0), Vector3(0.05, 0.2, 5.2))
		else:
			b.box(wood, Vector3(wall_x + s * (0.12 + depth), t[0] * 0.5, 6.0), Vector3(0.05, t[0], 5.2))
		Geo.col_box(body, Vector3(cx, t[0] * 0.5, 6.0), Vector3(depth, t[0], 5.2))
	tb.commit(tn, "polok")
	# каменка у северной стены; кирпич в натуральный размер (≈25×7.5 см при 1.5 м на повтор) и чуть светлее —
	# при 1.0 он мельчил в полосы, кладка читалась дощатым ящиком
	var stove_x := r.position.x + 4.6 if not female else r.end.x - 4.6
	var brick := Mat.m("brick_red", {"tint": Color(0.68, 0.52, 0.46), "scale": 1.5})
	var iron := Mat.m("rust", {"metal": 0.6, "tint": Color(0.4, 0.36, 0.33)})
	var sc := Vector3(stove_x, 0, 3.62)
	# кладка с цоколем и карнизом, по углам — стальные уголки, сверху — кожух-корзина для камней
	b.box(brick, sc + Vector3(0, 0.5, 0), Vector3(1.3, 1.0, 0.9))
	b.box(brick, sc + Vector3(0, 0.05, 0), Vector3(1.4, 0.1, 1.0))
	b.box(brick, sc + Vector3(0, 1.02, 0), Vector3(1.38, 0.06, 0.98))
	for cx in [-0.66, 0.66]:
		for cz in [-0.46, 0.46]:
			b.box(iron, sc + Vector3(cx, 0.55, cz), Vector3(0.05, 1.1, 0.05))
	for band in [0.35, 0.75]:
		b.box(iron, sc + Vector3(0, band, 0.455), Vector3(1.34, 0.04, 0.02))
	for side in [-1.0, 1.0]:
		b.box(iron, sc + Vector3(side * 0.62, 1.22, 0), Vector3(0.03, 0.36, 0.86))
		b.box(iron, sc + Vector3(0, 1.22, side * 0.42), Vector3(1.26, 0.36, 0.03))
	for k in 6:
		b.box(iron, sc + Vector3(-0.55 + k * 0.22, 1.06, 0), Vector3(0.03, 0.03, 0.84))
	# копоть на стене над кладкой
	Props.soot(n, sc + Vector3(0, 1.85, -0.42), Vector3(0, 0, 1), Vector2(1.5, 1.7))
	# камни: округлые голыши, часть раскалена
	var stone := Mat.flat(Color(0.22, 0.2, 0.19), 0.75)
	var stone2 := Mat.flat(Color(0.3, 0.27, 0.25), 0.7)
	var hot := Mat.flat(Color(0.12, 0.05, 0.03), 0.6, 0.0, {"emission": Color(1.0, 0.4, 0.12), "emission_energy": 2.4})
	for i in 26:
		var lay := float(i) / 26.0
		var p := sc + Vector3(randf_range(-0.5, 0.5), 1.12 + lay * 0.28 + randf() * 0.06, randf_range(-0.32, 0.32))
		var sz := Vector3(randf_range(0.14, 0.24), randf_range(0.1, 0.16), randf_range(0.14, 0.22))
		var m_s: Material = stone if randf() < 0.6 else stone2
		if lay < 0.45 and randf() < 0.22:
			m_s = hot
		b.stone(m_s, p, sz, float(i))
	# бак для воды сбоку и ковш на нём
	var tank_c := sc + Vector3(-0.95 * s, 0, 0)
	b.cyl(iron, tank_c + Vector3(0, 0.0, 0), tank_c + Vector3(0, 0.95, 0), 0.24, 12, true)
	b.cyl(iron, tank_c + Vector3(0, 0.95, 0), tank_c + Vector3(0, 0.99, 0), 0.26, 12, true)
	# ковш стоит на крышке донцем вниз (тёмный круг — вода внутри), ручка — от каменки наружу,
	# раньше уходила сквозь кожух в камни
	var ladle := Mat.m("planks_weather", {"tint": Color(0.55, 0.42, 0.3)})
	b.cyl(ladle, tank_c + Vector3(-0.05 * s, 0.99, -0.03), tank_c + Vector3(-0.05 * s, 1.06, -0.03), 0.07, 8, true)
	b.cyl(stone, tank_c + Vector3(-0.05 * s, 1.06, -0.03), tank_c + Vector3(-0.05 * s, 1.063, -0.03), 0.058, 8, true)
	b.cyl(ladle, tank_c + Vector3(-0.11 * s, 1.05, -0.03), tank_c + Vector3(-0.34 * s, 1.12, 0.08), 0.015, 5)
	Geo.col_box(body, sc + Vector3(0, 0.6, 0), Vector3(1.4, 1.2, 1.0))
	Geo.col_box(body, tank_c + Vector3(0, 0.5, 0), Vector3(0.5, 1.0, 0.5))
	var glow := Items.Fire.new()
	glow.base = 1.3
	# радиус до стены душевой (огонь без тени светил бы сквозь неё)
	glow.omni_range = 3.2
	glow.base *= 1.15
	glow.light_color = Color(1.0, 0.45, 0.18)
	n.add_child(glow)
	glow.global_position = Vector3(stove_x, 1.5, 3.9)
	# веники, ведро
	Props.model(n, "wooden_bucket_02", Vector3(stove_x + 1.0, 0, 4.4), 0.0)
	# веники на колышках у стены напротив полков: черенок-связка сверху, ниже — неровный пук сухой листвы
	# (не плоский тёмный брусок — тот читался щелью в стене)
	var vx := r.end.x - 0.12 if not female else r.position.x + 0.12
	var vin := -s
	var leaf := Mat.m("cloth", {"tint": Color(0.24, 0.25, 0.12), "scale": 0.35})
	for i in 3:
		var vz := 5.0 + i * 0.5
		b.box(iron, Vector3(vx + vin * 0.04, 2.02, vz), Vector3(0.08, 0.025, 0.025))
		b.cyl(ladle, Vector3(vx + vin * 0.06, 2.03, vz), Vector3(vx + vin * 0.075, 1.76, vz), 0.022, 6, true)
		b.stone(leaf, Vector3(vx + vin * 0.085, 1.52, vz), Vector3(0.15, 0.52, 0.27), float(i) * 3.1 + (0.0 if not female else 1.7))
		b.stone(leaf, Vector3(vx + vin * 0.09, 1.38, vz + 0.03), Vector3(0.13, 0.3, 0.22), float(i) * 5.3 + 2.0)
	Props.drain(w, b, Vector3((r.position.x + r.end.x) * 0.5 + s * 1.5, 0, 7.6), id)
	b.commit(n, "props")
	# укрытие под нижним полком
	# точка укрытия — у края нижнего полка: её зона должна торчать из коллизии полка, иначе луч взгляда в неё
	# не попадал и спрятаться под полок было нельзя
	var hs := HideSpot.make_bench(n, Vector3(wall_x + s * 2.3, 0, 7.0), PI * 0.5 if not female else -PI * 0.5)
	w.hides.append(hs)
	w.add_steam(id, 0.35)


static func _showers(w: World, id: String, female: bool) -> void:
	var n := _n(w, id)
	var body := _b(w, id)
	var r: Rect2 = w.rooms[id]["rect"]
	var b := Geo.Batch.new()
	var tile := Mat.m("tile_wall", {"wet": 0.5})
	for side in [0, 1]:
		var wx := r.position.x + 0.13 if side == 0 else r.end.x - 0.13
		var nrm := Vector3(1, 0, 0) if side == 0 else Vector3(-1, 0, 0)
		for i in 3:
			var z := 4.0 + i * 1.5
			var t := Props.shower(w, id, Vector3(wx, 1.25, z), nrm, id)
			w.taps.append(t)
			Props.puddle(n, Vector3(wx + nrm.x * 0.5, 0, z), randf_range(0.8, 1.2))
			# перегородки
			var pz := z + 0.75
			if i < 2:
				b.box(tile, Vector3(wx + nrm.x * 0.6, 0.95, pz), Vector3(1.2, 1.9, 0.08))
				Geo.col_box(body, Vector3(wx + nrm.x * 0.6, 0.95, pz), Vector3(1.2, 1.9, 0.08))
	Props.drain(w, b, Vector3(r.get_center().x - 1.6, 0, 8.3), id)
	Props.drain(w, b, Vector3(r.get_center().x + 1.6, 0, 4.0), id)
	b.commit(n, "props")


# ---------------------------------------------------------------- бассейн

static func pool(w: World) -> void:
	var n := _n(w, "pool")
	var body := _b(w, "pool")
	var b := Geo.Batch.new()
	# мозаичное панно — в полосе штукатурки между кафелем (до 2.2) и потолком (5.0), пропорция 2:1, с бордюром
	Props.picture(n, "res://tex/gen/mosaic.png", Vector3(26.0, 3.6, 6.12), Vector3(0, 0, 1), Vector2(5.2, 2.6), {"rough": 0.4})
	var border := Mat.m("tile_dark", {"wet": 0.3})
	for sy in [-1.0, 1.0]:
		b.box(border, Vector3(26.0, 3.6 + sy * 1.33, 6.135), Vector3(5.32, 0.06, 0.03))
	for sx in [-1.0, 1.0]:
		b.box(border, Vector3(26.0 + sx * 2.63, 3.6, 6.135), Vector3(0.06, 2.6, 0.03))
	Props.bench(b, body, Vector3(20.0, 0, 16.5), 5.0, true, false)
	Props.bench(b, body, Vector3(32.0, 0, 16.5), 5.0, true, false)
	# вышка спасателя
	var wood := Mat.m("planks_weather", {"tint": Color(0.75, 0.7, 0.6)})
	for dx in [-0.35, 0.35]:
		for dz in [-0.3, 0.3]:
			b.box(wood, Vector3(35.5 + dx, 0.9, 15.2 + dz), Vector3(0.06, 1.8, 0.06))
	b.box(wood, Vector3(35.5, 1.8, 15.2), Vector3(0.8, 0.06, 0.7))
	b.box(wood, Vector3(35.5, 2.2, 15.5), Vector3(0.8, 0.8, 0.05))
	Geo.col_box(body, Vector3(35.5, 0.9, 15.2), Vector3(0.8, 1.8, 0.7))
	# световой фонарь в потолке и лунный луч
	var sky := Mat.flat(Color(0.12, 0.15, 0.17), 0.2, 0.0, {"emission": Items.MOON, "emission_energy": 0.7})
	b.box(sky, Vector3(26.0, 4.97, 11.5), Vector3(6.0, 0.03, 3.0))
	var frame := Mat.m("rust", {"metal": 0.5})
	for i in 5:
		b.box(frame, Vector3(23.0 + i * 1.5, 4.95, 11.5), Vector3(0.05, 0.06, 3.0))
	var moon := SpotLight3D.new()
	moon.light_color = Items.MOON
	moon.light_energy = 2.6
	# не даёт серого «мрамора» на ряби: вода отражает фонарь сама (water.gdshader), блик прожектора не нужен
	moon.light_specular = 0.1
	moon.spot_range = 12.0
	moon.spot_angle = 22.0
	# с маской переплёта конус шире (как у окон в builder.gd); раньше 22° ниже затирал 30° и тени рам сбивались к центру
	var sck: Texture2D = Mat.tex("res://tex/gen/cookie_skylight.png")
	if sck:
		moon.light_projector = sck
		moon.spot_angle = 30.0
	moon.light_volumetric_fog_energy = 2.5
	moon.shadow_enabled = false
	n.add_child(moon)
	moon.global_position = Vector3(26.0, 4.9, 11.5)
	moon.rotation = Vector3(-PI * 0.5 + 0.15, 0, 0.1)
	Props.drain(w, b, Vector3(15.5, 0, 7.2), "pool")
	Props.drain(w, b, Vector3(36.5, 0, 7.2), "pool")
	Props.drain(w, b, Vector3(26.0, 0, 16.3), "pool")
	# решётка слива в глубокой части и люк
	b.box(Mat.m("grate", {"metal": 0.6, "scale": 0.4}), Vector3(32.2, Layout.POOL_DEEP + 0.01, 11.5), Vector3(0.5, 0.02, 0.5))
	b.commit(n, "props")


# ---------------------------------------------------------------- технический коридор, насосная

static func service(w: World) -> void:
	var n := _n(w, "service")
	var body := _b(w, "service")
	var b := Geo.Batch.new()
	var rust := Mat.m("rust", {"metal": 0.5})
	# изоляция — грязная мешковина с потёками (слой возраста только на среднем/высоком качестве), не белый пластик
	var insul := Mat.m("cloth", {"tint": Color(0.4, 0.37, 0.31), "scale": 0.5, "age": "wall", "age_y": 0.0, "age_h": 3.0})
	# магистрали под потолком и у пола
	b.cyl(insul, Vector3(0.2, 2.55, 0.35), Vector3(51.8, 2.55, 0.35), 0.13, 10)
	# проволочные бандажи на изоляции
	for k in 34:
		var bx := 1.0 + k * 1.5
		b.cyl(rust, Vector3(bx - 0.015, 2.55, 0.35), Vector3(bx + 0.015, 2.55, 0.35), 0.134, 10)
	b.cyl(rust, Vector3(0.2, 2.2, 0.32), Vector3(51.8, 2.2, 0.32), 0.07, 10)
	# нижняя труба вдоль южной стены — участками: в проёмах (двери, лестница) уходит под пол, топки обходит
	var gaps := [[3.85, 5.35], [46.65, 48.15]]
	for d in Layout.DOORS:
		var dp: Vector2 = d[2]
		if (d[0] == "service" or d[1] == "service") and absf(dp.y - 3.0) < 0.01:
			var hw: float = float(d[3]) * 0.5 + 0.12
			gaps.append([dp.x - hw, dp.x + hw])
	gaps.sort_custom(func(a, c): return a[0] < c[0])
	# первый участок выходит из западной стены, последний уходит в восточную, остальные концы — в пол
	var seg_a := -1.0
	for g in gaps:
		var g0: float = g[0]
		var g1: float = g[1]
		# у проёмов труба уходит в стену (+z), а не в пол — из проёма не видно обрубков
		var pts := [Vector3(0.0, 0.35, 2.7)] if seg_a < 0.0 else [Vector3(seg_a, 0.35, 3.1), Vector3(seg_a, 0.35, 2.7)]
		pts.append(Vector3(g0, 0.35, 2.7))
		pts.append(Vector3(g0, 0.35, 3.1))
		Props.pipe(b, pts, 0.06, rust)
		seg_a = g1
	Props.pipe(b, [Vector3(seg_a, 0.35, 3.1), Vector3(seg_a, 0.35, 2.7), Vector3(52.0, 0.35, 2.7)], 0.06, rust)
	# кронштейны: стойка у стены, полки под обеими трубами, хомуты; мельче и темнее ржавчина — на тонкой
	# детали крупный трипланар не давал рисунка, кронштейн читался белой доской. Над решёткой в подвал — без кронштейна
	var brk := Mat.m("rust", {"metal": 0.5, "scale": 0.3, "tint": Color(0.55, 0.45, 0.4)})
	for x in range(2, 52, 4):
		if absf(x - 25.25) < 1.0:
			continue
		b.box(brk, Vector3(x, 2.29, 0.13), Vector3(0.05, 0.36, 0.02))
		b.box(brk, Vector3(x, 2.4, 0.31), Vector3(0.05, 0.04, 0.38))
		b.box(brk, Vector3(x, 2.115, 0.27), Vector3(0.05, 0.03, 0.3))
		b.cyl(brk, Vector3(x - 0.02, 2.55, 0.35), Vector3(x + 0.02, 2.55, 0.35), 0.14, 10)
		b.cyl(brk, Vector3(x - 0.015, 2.2, 0.32), Vector3(x + 0.015, 2.2, 0.32), 0.078, 8)
	# топки каменок со стороны коридора
	for sx in [4.6, 47.4]:
		var brick := Mat.m("brick_red", {"tint": Color(0.5, 0.4, 0.35)})
		b.box(brick, Vector3(sx, 0.75, 2.75), Vector3(1.4, 1.5, 0.3))
		# коллизия топки — с решёткой и пастью (z от 2.54): иначе капсула у стены ставила камеру в кладку и огонь
		Geo.col_box(body, Vector3(sx, 0.75, 2.72), Vector3(1.4, 1.5, 0.36))
		b.box(Mat.flat(Color(0.12, 0.1, 0.09), 0.5, 0.8), Vector3(sx, 0.6, 2.58), Vector3(0.5, 0.42, 0.05))
		Items.fire_mouth(n, Vector3(sx, 0.6, 2.555), Vector3(0, 0, -1), Vector2(0.44, 0.36), 1.4)
		var f := Items.Fire.new()
		f.base = 1.6
		f.omni_range = 3.3
		f.base *= 1.2
		n.add_child(f)
		f.global_position = Vector3(sx, 0.7, 2.2)
		Props.soot(n, Vector3(sx, 1.45, 2.74), Vector3(0, 0, -1), Vector2(1.1, 1.5))
		# уголь у топки, лопата
		b.box(Mat.m("coal"), Vector3(sx + 1.2, 0.12, 2.3), Vector3(0.9, 0.25, 0.8), Basis(Vector3.UP, 0.3))
		Geo.col_box(body, Vector3(sx + 1.2, 0.12, 2.3), Vector3(0.9, 0.25, 0.8), Basis(Vector3.UP, 0.3))
		# начало модели лопаты — посреди черенка (штык −0.5…0): поднята почти на 0.5, чтобы штык стоял на полу.
		# Перед стеной на x sx − 1 идёт нижняя труба (z 2.64…2.76, y 0.35): штык прислонён к ней, а не проходит
		# сквозь неё; верх черенка (z ~2.8) не доходит до стены
		var spade := Props.model(n, "rusted_spade_01", Vector3(sx - 1.0, 0.48, 2.63), 0.2)
		spade.rotation.x = 0.3
	Props.picture(n, "res://tex/gen/sign_tech.png", Vector3(11.0, 2.4, 2.86), Vector3(0, 0, -1), Vector2(0.7, 0.35))
	# та же табличка со стороны мужской душевой: оттуда дверь с кодом была безымянной
	Props.picture(_n(w, "m_shower"), "res://tex/gen/sign_tech.png", Vector3(11.0, 2.4, 3.14), Vector3(0, 0, 1), Vector2(0.7, 0.35))
	Props.picture(n, "res://tex/gen/sign_kotelnaya.png", Vector3(23.8, 2.0, 0.14), Vector3(0, 0, 1), Vector2(0.7, 0.2))
	Props.picture(n, "res://tex/gen/sign_pump.png", Vector3(34.0, 2.35, 2.86), Vector3(0, 0, -1), Vector2(0.6, 0.17))
	Props.model(n, "wooden_ladder", Vector3(20.0, 0, 0.35), 0.0, 1.0, true)
	Props.model(n, "wooden_crate_01", Vector3(38.0, 0, 0.6), 0.5, 1.0, true)
	Props.drain(w, b, Vector3(16.0, 0, 1.5), "service")
	Props.drain(w, b, Vector3(36.0, 0, 1.5), "service")
	b.commit(n, "props")
	# отсвет топки внизу лестницы
	var glow := Items.Fire.new()
	glow.base = 2.2
	glow.omni_range = 7.0
	n.add_child(glow)
	glow.global_position = Vector3(25.25, -3.8, -6.0)
	# ниша у лестницы: склад
	var sw := _n(w, "stairwell")
	Props.model(sw, "wooden_crate_02", Vector3(24.0, 0, 5.3), 0.2, 1.0, true)
	Props.model(sw, "wooden_crate_01", Vector3(27.0, 0, 5.2), -0.3, 1.0, true)
	Props.model(sw, "cement_bag", Vector3(25.5, 0, 5.4), 0.0)
	# насосная
	var p := _n(w, "pump")
	var pb := Geo.Batch.new()
	# двигатели — гладкая крашеная сталь (у rust_paint вертикальный гофр: на лежачем барабане он давал обручи бочки),
	# станины — ржавые, чтобы корпус и основание читались разными деталями
	var motor := Mat.m("metal_green", {"metal": 0.4, "scale": 1.0})
	for px in [31.4, 32.9]:
		pb.cyl(motor, Vector3(px - 0.4, 0.45, 4.6), Vector3(px + 0.4, 0.45, 4.6), 0.3, 14, true)
		pb.box(rust, Vector3(px, 0.15, 4.6), Vector3(1.0, 0.3, 0.6))
		Geo.col_box(_b(w, "pump"), Vector3(px, 0.45, 4.6), Vector3(1.0, 0.9, 0.7))
	# стояки уходят в потолок (3.0), а не обрываются под ним
	Props.pipe(pb, [Vector3(31.2, 0.45, 4.6), Vector3(30.6, 0.45, 4.6), Vector3(30.6, 3.02, 4.6)], 0.08, rust)
	Props.pipe(pb, [Vector3(36.7, 0.0, 3.4), Vector3(36.7, 3.02, 3.4)], 0.12, rust)
	# стояки твёрдые: первый закрывает щель между западной стеной и двигателем, второй стоит у южной стены
	Geo.col_box(_b(w, "pump"), Vector3(30.6, 1.5, 4.6), Vector3(0.16, 3.0, 0.16))
	Geo.col_box(_b(w, "pump"), Vector3(36.7, 1.5, 3.4), Vector3(0.26, 3.0, 0.26))
	pb.commit(p, "props")
	Props.picture(p, "res://tex/gen/sign_wet.png", Vector3(37.86, 1.9, 4.6), Vector3(-1, 0, 0), Vector2(0.5, 0.25))


# ---------------------------------------------------------------- женское отделение

static func women(w: World) -> void:
	_locker_room(w, "f_lock", true)
	_wash(w, "f_wash", true)
	_steam(w, "f_steam", true)
	_showers(w, "f_shower", true)
	# сушуарная: кресла с колпаками
	var d := _n(w, "f_dry")
	var b := Geo.Batch.new()
	# колпак — круглый, с куполом и тёмным зевом снизу, на стойке с основанием позади спинки стула.
	# Всё западнее подоконника восточного окна (x ≥ 51.685, y 1.545–1.595): колпаки в него врезались,
	# а стойка проходила сквозь спинку. Низ колпака (1.30) — над спинкой стула (1.264)
	var shell := Mat.flat(Color(0.75, 0.72, 0.62), 0.35, 0.0)
	var pole := Mat.flat(Color(0.4, 0.4, 0.38), 0.4, 0.8)
	var mouth := Mat.flat(Color(0.05, 0.05, 0.05), 0.8)
	for i in 3:
		var z := 20.7 + i * 1.1
		Props.model(d, "painted_wooden_chair_02", Vector3(51.25, 0, z), -PI * 0.5)
		b.cyl(pole, Vector3(51.65, 0.0, z), Vector3(51.65, 0.03, z), 0.14, 10, true)
		b.cyl(pole, Vector3(51.65, 0.03, z), Vector3(51.65, 1.47, z), 0.022, 8, true)
		b.cyl(pole, Vector3(51.66, 1.45, z), Vector3(51.56, 1.45, z), 0.018, 6)
		b.cyl(shell, Vector3(51.38, 1.3, z), Vector3(51.38, 1.56, z), 0.2, 16, true)
		b.cone(shell, Vector3(51.38, 1.56, z), Vector3(51.38, 1.64, z), 0.2, 16)
		b.cyl(mouth, Vector3(51.38, 1.295, z), Vector3(51.38, 1.3, z), 0.17, 16, true)
	b.commit(d, "props")
	# комната банщицы
	var a := _n(w, "f_attend")
	var ab := Geo.Batch.new()
	# кровать повёрнута длинной стороной вдоль x (yaw −π/2): матрас тоже вдоль x, между спинками
	# (внутри рамы x 50.15–51.85, ширина 0.8), на сетке (у модели верх сетки 0.50 → 0.45 при масштабе 0.9).
	# Подушка у изголовья (восток), шерстяное одеяло — на ногах
	Props.model(a, "old_bed_frame", Vector3(51.0, 0, 28.6), -PI * 0.5, 0.9, true)
	var mattress := Mat.m("cloth", {"tint": Color(0.6, 0.55, 0.5)})
	ab.box(mattress, Vector3(51.0, 0.515, 28.6), Vector3(1.68, 0.12, 0.78))
	ab.box(mattress, Vector3(51.6, 0.62, 28.6), Vector3(0.34, 0.09, 0.56))
	ab.box(Mat.m("cloth", {"tint": Color(0.32, 0.28, 0.24), "scale": 0.6}), Vector3(50.62, 0.585, 28.6), Vector3(0.95, 0.025, 0.82))
	Props.model(a, "painted_wooden_table", Vector3(49.8, 0, 25.0), 0.0, 1.0, true)
	Props.model(a, "painted_wooden_chair_01", Vector3(49.8, 0, 25.7), PI)
	# столешница — 0.958 (у модели начало координат — дно)
	Props.model(a, "vintage_electric_kettle", Vector3(50.4, 0.96, 24.85), 1.0)
	Props.model(a, "vintage_radio_transceiver", Vector3(51.6, 0, 25.0), -PI * 0.5)
	Props.salt(ab, Vector3(48.32, 0, 27.0), false, 1.0)
	ab.commit(a, "props")
