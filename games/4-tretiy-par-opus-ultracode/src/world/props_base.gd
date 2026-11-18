class_name PropsBase
## Обстановка подвала (котельная, коллектор, сруб…) и двора.

const Y := Layout.BASE_Y


static func build(w: World) -> void:
	collector(w)
	boiler(w)
	stoker(w)
	meter(w)
	coal(w)
	banya(w)


static func _n(w: World, id: String) -> Node3D:
	return w.rooms[id]["node"]


static func _b(w: World, id: String) -> StaticBody3D:
	return w.rooms[id]["body"]


## Сухой поддон / мостки: ходить тихо.
static func pallet(w: World, b: Geo.Batch, body: StaticBody3D, rect: Rect2) -> void:
	var h := 0.15
	var c := Vector3(rect.get_center().x, Y + h * 0.5, rect.get_center().y)
	# доски поперёк
	var along_x := rect.size.x > rect.size.y
	# мировой трипланар не следует за доской: у planks_weather волокно идёт вдоль z, у planks_dark — вдоль x.
	# Доски, лежащие вдоль x, берут planks_dark (тон подобран под planks_weather), иначе их через каждые
	# 20 см пересекают тёмные швы текстуры, будто доска собрана из брусков
	var wood := Mat.m("planks_weather", {"tint": Color(0.5, 0.42, 0.33), "wet": 0.3}) if along_x else Mat.m("planks_dark", {"tint": Color(0.5, 0.4, 0.31), "wet": 0.3})
	var n := int((rect.size.x if along_x else rect.size.y) / 0.16)
	for i in n:
		var t := -0.5 + (i + 0.5) / n
		var p := c + (Vector3(t * rect.size.x, h * 0.5 - 0.015, 0) if along_x else Vector3(0, h * 0.5 - 0.015, t * rect.size.y))
		b.box(wood, p, Vector3(0.13, 0.03, rect.size.y) if along_x else Vector3(rect.size.x, 0.03, 0.13))
	b.box(Mat.m("planks_dark"), c + Vector3(0, -0.02, 0), Vector3(rect.size.x * 0.9, h - 0.04, rect.size.y * 0.9))
	Geo.col_box(body, c, Vector3(rect.size.x, h, rect.size.y))
	w.dry_rects.append({"rect": rect, "y": Y + h})


# ---------------------------------------------------------------- коллектор — её логово

static func collector(w: World) -> void:
	var n := _n(w, "collector")
	var b := Geo.Batch.new()
	var rust := Mat.m("rust", {"metal": 0.5})
	# у проёма в котельную трубы коленом уходят в боковые стены, а не торчат открытыми концами в проём
	Props.pipe(b, [Vector3(30.25, Y + 1.6, 11.9), Vector3(30.25, Y + 1.6, -6.6), Vector3(29.95, Y + 1.6, -6.6)], 0.09, rust)
	Props.pipe(b, [Vector3(31.8, Y + 0.3, 11.9), Vector3(31.8, Y + 0.3, -6.6), Vector3(32.05, Y + 0.3, -6.6)], 0.06, rust)
	# волосы свисают с потолка гуще к середине
	for i in 22:
		var z := randf_range(-5.0, 10.5)
		var dens := 1.0 - absf(z - 3.0) / 8.0
		if randf() > dens + 0.2:
			continue
		Props.hair_clump(n, Vector3(randf_range(30.5, 31.7), Y + 1.98, z), randf_range(0.6, 1.5), true)
	for i in 8:
		Props.hair_clump(n, Vector3(randf_range(30.3, 31.7), Y + 0.16, randf_range(1.0, 5.0)), randf_range(0.5, 1.0), false)
	# вещи пропавших: серая куртка, ушанка, отцовские сапоги. Лежат в воде наполовину: ни одна грань не на
	# уровне воды (Y+0.16), иначе она спорит с плоскостью воды по глубине и мерцает
	var cloth := Mat.m("cloth", {"tint": Color(0.35, 0.35, 0.33), "wet": 0.6})
	var fur := Mat.m("cloth", {"tint": Color(0.3, 0.25, 0.2)})
	# куртка комом: спинка, задранный воротник, рукава раскинуты
	var jb := Basis(Vector3.UP, 0.4)
	var jc := Vector3(30.6, Y + 0.155, 2.5)
	b.box(cloth, jc, Vector3(0.46, 0.07, 0.5), jb * Basis(Vector3.RIGHT, 0.05))
	b.box(cloth, jc + jb * Vector3(0.0, 0.025, -0.27), Vector3(0.32, 0.07, 0.1), jb * Basis(Vector3.RIGHT, -0.25))
	b.cyl(cloth, jc + jb * Vector3(-0.21, -0.01, -0.19), jc + jb * Vector3(-0.4, -0.01, 0.13), 0.055, 8, true)
	b.cyl(cloth, jc + jb * Vector3(0.21, -0.01, -0.19), jc + jb * Vector3(0.36, -0.015, -0.43), 0.05, 8, true)
	# ушанка: меховой околыш, суконный верх, уши свисают по бокам
	var hc := Vector3(31.5, Y, 4.2)
	b.cyl(fur, hc, hc + Vector3(0, 0.2, 0), 0.135, 10, true)
	b.cyl(cloth, hc + Vector3(0, 0.19, 0), hc + Vector3(0, 0.25, 0), 0.105, 10, true)
	for s in [-1.0, 1.0]:
		b.box(fur, hc + Vector3(s * 0.15, 0.13, 0.0), Vector3(0.03, 0.12, 0.14), Basis(Vector3.BACK, s * 0.35))
	# в модели две пары (чистая и грязная) — в коллектор только грязную, на место всей модели
	var boots := Props.model(n, "rubber_boots", Vector3(31.3, Y, 3.2), 1.2)
	if not boots.find_children("*dirt*", "MeshInstance3D", true, false).is_empty():
		for c in boots.find_children("*", "MeshInstance3D", true, false):
			if not String(c.name).contains("dirt"):
				c.queue_free()
		boots.translate_object_local(Vector3(-0.3, 0, 0))
	Props.drain(w, b, Vector3(31.0, Y, 8.0), "collector")
	Props.drain(w, b, Vector3(31.0, Y, -3.0), "collector")
	# лестница к люку в дне бассейна
	var lad := Mat.m("rust", {"metal": 0.6})
	for dx in [-0.22, 0.22]:
		b.cyl(lad, Vector3(31.0 + dx, Y, 11.85), Vector3(31.0 + dx, Y + 2.0, 11.85), 0.02, 6)
	for k in 6:
		b.cyl(lad, Vector3(30.78, Y + 0.3 + k * 0.3, 11.85), Vector3(31.22, Y + 0.3 + k * 0.3, 11.85), 0.015, 6)
	b.commit(n, "props")


# ---------------------------------------------------------------- котельная

static func boiler(w: World) -> void:
	var n := _n(w, "boiler")
	var body := _b(w, "boiler")
	var b := Geo.Batch.new()
	var steel := Mat.m("rust", {"metal": 0.55, "tint": Color(0.5, 0.46, 0.43)})
	var brick := Mat.m("brick_red", {"tint": Color(0.45, 0.35, 0.3)})
	var rust := Mat.m("rust", {"metal": 0.5})
	var iron := Mat.flat(Color(0.1, 0.09, 0.08), 0.5, 0.8)
	var dial := Mat.flat(Color(0.62, 0.6, 0.53), 0.4)
	var red := Mat.flat(Color(0.8, 0.05, 0.05), 0.4)
	for bx in [20.0, 27.0]:
		# кирпичная топка-основание и лежачий барабан котла
		b.box(brick, Vector3(bx, Y + 0.7, -14.0), Vector3(2.6, 1.4, 5.0))
		b.cyl(steel, Vector3(bx, Y + 2.3, -16.2), Vector3(bx, Y + 2.3, -11.6), 1.05, 18, true)
		for k in 5:
			var z := -16.0 + k * 1.1
			b.cyl(rust, Vector3(bx, Y + 2.3, z), Vector3(bx, Y + 2.3, z + 0.06), 1.08, 18)
		Geo.col_box(body, Vector3(bx, Y + 1.7, -14.0), Vector3(2.6, 3.4, 5.0))
		# дверцы топки с огнём
		b.box(iron, Vector3(bx, Y + 0.7, -11.47), Vector3(0.8, 0.6, 0.05))
		Items.fire_mouth(n, Vector3(bx, Y + 0.7, -11.43), Vector3(0, 0, 1), Vector2(0.7, 0.5), 1.8)
		var f := Items.Fire.new()
		f.base = 4.0
		f.omni_range = 12.0
		# свой блик огню не нужен: отражение пасти на воде даёт зеркало воды, а блик без тени лез из-за кирпича
		f.light_specular = 0.0
		n.add_child(f)
		f.light_color = Items.FIRE
		f.global_position = Vector3(bx, Y + 0.9, -10.9)
		Props.soot(n, Vector3(bx, Y + 1.25, -11.5), Vector3(0, 0, 1), Vector2(1.0, 0.9))
		# труба к борову: конец уходит в северную стену (грань z −17.88), у стены — манжета
		Props.pipe(b, [Vector3(bx, Y + 3.3, -15.0), Vector3(bx, Y + 3.9, -15.0), Vector3(bx, Y + 3.9, -17.95)], 0.25, rust)
		b.cyl(rust, Vector3(bx, Y + 3.9, -17.9), Vector3(bx, Y + 3.9, -17.82), 0.29, 10, true)
		# манометр на боку барабана, лицом к проходу (+x): корпус врезан в барабан, на эмали — деления по ходу
		# стрелки (поворот вокруг оси x от 0.8 до −2.6), последние два красные. Плоскость циферблата — bx + 1.14,
		# стрелка первого котла (сценарий) висит перед ней на bx + 1.15
		var gc := Vector3(bx + 1.14, Y + 2.4, -11.9)
		b.cyl(iron, Vector3(bx + 0.98, Y + 2.4, -11.9), Vector3(bx + 1.13, Y + 2.4, -11.9), 0.14, 24, true)
		b.cyl(dial, Vector3(bx + 1.1, Y + 2.4, -11.9), gc, 0.12, 24, true)
		for k in 8:
			var tb := Basis(Vector3.RIGHT, lerpf(0.8, -2.6, k / 7.0))
			b.box(red if k >= 6 else iron, gc + Vector3(0.0015, 0, 0) + tb * Vector3(0, 0.098, 0), Vector3(0.003, 0.022, 0.005), tb)
		b.box(iron, gc + Vector3(0.004, 0, 0), Vector3(0.008, 0.018, 0.018))
		if bx > 25.0:
			# у второго котла стрелка неподвижна: ходит только стрелка первого, её ставит сценарий
			var nb := Basis(Vector3.RIGHT, 0.35)
			b.box(red, gc + Vector3(0.008, 0, 0) + nb * Vector3(0, 0.035, 0), Vector3(0.006, 0.09, 0.01), nb)
	# уголь у топок — невысокая куча, а не плита; не заходит на мостки (x < 24.5, z > −10.4). Тачка, лопаты
	var coal_m := Mat.m("coal")
	b.stone(coal_m, Vector3(23.35, Y - 0.05, -9.3), Vector3(1.7, 1.1, 1.3), 1.0)
	b.stone(coal_m, Vector3(22.8, Y - 0.04, -9.05), Vector3(0.95, 0.66, 0.8), 2.0)
	b.stone(coal_m, Vector3(23.9, Y - 0.03, -9.65), Vector3(0.7, 0.46, 0.6), 3.0)
	for p in [Vector3(22.15, Y, -9.6), Vector3(24.3, Y, -8.85), Vector3(23.0, Y, -8.45), Vector3(24.05, Y, -10.2), Vector3(22.5, Y, -10.1)]:
		var s := randf_range(0.12, 0.22)
		b.box(coal_m, p + Vector3(0, s * 0.25, 0), Vector3(s, s * 0.7, s * 0.9), Basis.from_euler(Vector3(randf_range(-0.5, 0.5), randf() * TAU, randf_range(-0.5, 0.5))))
	Geo.col_box(body, Vector3(23.3, Y + 0.2, -9.3), Vector3(1.6, 0.4, 1.2))
	# лопата воткнута в кучу: штык (−0.5…0 от начала модели) целиком в угле, наружу — черенок
	Props.model(n, "rusted_spade_01", Vector3(22.6, Y + 0.1, -9.15), 1.1)
	# вторая лопата прислонена к боку второго котла (грань x 28.3): начало модели на 0.5 выше пола — штык
	# стоит на полу, а не уходит под него; плоскость штыка вдоль котла, черенок наклонён к кирпичу
	var spade := Props.model(n, "rusted_spade_01", Vector3(28.45, Y + 0.5, -12.2), PI * 0.5)
	spade.rotation.x = -0.2
	Props.model(n, "metal_stool_01", Vector3(29.5, Y, -9.0), 0.4)
	# трубы по потолку
	b.cyl(rust, Vector3(16.2, Y + 3.8, -8.0), Vector3(31.8, Y + 3.8, -8.0), 0.12, 10)
	b.cyl(rust, Vector3(16.2, Y + 3.5, -17.5), Vector3(31.8, Y + 3.5, -17.5), 0.1, 10)
	# сухие мостки: от лестницы к комнатам
	pallet(w, b, body, Rect2(24.5, -10.0, 1.5, 2.9))   # низ лестницы
	pallet(w, b, body, Rect2(16.2, -11.6, 8.3, 1.2))   # к истопнику
	pallet(w, b, body, Rect2(16.2, -16.6, 1.2, 5.0))   # к водомеру
	pallet(w, b, body, Rect2(25.9, -8.9, 5.9, 1.4))    # к коллектору и срубу
	pallet(w, b, body, Rect2(30.6, -15.2, 1.2, 6.3))   # к бункеру
	Props.drain(w, b, Vector3(18.0, Y, -8.0), "boiler")
	Props.drain(w, b, Vector3(30.5, Y, -17.0), "boiler")
	Props.drain(w, b, Vector3(23.5, Y, -16.8), "boiler")
	b.commit(n, "props")


# ---------------------------------------------------------------- комната истопника

static func stoker(w: World) -> void:
	var n := _n(w, "stoker")
	var body := _b(w, "stoker")
	var b := Geo.Batch.new()
	Props.model(n, "old_bed_frame", Vector3(11.0, Y, -12.2), 0.0, 0.9, true)
	# матрас лежит на боковинах рамы между спинками (рама при масштабе 0.9 — 0.81 × 1.8 м, спинки на ±0.85),
	# у изголовья (север) подушка, в ногах — солдатское одеяло, свисает по бокам
	var bedding := Mat.m("cloth", {"tint": Color(0.4, 0.38, 0.32)})
	b.box(bedding, Vector3(11.0, Y + 0.52, -12.2), Vector3(0.74, 0.12, 1.66))
	b.box(bedding, Vector3(11.0, Y + 0.62, -12.83), Vector3(0.5, 0.09, 0.3), Basis(Vector3.RIGHT, 0.12))
	var blanket := Mat.m("cloth", {"tint": Color(0.26, 0.27, 0.22), "scale": 0.5})
	b.box(blanket, Vector3(11.0, Y + 0.6, -11.85), Vector3(0.78, 0.04, 0.95))
	for s in [-1.0, 1.0]:
		b.box(blanket, Vector3(11.0 + s * 0.39, Y + 0.53, -11.85), Vector3(0.015, 0.18, 0.95))
	# столешница painted_wooden_table — на Y + 0.958 (под неё же подняты журнал и батарейки в сценарии);
	# будильник и свеча стоят на ней, а не утоплены в доску на 0.78. Воск свечи случайной высоты 0.12..0.18
	# центрирован на +0.07, низ — от −0.02 до +0.01: при Y + 0.948 он всегда касается доски (до 3 см в ней)
	Props.model(n, "painted_wooden_table", Vector3(13.5, Y, -8.7), 0.0, 1.0, true)
	Props.model(n, "wooden_stool_01", Vector3(13.5, Y, -9.5), 0.3)
	Props.model(n, "vintage_radio_transceiver", Vector3(15.4, Y, -9.0), -PI * 0.5)
	Props.model(n, "alarm_clock_01", Vector3(14.2, Y + 0.96, -8.55), 2.5)
	Items.candle(n, Vector3(12.9, Y + 0.948, -8.6))
	Props.picture(n, "res://tex/gen/calendar.png", Vector3(13.0, Y + 1.7, -13.86), Vector3(0, 0, 1), Vector2(0.32, 0.45))
	# шкаф с отцовским ватником: спиной к восточной стене, дверцы смотрят в комнату (−x, грань x 15.2)
	b.box(Mat.m("planks_weather", {"tint": Color(0.55, 0.5, 0.42)}), Vector3(15.5, Y + 0.95, -13.4), Vector3(0.6, 1.9, 0.8))
	var wood_d := Mat.m("planks_weather", {"tint": Color(0.4, 0.36, 0.3)})
	b.box(wood_d, Vector3(15.5, Y + 0.05, -13.4), Vector3(0.63, 0.1, 0.83))
	b.box(wood_d, Vector3(15.5, Y + 1.93, -13.4), Vector3(0.66, 0.06, 0.86))
	for dz in [-0.2, 0.2]:
		b.box(wood_d, Vector3(15.192, Y + 1.0, -13.4 + dz), Vector3(0.016, 1.6, 0.36))
	var fittings := Mat.flat(Color(0.07, 0.06, 0.05), 0.55, 0.6)
	b.box(fittings, Vector3(15.19, Y + 1.0, -13.4), Vector3(0.02, 1.7, 0.012))
	for dz in [-0.035, 0.035]:
		b.box(fittings, Vector3(15.17, Y + 1.05, -13.4 + dz), Vector3(0.03, 0.11, 0.018))
	Geo.col_box(body, Vector3(15.5, Y + 0.95, -13.4), Vector3(0.6, 1.9, 0.8))
	Props.salt(b, Vector3(15.75, Y, -11.0), false, 1.0)
	b.commit(n, "props")


# ---------------------------------------------------------------- водомерный узел

static func meter(w: World) -> void:
	var n := _n(w, "meter")
	var body := _b(w, "meter")
	var b := Geo.Batch.new()
	# крашеная сталь, а не профлист rust_paint: его вертикальные гофры на трубе вдоль x ложились кольцами
	# («гофрошланг»), а тёмный оттенок с металличностью 0.5 давал почти чёрную трубу вне луча фонаря
	var pipe := Mat.m("rust", {"metal": 0.3, "tint": Color(0.6, 0.66, 0.78)})
	# ввод из стены → задвижка → водомер → в котельную; стояк уходит в перекрытие (потолок — Y + 3.0)
	var PZ := -17.2
	b.cyl(pipe, Vector3(10.1, Y + 0.9, PZ), Vector3(15.9, Y + 0.9, PZ), 0.16, 14)
	b.cyl(pipe, Vector3(15.9, Y + 0.9, PZ), Vector3(15.9, Y + 3.05, PZ), 0.16, 14)
	# корпус задвижки
	var body_m := Mat.m("rust", {"metal": 0.6, "tint": Color(0.7, 0.55, 0.5)})
	b.box(body_m, Vector3(12.0, Y + 0.95, PZ), Vector3(0.5, 0.6, 0.55))
	b.cyl(body_m, Vector3(12.0, Y + 1.25, PZ), Vector3(12.0, Y + 1.75, PZ), 0.07, 10)
	# водомер: крашеный чугун с фланцами (раньше — гладкий тёмный куб, на котором белый диск будто висел
	# в воздухе); циферблат — состаренная эмаль в металлическом ободке, с делениями
	var meter_m := Mat.m("metal_green", {"metal": 0.25, "tint": Color(1.2, 1.25, 1.3)})
	b.box(meter_m, Vector3(14.2, Y + 0.95, PZ), Vector3(0.45, 0.42, 0.42))
	for fx in [-0.24, 0.24]:
		b.cyl(pipe, Vector3(14.2 + fx - 0.015, Y + 0.9, PZ), Vector3(14.2 + fx + 0.015, Y + 0.9, PZ), 0.21, 14, true)
	b.cyl(Mat.flat(Color(0.62, 0.6, 0.53), 0.4), Vector3(14.2, Y + 1.16, PZ), Vector3(14.2, Y + 1.18, PZ), 0.14, 24, true)
	for k in 12:
		var rb := Basis(Vector3.UP, TAU * k / 12.0)
		b.box(pipe, Vector3(14.2, Y + 1.17, PZ) + rb * Vector3(0, 0, 0.152), Vector3(0.085, 0.03, 0.024), rb)
	var ink := Mat.flat(Color(0.08, 0.07, 0.06), 0.6)
	for k in 10:
		var rb := Basis(Vector3.UP, TAU * k / 10.0)
		b.box(ink, Vector3(14.2, Y + 1.1815, PZ) + rb * Vector3(0, 0, 0.112), Vector3(0.006, 0.003, 0.024), rb)
	Geo.col_box(body, Vector3(13.0, Y + 0.9, PZ), Vector3(5.8, 0.6, 0.6))
	Props.picture(n, "res://tex/gen/sign_vvod.png", Vector3(12.0, Y + 2.1, -17.86), Vector3(0, 0, 1), Vector2(0.6, 0.3))
	b.commit(n, "props")
	Props.model(n, "vintage_oil_lamp", Vector3(13.1, Y + 1.07, -17.2), 0.4)
	var lamp := Items.Fire.new()
	lamp.base = 0.55
	lamp.omni_range = 3.6
	n.add_child(lamp)
	lamp.light_color = Items.CANDLE
	lamp.global_position = Vector3(13.1, Y + 1.35, -17.05)
	# стрелка водомера крутится
	var hand := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.012, 0.004, 0.11)
	hand.mesh = bm
	hand.material_override = Mat.flat(Color(0.7, 0.05, 0.05), 0.5)
	n.add_child(hand)
	hand.global_position = Vector3(14.2, Y + 1.19, -17.2)
	w.set_meta("meter_hand", hand)


# ---------------------------------------------------------------- угольный бункер

static func coal(w: World) -> void:
	var n := _n(w, "coal")
	var body := _b(w, "coal")
	var b := Geo.Batch.new()
	var cm := Mat.m("coal", {"scale": 1.0})
	# куча угля поднимается к люку у северной стены
	var ramp_len := 5.4
	var rise := 2.7
	var ang := atan2(rise, ramp_len)
	var mid := Vector3(35.0, Y + rise * 0.5 - 0.1, -14.6)
	var basis := Basis(Vector3.RIGHT, ang)
	var slope_l := sqrt(ramp_len * ramp_len + rise * rise)
	b.box(cm, mid, Vector3(4.0, 0.4, slope_l), basis)
	Geo.col_box(body, mid, Vector3(4.0, 0.4, slope_l), basis)
	# площадка у люка (визуально на 1 см уже откоса: их боковые грани не совпадают и не мерцают)
	b.box(cm, Vector3(35.0, Y + rise - 0.2, -17.5), Vector3(3.98, 0.4, 0.8))
	Geo.col_box(body, Vector3(35.0, Y + rise - 0.2, -17.5), Vector3(4.0, 0.4, 0.8))
	# толща под откосом твёрдая и для коллизии: без неё из бокового прохода можно было пролезть (пригнувшись,
	# а севернее z −16 и в рост) сквозь одностороннюю боковую грань внутрь кучи. Верх коробок (1.8 и 1.1)
	# ниже поверхности откоса на их южных краях (1.92 при z −15.5, 1.51 при z −14.68) — подъём к люку прежний
	Geo.col_box(body, Vector3(35.0, Y + 0.9, -16.69), Vector3(4.0, 1.8, 2.38))
	Geo.col_box(body, Vector3(35.0, Y + 0.55, -15.1), Vector3(4.0, 1.1, 0.84))
	# под откосом — сплошная толща до стены: боковые грани идут по нижней плоскости откоса до низа площадки.
	# Раньше коробка-заполнитель торчала сквозь склон уступом, а между ней и стеной была пустота
	var down := basis * Vector3.BACK    # вдоль склона вниз, к подножию
	var nrm := basis * Vector3.UP
	var bot_s := mid - nrm * 0.2 + down * slope_l * 0.5
	var bot_n := mid - nrm * 0.2 - down * slope_l * 0.5
	var top_s := mid + nrm * 0.2 + down * slope_l * 0.5
	var top_n := mid + nrm * 0.2 - down * slope_l * 0.5
	var slab_y := Y + rise - 0.4
	var z_foot := lerpf(bot_s.z, bot_n.z, (Y - bot_s.y) / (bot_n.y - bot_s.y))
	var z_cap := lerpf(bot_s.z, bot_n.z, (slab_y - bot_s.y) / (bot_n.y - bot_s.y))
	for sx in [-1.0, 1.0]:
		var x: float = 35.0 + sx * 2.0
		b.quad(cm, Vector3(x, Y, z_foot), Vector3(x, slab_y, z_cap), Vector3(x, slab_y, -17.88), Vector3(x, Y, -17.88), Vector3(sx, 0, 0))
	# рваный силуэт вместо ящика: глыбы вдоль боковых граней и по кромке откоса. В боковые проходы
	# выступают не больше чем на ~0.2 м, коллизия кучи прежняя (по откосу ходят к люку)
	for sx in [-1.0, 1.0]:
		var x0: float = 35.0 + sx * 2.0
		var z := -17.55
		while z < -11.9:
			var yt := Y + rise
			if z > top_n.z:
				yt = lerpf(top_s.y, top_n.y, (z - top_s.z) / (top_n.z - top_s.z))
			var hy := Y + 0.15
			while hy < yt - 0.2:
				if randf() < 0.2:
					hy += 0.45
					continue
				b.stone(cm, Vector3(x0 + sx * randf_range(-0.06, 0.04), hy, z + randf_range(-0.2, 0.2)), Vector3(randf_range(0.26, 0.32), randf_range(0.3, 0.42), randf_range(0.4, 0.55)), z * 7.0 + hy)
				hy += randf_range(0.3, 0.55)
			b.stone(cm, Vector3(x0 - sx * randf_range(0.0, 0.15), yt - randf_range(0.0, 0.1), z + randf_range(-0.15, 0.15)), Vector3(randf_range(0.3, 0.5), randf_range(0.18, 0.32), randf_range(0.35, 0.6)), z * 3.0)
			z += randf_range(0.3, 0.75)
	# мелкие куски у подножия: наклонены и утоплены в пол; варежку у восточной стены (37.3, −11.6) не прячут
	for i in 22:
		var p := Vector3(randf_range(32.6, 37.6), Y, randf_range(-12.3, -11.35))
		if Vector2(p.x - 37.3, p.z + 11.6).length() < 0.45:
			continue
		var s := randf_range(0.1, 0.28)
		p.y = Y + s * 0.2
		b.box(cm, p, Vector3(s, s * randf_range(0.55, 0.85), s * randf_range(0.7, 1.2)), Basis.from_euler(Vector3(randf_range(-0.5, 0.5), randf() * TAU, randf_range(-0.5, 0.5))))
	# люк углеподачи в стене под потолком
	var hatch := Mat.m("rust", {"metal": 0.6})
	b.box(hatch, Vector3(35.0, Y + 3.45, -17.85), Vector3(1.2, 1.0, 0.06))
	b.box(Mat.flat(Color(0.08, 0.08, 0.08), 0.6, 0.7), Vector3(35.0, Y + 3.45, -17.8), Vector3(1.0, 0.8, 0.04))
	# лопата воткнута в подножие кучи (верх откоса тут ~Y+0.3): штык (−0.5…0) под углем, а не под полом у края кучи
	Props.model(n, "rusted_spade_01", Vector3(33.35, Y + 0.05, -12.3), 2.4)
	# сквозь щели люка с улицы сочится холодный свет: тонкие полосы по краю и луч в угольной пыли
	var slit := Mat.flat(Color(0.3, 0.35, 0.38), 0.5, 0.0, {"emission": Items.MOON, "emission_energy": 1.6})
	b.box(slit, Vector3(35.0, Y + 3.96, -17.81), Vector3(1.0, 0.015, 0.02))
	b.box(slit, Vector3(34.42, Y + 3.45, -17.81), Vector3(0.015, 0.8, 0.02))
	b.box(slit, Vector3(35.0, Y + 2.94, -17.81), Vector3(0.6, 0.012, 0.02))
	b.commit(n, "props")
	var leak := SpotLight3D.new()
	leak.light_color = Items.MOON
	leak.light_energy = 0.8
	leak.spot_range = 8.0
	leak.spot_angle = 24.0
	leak.spot_attenuation = 1.3
	leak.shadow_enabled = false
	leak.light_specular = 0.2
	leak.light_volumetric_fog_energy = 3.0
	n.add_child(leak)
	leak.global_position = Vector3(35.0, Y + 3.5, -17.5)
	leak.look_at(Vector3(35.0, Y + 0.5, -13.0))


# ---------------------------------------------------------------- сруб: старая чёрная баня

static func banya(w: World) -> void:
	var n := _n(w, "banya")
	var body := _b(w, "banya")
	var b := Geo.Batch.new()
	# прокопчённое дерево, но с видимым волокном (при тоне 0.35 доски читались чёрным ящиком без текстуры)
	var soot := Mat.m("planks_dark", {"tint": Color(0.55, 0.48, 0.42)})
	# полок у южной стены, два яруса; подступёнок между ярусами — верхняя доска не висит над нижней в воздухе
	b.box(soot, Vector3(35.0, Y + 0.45, -5.6), Vector3(5.6, 0.07, 0.8))
	b.box(soot, Vector3(35.0, Y + 0.95, -5.45), Vector3(5.6, 0.07, 0.5))
	b.box(soot, Vector3(35.0, Y + 0.22, -5.95), Vector3(5.6, 0.45, 0.05))
	b.box(soot, Vector3(35.0, Y + 0.7, -5.655), Vector3(5.6, 0.44, 0.05))
	Geo.col_box(body, Vector3(35.0, Y + 0.25, -5.6), Vector3(5.6, 0.5, 0.8))
	# каменка-каменица в углу: груда тёмных голышей (текстура камня, а не гладкие кубики)
	var stone := Mat.m("coal", {"tint": Color(0.6, 0.57, 0.55), "scale": 0.5})
	# угли: трещины жара на тёмной корке, а не оранжевые кубики — и только в нижнем ряду внутри груды (r < 0.45:
	# у края кучи низкие и каждый камень проходил бы по высоте): жар светит в щелях между холодными камнями,
	# а не открытыми гранями по кромке
	var ember := Mat.flat(Color(0.06, 0.03, 0.02), 0.7, 0.0, {"emission": Color(1.0, 0.35, 0.08), "emission_energy": 3.0})
	for i in 40:
		var r := randf_range(0.0, 0.65)
		var a := randf() * TAU
		var h := (0.65 - r) * 1.2
		var p := Vector3(36.8 + cos(a) * r, Y + randf() * h + 0.1, -10.0 + sin(a) * r)
		var is_ember := r < 0.45 and p.y < Y + 0.35 and randf() < 0.25
		var sz := Vector3(randf_range(0.18, 0.3), randf_range(0.12, 0.2), randf_range(0.16, 0.28))
		b.stone(ember if is_ember else stone, p, sz * (0.75 if is_ember else 1.0), float(i))
	Geo.col_box(body, Vector3(36.8, Y + 0.45, -10.0), Vector3(1.3, 0.9, 1.3))
	var glow := Items.Fire.new()
	glow.base = 0.7
	glow.omni_range = 4.0
	glow.light_color = Color(1.0, 0.38, 0.12)
	n.add_child(glow)
	glow.global_position = Vector3(36.6, Y + 1.0, -9.6)
	# сухие веники на гвоздях по западной стене (грань x 32.12) — севернее двери: дверь z −8.4..−7.6 и её
	# наличник они не задевают, створка открывается к югу. Каждый — связка-черенок и пышный низ. Ведро, ковш
	var leaf := Mat.m("cloth", {"tint": Color(0.3, 0.3, 0.14), "scale": 0.35})
	var twig := Mat.m("planks_weather", {"tint": Color(0.62, 0.56, 0.32)})
	for i in 4:
		var bz := -10.55 + i * 0.5
		var lean := Basis(Vector3.RIGHT, randf_range(-0.08, 0.08))
		var top := Vector3(32.19, Y + 1.98, bz)
		b.box(twig, top + lean * Vector3(0, -0.11, 0), Vector3(0.04, 0.2, 0.05), lean)
		b.stone(leaf, top + lean * Vector3(0, -0.36, 0), Vector3(0.13, 0.42, 0.25), float(i) * 3.1)
		b.stone(leaf, top + lean * Vector3(0, -0.5, 0.03), Vector3(0.12, 0.26, 0.21), float(i) * 5.3 + 2.0)
		b.box(soot, Vector3(32.19, Y + 2.0, bz), Vector3(0.008, 0.06, 0.008))
		b.box(soot, Vector3(32.16, Y + 2.03, bz), Vector3(0.08, 0.012, 0.012))
	Props.model(n, "wooden_bucket_01", Vector3(33.0, Y, -10.2), 0.4)
	b.commit(n, "props")
	# волосы на полке
	for i in 5:
		Props.hair_clump(n, Vector3(randf_range(33.0, 37.0), Y + 0.99, -5.4), randf_range(0.5, 0.9), false)
	Props.hair_clump(n, Vector3(35.0, Y + 2.38, -8.0), 1.6, true)


# ---------------------------------------------------------------- двор

static func exterior(w: World) -> void:
	var ext := Node3D.new()
	ext.name = "yard"
	w.add_child(ext)
	var body := Geo.static_body(ext, "col")
	var b := Geo.Batch.new()
	# вывеска
	Props.picture(ext, "res://tex/gen/sign_bani.png", Vector3(26.0, 3.6, 30.36), Vector3(0, 0, 1), Vector2(3.6, 0.9))
	Props.picture(ext, "res://tex/gen/sign_no3.png", Vector3(28.4, 1.9, 30.36), Vector3(0, 0, 1), Vector2(0.4, 0.4))
	# «Закрыто на ремонт» — на левой створке входа. Дверь утоплена в проём фасада на 0.35 м: на плоскости
	# фасада листок висел в воздухе перед ней и оставался в проёме, когда дверь открыта. На створке он уходит
	# вместе с ней; положение — в осях створки (петля x 0, середина полотна x 0.455, лицо наружу +z),
	# так что верно и для двери, восстановленной открытой из сохранения. Ниже стекла, над нижней филёнкой
	var ent := w.doors.get("d_entrance") as Door
	if ent and not ent.leaves.is_empty():
		var leaf: Node3D = ent.leaves[0]["body"]
		var notice := Props.picture(leaf, "res://tex/gen/sign_closed.png", Vector3.ZERO, Vector3(0, 0, 1), Vector2(0.42, 0.33))
		notice.position = Vector3(0.455, 1.2, 0.062)
		notice.rotation = Vector3.ZERO
	else:
		Props.picture(ext, "res://tex/gen/sign_closed.png", Vector3(24.65, 1.45, 30.36), Vector3(0, 0, 1), Vector2(0.42, 0.33))
	# фонарный столб
	var pole := Mat.flat(Color(0.2, 0.2, 0.2), 0.6, 0.5)
	b.cyl(pole, Vector3(16.0, 0, 37.0), Vector3(16.0, 6.0, 37.0), 0.08, 8)
	b.cyl(pole, Vector3(16.0, 6.0, 37.0), Vector3(17.2, 6.2, 37.0), 0.05, 6)
	b.box(Mat.flat(Color(1, 0.7, 0.4), 0.5, 0.0, {"emission": Items.SODIUM, "emission_energy": 4.0}), Vector3(17.2, 6.1, 37.0), Vector3(0.35, 0.08, 0.2))
	Geo.col_box(body, Vector3(16.0, 3.0, 37.0), Vector3(0.2, 6.0, 0.2))
	var sl := SpotLight3D.new()
	sl.light_color = Items.SODIUM
	sl.light_energy = 4.0
	sl.spot_range = 14.0
	sl.spot_angle = 50.0
	sl.shadow_enabled = true
	ext.add_child(sl)
	sl.global_position = Vector3(17.2, 6.0, 37.0)
	sl.rotation = Vector3(-PI * 0.5, 0, 0)
	# фургон «Водоканала»
	van(ext, body, b, Vector3(32.0, 0, 41.5), 0.25)
	# бетонный забор вокруг двора: плиты внахлёст, без щелей (раньше плита 3.3 м на шаге 3.4 — сквозь щели
	# светил снег и лунные полосы); боковые доходят до южного, углы закрыты
	# плиты с потёками («возраст» по высоте забора) и столбы на стыках — читается забором, а не глухой плитой
	var fence := Mat.m("concrete", {"tint": Color(0.6, 0.6, 0.6), "age": "wall", "age_y": 0.0, "age_h": 2.4})
	var post := Mat.m("concrete", {"tint": Color(0.5, 0.5, 0.5)})
	for i in 20:
		var x := -6.0 + i * 3.4
		b.box(fence, Vector3(x, 1.1, 51.5), Vector3(3.45, 2.2, 0.15))
		b.box(post, Vector3(x - 1.7, 1.2, 51.5), Vector3(0.24, 2.4, 0.24))
	for i in 6:
		var z := 32.1125 + i * 3.525
		b.box(fence, Vector3(-7.6, 1.1, z), Vector3(0.15, 2.2, 3.6))
		b.box(fence, Vector3(59.6, 1.1, z), Vector3(0.15, 2.2, 3.6))
		b.box(post, Vector3(-7.6, 1.2, z - 1.76), Vector3(0.24, 2.4, 0.24))
		b.box(post, Vector3(59.6, 1.2, z - 1.76), Vector3(0.24, 2.4, 0.24))
	# от углов здания до боковых заборов по линии фасада: в щель было видно край земли и чёрное небо за ним
	for seg in [[-7.6, -0.35], [52.35, 59.6]]:
		var x0: float = seg[0]
		var x1: float = seg[1]
		# ниже основного (1.8 м): из двора над ним видны светящиеся окна мылен на боковых стенах
		var c := Vector3((x0 + x1) * 0.5, 0.9, 30.43)
		b.box(fence, c, Vector3(x1 - x0 + 0.08, 1.8, 0.15))
		b.box(post, Vector3((x0 + x1) * 0.5, 1.0, 30.43), Vector3(0.24, 2.0, 0.24))
		Geo.col_box(body, c, Vector3(x1 - x0, 1.8, 0.15))
	# голые деревья
	for tpos in [Vector3(4, 0, 44), Vector3(9, 0, 48), Vector3(46, 0, 46), Vector3(53, 0, 40), Vector3(-3, 0, 36)]:
		tree(b, tpos)
		# стволы твёрдые: коробка только по нижнему колену (до 2 м), выше ствол уходит вбок
		Geo.col_box(body, tpos + Vector3(0, 1.0, 0), Vector3(0.36, 2.0, 0.36))
	b.commit(ext, "yard")
	# снегопад
	snow_fx(ext, Vector3(26, 10, 42))


static func van(parent: Node3D, body: StaticBody3D, b: Geo.Batch, pos: Vector3, yaw: float) -> void:
	# светло-серый кузов с синей полосой — силуэт читается и в темноте двора
	var paint := Mat.flat(Color(0.6, 0.62, 0.64), 0.45, 0.35)
	var stripe := Mat.flat(Color(0.06, 0.13, 0.32), 0.5, 0.3)
	var dark := Mat.flat(Color(0.03, 0.035, 0.04), 0.1, 0.6)
	var tire := Mat.flat(Color(0.05, 0.05, 0.05), 0.9)
	var xf := Basis(Vector3.UP, yaw)
	var parts := [
		[Vector3(0, 1.25, 0), Vector3(2.0, 1.6, 4.4), paint],
		[Vector3(0, 1.55, -2.25), Vector3(1.85, 0.75, 0.05), dark],
		[Vector3(1.01, 1.6, -1.3), Vector3(0.03, 0.55, 0.9), dark],
		[Vector3(-1.01, 1.6, -1.3), Vector3(0.03, 0.55, 0.9), dark],
		[Vector3(1.01, 1.6, 0.6), Vector3(0.03, 0.45, 1.6), dark],
		[Vector3(0, 2.1, 0), Vector3(1.9, 0.08, 4.2), paint],
		[Vector3(0, 0.55, -2.2), Vector3(2.0, 0.25, 0.1), Mat.flat(Color(0.2, 0.2, 0.2), 0.5, 0.6)],
	]
	for p in parts:
		b.box(p[2], pos + xf * p[0], p[1], xf)
	# полоса по бортам и корме, задние фонари, окна задних дверей, маячок на крыше
	for sx in [-1.015, 1.015]:
		b.box(stripe, pos + xf * Vector3(sx, 1.05, 0.1), Vector3(0.02, 0.22, 4.0), xf)
	b.box(stripe, pos + xf * Vector3(0, 1.05, 2.215), Vector3(1.9, 0.22, 0.02), xf)
	b.box(dark, pos + xf * Vector3(0, 1.62, 2.21), Vector3(1.6, 0.45, 0.02), xf)
	b.box(Mat.flat(Color(0.02, 0.02, 0.02), 0.6), pos + xf * Vector3(0, 1.25, 2.212), Vector3(0.02, 1.4, 0.02), xf)
	var tail := Mat.flat(Color(0.3, 0.02, 0.02), 0.4, 0.0, {"emission": Color(1.0, 0.08, 0.05), "emission_energy": 1.6})
	for tx in [-0.85, 0.85]:
		b.box(tail, pos + xf * Vector3(tx, 0.75, 2.215), Vector3(0.16, 0.12, 0.02), xf)
	var amber := Mat.flat(Color(0.5, 0.25, 0.02), 0.4, 0.0, {"emission": Color(1.0, 0.55, 0.1), "emission_energy": 2.0})
	b.box(amber, pos + xf * Vector3(0, 2.22, -1.6), Vector3(0.22, 0.14, 0.22), xf)
	for wx in [-0.95, 0.95]:
		for wz in [-1.35, 1.35]:
			var c := pos + xf * Vector3(wx, 0.38, wz)
			b.cyl(tire, c - xf * Vector3(0.12, 0, 0), c + xf * Vector3(0.12, 0, 0), 0.38, 14, true)
	Geo.col_box(body, pos + xf * Vector3(0, 1.1, 0), Vector3(2.0, 2.2, 4.4), xf)
	var lbl := Geo.label3d(parent, "АВАРИЙНАЯ\nВОДОКАНАЛ", pos + xf * Vector3(1.03, 1.45, 0.4), 0.09, Color(0.6, 0.1, 0.08))
	lbl.rotation.y = yaw + PI * 0.5
	# маячок: тусклое янтарное мигание
	var bl := OmniLight3D.new()
	bl.light_color = Color(1.0, 0.55, 0.15)
	bl.omni_range = 6.0
	bl.light_energy = 0.0
	bl.shadow_enabled = false
	parent.add_child(bl)
	bl.global_position = pos + xf * Vector3(0, 2.45, -1.6)
	var blink := Node.new()
	blink.set_script(load("res://src/world/flicker.gd"))
	blink.set("light", bl)
	blink.set("base", 0.9)
	blink.set("blink", 1.6)
	parent.add_child(blink)
	# фары горят: светят на баню
	for hx in [-0.65, 0.65]:
		var hp := pos + xf * Vector3(hx, 0.9, -2.22)
		b.box(Mat.flat(Color(1, 0.95, 0.8), 0.2, 0.0, {"emission": Color(1, 0.93, 0.75), "emission_energy": 6.0}), hp, Vector3(0.22, 0.16, 0.03), xf)
		var sp := SpotLight3D.new()
		sp.light_color = Color(1.0, 0.92, 0.75)
		sp.light_energy = 6.0
		sp.spot_range = 22.0
		sp.spot_angle = 24.0
		sp.shadow_enabled = hx < 0.0
		sp.light_volumetric_fog_energy = 1.5
		parent.add_child(sp)
		sp.global_position = hp + xf * Vector3(0, 0, -0.05)
		sp.global_rotation = Vector3(-0.07, yaw, 0)


## Голое дерево: ствол сужается и чуть гнётся (три колена и конус-вершина), ветви толстые у основания,
## с изломом и тонкими побегами — силуэт на фоне неба читается деревом, а не столбом с палками.
static func tree(b: Geo.Batch, pos: Vector3) -> void:
	var bark := Mat.m("planks_dark", {"tint": Color(0.35, 0.33, 0.32)})
	var h := randf_range(5.0, 7.5)
	var trunk: Array[Vector3] = [pos]
	var r := 0.17
	for k in 3:
		var p1: Vector3 = trunk[k] + Vector3(randf_range(-0.22, 0.22), h * 0.27, randf_range(-0.22, 0.22))
		b.cyl(bark, trunk[k], p1, r, 7)
		trunk.append(p1)
		r *= 0.7
	var tip: Vector3 = trunk[3] + Vector3(randf_range(-0.2, 0.2), h * 0.19, randf_range(-0.2, 0.2))
	b.cone(bark, trunk[3], tip, r, 6)
	trunk.append(tip)
	for i in 9:
		var f := randf_range(0.35, 0.92)
		var s := _on_trunk(trunk, pos.y + h * f)
		var a := randf() * TAU
		var l := randf_range(1.0, 2.2) * (1.15 - f * 0.5)
		var d := Vector3(cos(a), randf_range(0.5, 0.9), sin(a)).normalized()
		var m := s + d * l * 0.55
		b.cyl(bark, s, m, 0.065 * (1.1 - f * 0.5), 5)
		var d2 := (d + Vector3(randf_range(-0.4, 0.4), randf_range(0.0, 0.3), randf_range(-0.4, 0.4))).normalized()
		b.cone(bark, m, m + d2 * l * 0.5, 0.035, 5)
		for k in 2:
			var d3 := (d + Vector3(randf_range(-0.8, 0.8), randf_range(0.1, 0.6), randf_range(-0.8, 0.8))).normalized()
			b.cone(bark, m, m + d3 * randf_range(0.4, 0.8), 0.022, 4)


## Точка на ломаной ствола на высоте y.
static func _on_trunk(trunk: Array[Vector3], y: float) -> Vector3:
	for k in range(1, trunk.size()):
		var a: Vector3 = trunk[k - 1]
		var c: Vector3 = trunk[k]
		if y <= c.y:
			return a.lerp(c, clampf((y - a.y) / maxf(c.y - a.y, 0.001), 0.0, 1.0))
	var last: Vector3 = trunk[trunk.size() - 1]
	return last


static func snow_fx(parent: Node3D, center: Vector3) -> void:
	var p := GPUParticles3D.new()
	p.amount = 600
	p.lifetime = 8.0
	p.preprocess = 8.0
	p.visibility_aabb = AABB(Vector3(-40, -12, -25), Vector3(80, 24, 50))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	# только над двором: раньше область захватывала южную часть здания и снег сыпался сквозь крышу в вестибюль
	pm.emission_box_extents = Vector3(34, 0.5, 10.5)
	pm.direction = Vector3(0.2, -1, 0)
	pm.spread = 15.0
	pm.initial_velocity_min = 0.8
	pm.initial_velocity_max = 1.4
	pm.gravity = Vector3(0, -0.3, 0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.4
	p.process_material = pm
	var qm := QuadMesh.new()
	qm.size = Vector2(0.035, 0.035)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.85, 0.88, 0.95, 0.85)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.material = m
	p.draw_pass_1 = qm
	parent.add_child(p)
	p.global_position = center
