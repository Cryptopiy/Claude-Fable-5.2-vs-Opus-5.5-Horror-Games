class_name BuildSites
extends RefCounted
## Постройки вне дома: дизельная, метеоплощадка, склад ГСМ, мачта с фидерной будкой, вертолётная площадка,
## старый балок 1961 года и ледник под ним.

const FY := 0.03
const CELLAR := Vector3(-48.0, 0.0, -300.0)     # ледник стоит далеко в стороне: в него попадают через люк


static func build(w: World) -> void:
	_shed(w)
	_meteo(w)
	_depot(w)
	_mast(w)
	_pad(w)
	_balok(w)
	_cellar(w)


static func _snow() -> Material:
	return Kit.snow()


static func _wall_lamp(w: World, root: Node3D, pos: Vector3, yaw_deg: float, energy := 1.8, rng := 7.0) -> void:
	Kit.place(root, "walllamp", pos, yaw_deg, 1.0, false, false)
	var fwd := Kit.yaw(yaw_deg) * Vector3(0, 0, 1)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(1.0, 0.9, 0.7)
	gm.emission_enabled = true
	gm.emission = Color(1.0, 0.75, 0.42)
	gm.emission_energy_multiplier = 3.0
	# свечение — на месте лампочки модели, внутри стекла (стекло до 0.125 м от стены)
	Kit.sphere_node(root, pos + fwd * 0.062, 0.045, gm, Vector3(1, 1.7, 1), 8).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.reg_glow(gm)
	# с тенью: лампа в полуметре от стены без тени светила сквозь неё — у двери изнутри светлее, чем под потолочной лампой
	w.reg_light(Kit.omni(root, pos + fwd * 0.45, Color(1.0, 0.76, 0.42), energy, rng, true, 70.0))
	w.reg_halo(Kit.halo(root, pos + fwd * 0.2, Color(1.0, 0.72, 0.38), 1.2, 1.6))


# ------------------------------------------------------------------ дизельная

static func _shed(w: World) -> void:
	var root := Node3D.new()
	root.name = "Shed"
	w.add_child(root)
	var b := Batch.new()
	var ext := Kit.mat("corrugv", 2.0)   # гофролист на стенах — рёбрами вертикально
	var inn := Kit.mat("wallraw", 2.0, Color(0.6, 0.58, 0.55))
	var x0 := 30.0
	var x1 := 34.4
	var z0 := -1.0
	var z1 := 4.2
	var h := 2.4
	b.box(Vector3((x0 + x1) * 0.5, FY - 0.1, (z0 + z1) * 0.5), Vector3(x1 - x0 + 0.2, 0.2, z1 - z0 + 0.2), Kit.mat("concrete", 2.5))
	# стены по x0/x1 на 5 мм короче: их внутренний слой кончался в плоскости наружной грани стен wall_x (полоса 6 см на углах мерцала)
	# западная стена — до кровли: над дверью низ кровли на 2,93 м, раньше между стеной и кровлей была щель
	Walls.wall_z(b, x0, z0 - 0.055, z1 + 0.055, 0, h + 0.55, 0.12, ext, inn, [[1.6, 0.95, 0.0, 2.0]], true, false)
	Walls.wall_z(b, x1, z0 - 0.055, z1 + 0.055, 0, h, 0.12, inn, ext, [], false, true)
	Walls.wall_x(b, z0, x0, x1, 0, h, 0.12, ext, inn, [], true, false)
	Walls.wall_x(b, z1, x0, x1, 0, h, 0.12, inn, ext, [], false, true)
	# щипцы под скатом — треугольники на 2 мм снаружи обшивки торцевых стен
	for side in [[z0 - 0.062, -1.0], [z1 + 0.062, 1.0]]:
		var gz: float = side[0]
		var gs: float = side[1]
		b.tri(Vector3(x0 - 0.06, h, gz), Vector3(x1 + 0.02, h, gz), Vector3(x0 - 0.06, h + 0.55, gz), Vector3(0, 0, gs), ext, Vector3(0, -1, 0), Vector3(gs, 0, 0))
	var rot := Basis(Vector3.BACK, deg_to_rad(-7))
	# рёбра гофры — вдоль ската (uvrot): без поворота шли по Z, поперёк ската
	b.box(Vector3(32.2, h + 0.28, 1.6), Vector3(5.0, 0.06, 5.9), Kit.mat("corrugrust", 2.0, Color(0.5, 0.48, 0.48)), true, rot, true)
	b.box(Vector3(32.2, h + 0.4, 1.6), Vector3(4.9, 0.18, 5.8), _snow(), false, rot)
	b.box(Vector3(32.2, h + 0.03, 1.6), Vector3(4.4, 0.05, 5.2), inn, false)
	var d := Door.make(root, Vector3(x0, FY, 1.6 - 0.475), -90.0, 0.95, 1.97, Kit.mat("plankold", 1.6), 100.0, 0.05)
	w.doors["shed"] = d
	_wall_lamp(w, root, Vector3(x0 - 0.07, 2.24, 1.6), -90.0, 1.6, 6.5)   # целиком над проёмом двери (верх проёма 2.0)
	Props.sign_board(root, Vector3(x0 - 0.075, 2.02, 2.55), -90.0, "ДИЗЕЛЬНАЯ", 0.07)
	# с тенью: окон у дизельной нет, а лампа (6 м) без тени светила сквозь гофролист — тёплые пятна на снегу
	# у трёх глухих стен (~0,1–0,25) и светящийся туман над крышей
	Props.ceil_lamp(w, root, Vector3(32.0, h + 0.005, 1.6), 1.7, 6.0, Color(1.0, 0.8, 0.55), true)   # патрон — к низу подшивки
	# дизель на бетонной подушке, бак на стойке, выхлоп в стену
	b.box(Vector3(33.3, FY + 0.06, 2.6), Vector3(1.2, 0.12, 2.3), Kit.mat("concrete", 2.5, Color(0.7, 0.7, 0.7)))
	# дизель-генератор ДЭС (раньше тут стоял воздушный компрессор с латинской табличкой)
	_genset(root, b, Vector3(33.3, FY + 0.12, 2.6))
	b.solid(Vector3(33.3, 0.7, 2.6), Vector3(0.75, 1.4, 1.8))
	var green := Kit.mat("metalgreen", 1.0)
	var rust := Kit.flat(Color(0.2, 0.15, 0.12), 0.7, 0.5)
	b.cyl(Vector3(33.75, 1.45, 0.2), 0.3, 0.9, green, 12, false, Basis(Vector3.RIGHT, deg_to_rad(90)))
	b.beam(Vector3(33.75, 0.0, -0.15), Vector3(33.75, 1.15, -0.15), 0.05, rust)
	b.beam(Vector3(33.75, 0.0, 0.55), Vector3(33.75, 1.15, 0.55), 0.05, rust)
	b.solid(Vector3(33.75, 0.9, 0.2), Vector3(0.7, 1.8, 1.0))
	b.pipe(Vector3(33.75, 1.2, 0.6), Vector3(33.75, 1.2, 1.9), 0.02, rust)
	b.pipe(Vector3(33.75, 1.2, 1.9), Vector3(33.3, 1.03, 2.55), 0.02, rust)   # к первой форсунке на головке
	b.pipe(Vector3(33.4, 1.25, 3.2), Vector3(33.4, 2.05, 3.2), 0.05, rust)
	b.pipe(Vector3(33.4, 2.05, 3.2), Vector3(34.7, 2.05, 3.2), 0.05, rust)
	b.pipe(Vector3(34.7, 2.05, 3.2), Vector3(34.7, 2.9, 3.2), 0.05, rust)
	w.things["gen_snd"] = Snd.emitter("gen_loop", root, Vector3(33.3, 0.8, 2.6), -2.0, 55.0, 4.0)
	w.things["gen_pos"] = Vector3(33.3, 0.8, 2.6)
	w.things["gen_fuel"] = Interactable.make(root, Vector3(33.6, 1.4, 0.25), Vector3(0.8, 0.9, 1.1), "Залить солярку", func() -> void: G.act("gen_fuel"), 5.0)
	w.things["gen_start"] = Interactable.make(root, Vector3(32.85, 0.85, 2.6), Vector3(0.5, 1.2, 1.7), "Запустить дизель", func() -> void: G.act("gen_start"))
	# канистра
	var can := Kit.put(root, "jerry", Vector3(31.0, FY, 3.75), 30.0, 1.0, false)
	w.things["jerry"] = can
	w.things["jerry_it"] = Interactable.make(root, Vector3(31.0, 0.3, 3.75), Vector3(0.5, 0.6, 0.4), "Взять канистру", func() -> void: G.act("jerry"))
	# верстак у северной стены
	var wood := Kit.mat("plankgrey", 1.5)
	b.box(Vector3(31.4, 0.84, -0.62), Vector3(2.0, 0.06, 0.62), wood)
	for lx in [30.5, 32.3]:
		b.box(Vector3(lx, 0.42, -0.62), Vector3(0.07, 0.82, 0.56), wood, false)
	Kit.place(root, "vice", Vector3(30.75, 0.87, -0.48), 0.0, 1.0, false, false)   # начало модели — низ станины; винт с воротком за краем верстака
	Kit.put(root, "toolbox", Vector3(31.9, 0.87, -0.62), 12.0, 1.0, false, false)
	Kit.put(root, "toolchest", Vector3(33.0, FY, -0.62), 0.0, 1.0, true)
	Kit.put(root, "drumred", Vector3(30.55, FY, 0.4), 0.0, 1.0, true)
	Kit.put(root, "jerryred", Vector3(31.55, FY, -0.2), 70.0, 1.0, false, false)
	for i in 3:
		Kit.put(root, "oiltin", Vector3(31.2 + i * 0.16, 0.87, -0.78), i * 31.0, 1.0, false, false)
	Kit.place(root, "breaker", Vector3(x0 + 0.11, 1.5, 3.3), 90.0, 1.0, false, false)   # начало модели — середина корпуса глубиной 9.5 см
	b.commit(root, "Static")
	Props.drift_wall(root, Vector3(32.2, -0.02, -1.07), Vector3(0, 0, -1), Vector3(4.2, 1.0, 1.7))
	Props.drift_wall(root, Vector3(34.47, -0.02, 1.2), Vector3(1, 0, 0), Vector3(3.6, 0.7, 1.2))
	w.add_zone("shed", Vector3(x0 - 0.1, -1, z0), Vector3(x1, h, z1), "conc", 1.0, 0.8)
	w.places["shed_in"] = [Vector3(31.2, FY, 1.6), -90.0]


## Дизель-генератор на салазках: радиатор к стене (+Z), двигатель, генератор и щиток к двери (−Z, −X).
## Всё — в одну пачку Batch: в кадре это несколько вызовов отрисовки на всю дизельную.
static func _genset(root: Node3D, b: Batch, base: Vector3) -> void:
	var paint := Kit.mat("metalgreen", 0.8, Color(0.62, 0.7, 0.6))
	var dark := Kit.flat(Color(0.07, 0.075, 0.07), 0.55, 0.6)
	var steel := Kit.mat("metalplate", 0.8, Color(0.55, 0.55, 0.55))
	var rust := Kit.mat("metalrust", 0.8, Color(0.55, 0.5, 0.48))
	var grey := Kit.flat(Color(0.28, 0.3, 0.29), 0.6, 0.4)
	var face := Kit.flat(Color(0.8, 0.78, 0.7), 0.5)
	var red := Kit.flat(Color(0.55, 0.06, 0.04), 0.5)
	var x := base.x
	var z := base.z
	var y := base.y
	# салазки из швеллера и поперечины
	for sx in [-0.3, 0.3]:
		b.box(Vector3(x + sx, y + 0.05, z), Vector3(0.08, 0.1, 1.85), rust, false)
	for sz in [-0.8, 0.0, 0.8]:
		b.box(Vector3(x, y + 0.05, z + sz), Vector3(0.62, 0.06, 0.08), rust, false)
	# двигатель: картер, блок, клапанная крышка, коллектор
	b.box(Vector3(x, y + 0.2, z + 0.25), Vector3(0.5, 0.2, 0.9), dark, false)
	b.box(Vector3(x, y + 0.5, z + 0.25), Vector3(0.56, 0.42, 0.86), paint, false)
	b.box(Vector3(x, y + 0.77, z + 0.25), Vector3(0.42, 0.12, 0.78), paint, false)
	b.box(Vector3(x, y + 0.85, z + 0.25), Vector3(0.36, 0.04, 0.7), grey, false)
	for i in 4:
		b.cyl(Vector3(x, y + 0.88, z - 0.05 + i * 0.2), 0.03, 0.04, dark, 8, false)
	b.box(Vector3(x + 0.31, y + 0.62, z + 0.25), Vector3(0.08, 0.1, 0.8), rust, false)
	b.cyl(Vector3(x - 0.33, y + 0.5, z + 0.1), 0.07, 0.2, red, 10, false)                   # масляный фильтр
	b.cyl(Vector3(x - 0.33, y + 0.7, z + 0.5), 0.05, 0.16, grey, 8, false)                  # топливный насос
	# радиатор с решёткой и кожух вентилятора
	b.box(Vector3(x, y + 0.53, z + 0.82), Vector3(0.64, 0.86, 0.1), paint, false)   # низом на салазках
	for i in 9:
		b.box(Vector3(x, y + 0.24 + i * 0.075, z + 0.875), Vector3(0.5, 0.025, 0.02), dark, false)
	b.cyl(Vector3(x, y + 1.0, z + 0.82), 0.05, 0.12, steel, 10, false)                      # крышка горловины
	b.cyl(Vector3(x, y + 0.55, z + 0.74), 0.26, 0.08, dark, 14, false, Basis(Vector3.RIGHT, deg_to_rad(90)))
	# генератор: корпус, торцевой щит, клеммная коробка
	b.cyl(Vector3(x, y + 0.45, z - 0.47), 0.27, 0.62, paint, 16, false, Basis(Vector3.RIGHT, deg_to_rad(90)))   # торцом в блок
	b.box(Vector3(x, y + 0.2, z - 0.5), Vector3(0.6, 0.2, 0.3), paint, false)                 # лапа генератора на салазках
	b.cyl(Vector3(x, y + 0.45, z - 0.8), 0.22, 0.06, grey, 16, false, Basis(Vector3.RIGHT, deg_to_rad(90)))
	for i in 6:
		var a := TAU * float(i) / 6.0
		b.box(Vector3(x + cos(a) * 0.15, y + 0.45 + sin(a) * 0.15, z - 0.835), Vector3(0.05, 0.05, 0.01), dark, false)
	b.box(Vector3(x, y + 0.77, z - 0.5), Vector3(0.26, 0.12, 0.3), paint, false)
	# щиток на стойке со стороны прохода: вольтметр, амперметр, давление масла
	b.beam(Vector3(x - 0.36, y, z - 0.55), Vector3(x - 0.36, y + 1.05, z - 0.55), 0.04, rust)
	b.box(Vector3(x - 0.39, y + 1.02, z - 0.55), Vector3(0.05, 0.3, 0.5), paint, false)
	for i in 3:
		var gz := z - 0.72 + i * 0.17
		b.cyl(Vector3(x - 0.42, y + 1.05, gz), 0.055, 0.02, dark, 12, false, Basis(Vector3.FORWARD, deg_to_rad(90)))
		b.cyl(Vector3(x - 0.432, y + 1.05, gz), 0.045, 0.005, face, 12, false, Basis(Vector3.FORWARD, deg_to_rad(90)))
		b.box(Vector3(x - 0.436, y + 1.06, gz + 0.012), Vector3(0.002, 0.04, 0.004), red, false, Basis(Vector3.RIGHT, deg_to_rad(35.0 - 25.0 * i)))
	b.box(Vector3(x - 0.42, y + 0.92, z - 0.42), Vector3(0.03, 0.05, 0.05), red, false)        # кнопка «стоп»
	# глушитель под выхлопом
	b.cyl(Vector3(x + 0.115, y + 1.02, z + 0.6), 0.09, 0.64, rust, 10, false)   # стоит на блоке (низ 0.85), мимо четвёртой форсунки
	# трафарет на блоке и пятно масла на подушке
	Kit.label(root, Vector3(x - 0.285, y + 0.52, z + 0.3), "ДЭС-8", 0.075, Color(0.82, 0.8, 0.72), "head", Kit.yaw(-90))   # правее масляного фильтра
	Kit.label(root, Vector3(x - 0.285, y + 0.42, z + 0.3), "1971", 0.04, Color(0.82, 0.8, 0.72), "head", Kit.yaw(-90))
	var oil := Kit.quad_node(root, Vector3(x - 0.05, y + 0.003, z + 0.1), Vector2(0.9, 1.3), Kit.flat(Color(0.02, 0.018, 0.015, 0.75), 0.15), Basis(Vector3.RIGHT, deg_to_rad(-90)))
	oil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# ------------------------------------------------------------------ метеоплощадка

static func _meteo(w: World) -> void:
	var root := Node3D.new()
	root.name = "Meteo"
	w.add_child(root)
	var b := Batch.new()
	var wood := Kit.mat("plankgrey", 1.5)
	# будка выкрашена белым, но краска старая — светло-серая, чтобы вплотную под фонарём не горела пятном
	var white := Kit.mat("plaster", 1.5, Color(0.7, 0.71, 0.68))
	var wire := Kit.flat(Color(0.08, 0.08, 0.08), 0.5, 0.5)
	# ограда 12×12 с воротами на юг и на запад
	var c := Map.METEO
	var hs := 6.0
	var corners := [Vector3(c.x - hs, 0, c.z - hs), Vector3(c.x + hs, 0, c.z - hs), Vector3(c.x + hs, 0, c.z + hs), Vector3(c.x - hs, 0, c.z + hs)]
	for i in 4:
		var p0: Vector3 = corners[i]
		var p1: Vector3 = corners[(i + 1) % 4]
		var n := 4
		for k in n:
			var p := p0.lerp(p1, float(k) / float(n))
			# угол — начало следующей стороны (дважды не ставим); в середине ворот столба нет: там проход с леера
			if p.distance_to(Map.METEO_GATE) < 0.5 or p.distance_to(Map.METEO_WGATE) < 0.5:
				continue
			b.box(p + Vector3(0, 0.6, 0), Vector3(0.09, 1.7, 0.09), wood, false)
		for k in n:
			var a := p0.lerp(p1, float(k) / float(n))
			var e := p0.lerp(p1, float(k + 1) / float(n))
			var mid := (a + e) * 0.5
			# ворота: юг (сторона 2→3, середина) и запад (сторона 3→0, середина)
			var gate := (i == 2 and (k == 1 or k == 2) and absf(mid.x - c.x) < 1.6) or (i == 3 and (k == 1 or k == 2) and absf(mid.z - c.z) < 1.6)
			if gate:
				continue
			for hy in [0.55, 1.05]:
				b.beam(a + Vector3(0, hy, 0), e + Vector3(0, hy, 0), 0.012, wire)
			b.solid(mid + Vector3(0, 0.7, 0), Vector3(absf(e.x - a.x) + 0.1, 1.4, absf(e.z - a.z) + 0.1))
	# ворота уже: по одному пролёту с каждой стороны проёма закрываем коротким отрезком
	for side in [-1.0, 1.0]:
		var ga := Vector3(c.x + side * 3.0, 0, c.z + hs)
		var gb := Vector3(c.x + side * 0.9, 0, c.z + hs)
		b.box(gb + Vector3(0, 0.6, 0), Vector3(0.09, 1.7, 0.09), wood, false)
		for hy in [0.55, 1.05]:
			b.beam(ga + Vector3(0, hy, 0), gb + Vector3(0, hy, 0), 0.012, wire)
		b.solid((ga + gb) * 0.5 + Vector3(0, 0.7, 0), Vector3(2.1, 1.4, 0.1))
		var wa := Vector3(c.x - hs, 0, c.z + side * 3.0)
		var wb := Vector3(c.x - hs, 0, c.z + side * 0.9)
		b.box(wb + Vector3(0, 0.6, 0), Vector3(0.09, 1.7, 0.09), wood, false)
		for hy in [0.55, 1.05]:
			b.beam(wa + Vector3(0, hy, 0), wb + Vector3(0, hy, 0), 0.012, wire)
		b.solid((wa + wb) * 0.5 + Vector3(0, 0.7, 0), Vector3(0.1, 1.4, 2.1))
	# табличка привязана к верхней проволоке (ось y 1,05, лицо проволоки z −49,994) — раньше висела в воздухе на 1,5 м
	Props.sign_board(root, Vector3(c.x + 1.6, 1.05, c.z + hs + 0.016), 0.0, "МЕТЕОПЛОЩАДКА", 0.075)

	# психрометрическая будка: жалюзи, дверца на юг
	var bp := Vector3(24.0, 0, -55.4)
	for lx in [-0.26, 0.26]:
		for lz in [-0.22, 0.22]:
			b.beam(bp + Vector3(lx * 1.25, 0, lz * 1.3), bp + Vector3(lx, 1.28, lz), 0.05, white)
	b.box(bp + Vector3(0, 1.3, 0), Vector3(0.66, 0.04, 0.56), white, false)
	b.box(bp + Vector3(0, 1.98, 0), Vector3(0.78, 0.04, 0.68), white, false)
	b.box(bp + Vector3(0, 2.05, 0), Vector3(0.7, 0.1, 0.6), _snow(), false)
	for i in 9:
		var y := 1.36 + i * 0.07
		var tilt := Basis(Vector3.BACK, deg_to_rad(35))
		b.box(bp + Vector3(-0.31, y, 0), Vector3(0.012, 0.08, 0.5), white, false, tilt)
		b.box(bp + Vector3(0.31, y, 0), Vector3(0.012, 0.08, 0.5), white, false, tilt.inverse())
		# задние планки во всю ширину (±0,338, как боковые): иначе в задних углах щель насквозь
		b.box(bp + Vector3(0, y, -0.26), Vector3(0.676, 0.08, 0.012), white, false, Basis(Vector3.RIGHT, deg_to_rad(-35)))
	b.solid(bp + Vector3(0, 1.0, 0), Vector3(0.7, 2.0, 0.6))
	# внутри: доска с двумя термометрами, прибита к задним жалюзи (их передние кромки — z −0,232)
	b.box(bp + Vector3(0, 1.64, -0.227), Vector3(0.4, 0.5, 0.012), Kit.flat(Color(0.82, 0.8, 0.74), 0.8), false)
	# стекло термометров полупрозрачное: у трубки (r 0,009) правильный обход, и непрозрачная она закрыла бы столбик (r 0,006)
	var glass := Kit.flat(Color(0.75, 0.8, 0.85, 0.35), 0.15, 0.2)
	var red := Kit.flat(Color(0.7, 0.06, 0.05), 0.4)
	for tx in [-0.09, 0.09]:
		b.cyl(bp + Vector3(tx, 1.64, -0.212), 0.009, 0.4, glass, 6, false)
		b.cyl(bp + Vector3(tx, 1.52, -0.211), 0.006, 0.14, red, 6, false)
	# дверца будки (открывается при отсчёте)
	var bd := Node3D.new()
	bd.position = bp + Vector3(-0.31, 1.33, 0.27)
	root.add_child(bd)
	var bdm := Batch.new()
	for i in 9:
		bdm.box(Vector3(0.31, 0.05 + i * 0.07, 0), Vector3(0.6, 0.08, 0.012), white, false, Basis(Vector3.RIGHT, deg_to_rad(35)))
	bdm.box(Vector3(0.31, 0.32, 0), Vector3(0.64, 0.66, 0.006), white, false)
	bdm.commit(bd, "BoothDoor", false)
	w.things["booth_door"] = bd
	w.things["booth_pos"] = bp
	var it := Interactable.make(root, bp + Vector3(0, 1.62, 0.2), Vector3(0.7, 0.75, 0.5), "Снять показания термометра", func() -> void: G.act("read_t"), 3.0)
	it.need_light = true
	it.on_hold = func(active: bool) -> void: G.act("booth_open" if active else "booth_close")
	w.things["read_t"] = it
	# рукавица Громова и записка под будкой (появляются на вторую ночь)
	var mit := Node3D.new()
	# полюс сферы уходит в полку на 1 см, нижний пояс вершин (1,317) — вровень с полкой 1,32: «примёрзла», а не висит
	mit.position = bp + Vector3(0.12, 1.31, 0.12)
	root.add_child(mit)
	var mcl := Kit.mat("caban", 0.4, Color(0.3, 0.26, 0.2))
	Kit.sphere_node(mit, Vector3(0, 0.035, 0), 1.0, mcl, Vector3(0.07, 0.035, 0.11), 8)
	Kit.sphere_node(mit, Vector3(0.06, 0.03, -0.03), 1.0, mcl, Vector3(0.03, 0.025, 0.05), 6)
	mit.visible = false
	w.things["mitten"] = mit
	var n3 := Props.paper(root, bp + Vector3(-0.1, 1.326, 0.1), 15.0, "gr3", true, Vector2(0.15, 0.2), true)
	n3.enabled = false
	# лежит на дне будки — внутри её коллизии и под объёмом термометра: достаётся «сквозь» них
	n3.reach_in = 0.3
	(n3.get_meta("mesh") as Node3D).visible = false
	w.things["note_gr3"] = n3

	# анемометр: мачта 4,5 м, вертушка, пульт на уровне груди
	var ap := Vector3(28.6, 0, -57.6)
	b.cyl(ap + Vector3(0, 2.25, 0), 0.035, 4.5, white, 8, true)
	# растяжки в стороны от пульта (он смотрит на юг): трос на 270° шёл на уровне глаз там, где стоят у пульта
	for ang in [90.0, 210.0, 330.0]:
		var dv := Kit.yaw(ang) * Vector3(2.4, 0, 0)
		b.beam(ap + Vector3(0, 3.6, 0), ap + dv, 0.01, wire)
	var rotor := Node3D.new()
	rotor.position = ap + Vector3(0, 4.55, 0)
	root.add_child(rotor)
	var cup := Kit.flat(Color(0.12, 0.12, 0.12), 0.5, 0.3)
	# ступица: входит в макушку мачты (4,50) на 2 см и держит спицы (4,544–4,556) — без неё вертушка висела в воздухе
	Kit.cyl_node(rotor, Vector3(0, -0.02, 0), 0.022, 0.1, cup, 10)
	for ang in [0.0, 120.0, 240.0]:
		var arm := Kit.yaw(ang) * Vector3(0.22, 0, 0)
		Kit.box_node(rotor, arm * 0.5, Vector3(0.22, 0.012, 0.012), cup, false).rotation.y = deg_to_rad(ang)
		Kit.sphere_node(rotor, arm, 0.05, cup, Vector3.ONE, 8).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.things["anemo_rotor"] = rotor
	b.box(ap + Vector3(0, 1.4, 0.1), Vector3(0.26, 0.32, 0.14), Kit.mat("metalgreen", 1.0), false)
	b.cyl(ap + Vector3(0, 1.44, 0.172), 0.09, 0.006, Kit.flat(Color(0.85, 0.84, 0.78), 0.4), 14, false, Basis(Vector3.RIGHT, deg_to_rad(90)))
	b.box(ap + Vector3(0.02, 1.46, 0.178), Vector3(0.008, 0.07, 0.004), Kit.flat(Color(0.05, 0.05, 0.05), 0.5), false, Basis(Vector3.BACK, deg_to_rad(-40)))
	var it2 := Interactable.make(root, ap + Vector3(0, 1.4, 0.15), Vector3(0.4, 0.5, 0.4), "Снять показания анемометра", func() -> void: G.act("read_w"), 3.0)
	it2.need_light = true
	w.things["read_w"] = it2
	w.things["anemo_snd"] = Snd.emitter("anemo_loop", root, ap + Vector3(0, 3.0, 0), -6.0, 14.0, 2.0)

	# снегомерная рейка: красно-белые деления
	var sp := Vector3(26.6, 0, -59.6)
	var wh := Kit.flat(Color(0.9, 0.9, 0.86), 0.7)
	var rd := Kit.flat(Color(0.75, 0.08, 0.06), 0.7)
	for i in 20:
		b.box(sp + Vector3(0, 0.05 + i * 0.1, 0), Vector3(0.07, 0.1, 0.02), rd if i % 2 == 0 else wh, false)
	b.solid(sp + Vector3(0, 1.0, 0), Vector3(0.1, 2.0, 0.1))
	var it3 := Interactable.make(root, sp + Vector3(0, 0.9, 0), Vector3(0.4, 1.4, 0.4), "Снять высоту снега", func() -> void: G.act("read_s"), 2.0)
	it3.need_light = true
	w.things["read_s"] = it3
	Props.drift(root, sp + Vector3(0.1, -0.25, 0.1), Vector3(1.4, 0.95, 1.1))

	# осадкомер: ведро в конусной защите на столбе
	var op := Vector3(22.6, 0, -59.2)
	b.cyl(op + Vector3(0, 0.8, 0), 0.04, 1.6, wood, 6, true)
	b.cyl(op + Vector3(0, 1.75, 0), 0.16, 0.32, white, 12, false, Basis.IDENTITY, false, 0.42)
	b.cyl(op + Vector3(0, 1.72, 0), 0.11, 0.28, Kit.mat("metalrust", 1.0), 10, false)

	# фонарь на столбе посреди площадки: виден с леера, гаснет вместе с дизелем
	var lp := Vector3(26.0, 0, -53.2)
	b.cyl(lp + Vector3(0, 1.6, 0), 0.05, 3.2, wood, 6, true)
	b.box(lp + Vector3(0, 3.2, 0.12), Vector3(0.05, 0.05, 0.3), wood, false)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(1.0, 0.9, 0.7)
	gm.emission_enabled = true
	gm.emission = Color(1.0, 0.78, 0.45)
	gm.emission_energy_multiplier = 3.0
	Kit.sphere_node(root, lp + Vector3(0, 3.1, 0.25), 0.06, gm, Vector3(1, 1.4, 1), 8).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.reg_glow(gm)
	w.reg_light(Kit.omni(root, lp + Vector3(0, 2.95, 0.25), Color(1.0, 0.78, 0.45), 1.7, 9.0, false, 70.0))
	w.reg_halo(Kit.halo(root, lp + Vector3(0, 3.1, 0.25), Color(1.0, 0.74, 0.4), 1.3, 1.5))
	b.commit(root, "Static")
	w.places["meteo_in"] = [Vector3(26.0, 0, -52.0), 0.0]
	w.places["booth"] = [bp + Vector3(0, 0, 1.1), 0.0]


# ------------------------------------------------------------------ склад ГСМ

static func _depot(w: World) -> void:
	var root := Node3D.new()
	root.name = "Depot"
	w.add_child(root)
	var b := Batch.new()
	var c := Map.DEPOT
	var wood := Kit.mat("plankgrey", 1.5)
	var iron := Kit.mat("corrugrust", 2.0, Color(0.5, 0.48, 0.48))
	# столбы до низа наклонной кровли: низ листа на оси навеса 2.47 м, уклон 7°, +1.5 см в лист
	for dx in [-2.4, 2.4]:
		var top: float = 2.47 + dx * tan(deg_to_rad(7.0)) + 0.015
		for dz in [-2.0, 2.0]:
			b.box(c + Vector3(dx, top * 0.5, dz), Vector3(0.12, top, 0.12), wood)
	# столб у свободного края северной стенки
	var top_n: float = 2.47 - 0.6 * tan(deg_to_rad(7.0)) + 0.015
	b.box(c + Vector3(-0.6, top_n * 0.5, -2.0), Vector3(0.12, top_n, 0.12), wood)
	var rot := Basis(Vector3.BACK, deg_to_rad(7))
	# рёбра гофры — вдоль ската (uvrot): без поворота шли по Z, поперёк ската
	b.box(c + Vector3(0, 2.5, 0), Vector3(5.6, 0.06, 4.8), iron, false, rot, true)
	b.box(c + Vector3(0, 2.62, 0), Vector3(5.5, 0.2, 4.7), _snow(), false, rot)
	# задняя (восточная) и северная стенки от ветра
	Walls.wall_z(b, c.x + 2.4, c.z - 2.0, c.z + 2.0, 0, 2.2, 0.06, iron, iron, [])
	Walls.wall_x(b, c.z - 2.0, c.x - 0.6, c.x + 2.4, 0, 2.1, 0.06, iron, iron, [])
	# бочки
	var k := 0
	for dx in [0.9, 1.7]:
		for dz in [-1.4, -0.6, 0.2, 1.0]:
			Kit.put(root, "drumred" if k % 3 != 1 else "drumblue", c + Vector3(dx + (k % 2) * 0.05, 0, dz), k * 37.0, 1.0, true)
			k += 1
	# расходная бочка на козлах с ручным насосом
	var pp := c + Vector3(-1.2, 0, 0.6)
	# козлы до низа бочки: ось 0.82, радиус обечайки 0.276
	b.box(pp + Vector3(0, 0.273, -0.3), Vector3(0.9, 0.546, 0.1), wood)
	b.box(pp + Vector3(0, 0.273, 0.3), Vector3(0.9, 0.546, 0.1), wood)
	var dr := Kit.put(root, "drumred", pp + Vector3(0, 0.82, -0.44), 0.0, 1.0, false)
	if dr != null:
		dr.rotation.x = deg_to_rad(90)
	b.solid(pp + Vector3(0, 0.5, 0), Vector3(0.9, 1.0, 1.0))
	# ручной коловратный насос для бочек (раньше тут стоял велосипедный насос, увеличенный в полтора раза)
	var pmet := Kit.flat(Color(0.16, 0.2, 0.22), 0.55, 0.6)
	var psteel := Kit.flat(Color(0.42, 0.42, 0.4), 0.35, 0.85)
	var hose := Kit.flat(Color(0.03, 0.03, 0.03), 0.8)
	b.pipe(pp + Vector3(0, 0.98, 0), pp + Vector3(0, 1.36, 0), 0.022, psteel)                        # заборная труба в горловине
	b.cyl(pp + Vector3(0, 1.1, 0), 0.04, 0.05, pmet, 10, false)                                      # штуцер горловины
	b.cyl(pp + Vector3(0, 1.43, 0), 0.085, 0.16, pmet, 14, false, Basis(Vector3.FORWARD, deg_to_rad(90)))  # корпус насоса
	b.cyl(pp + Vector3(0.09, 1.43, 0), 0.03, 0.04, psteel, 10, false, Basis(Vector3.FORWARD, deg_to_rad(90)))
	b.beam(pp + Vector3(0.11, 1.43, 0), pp + Vector3(0.11, 1.78, 0.18), 0.022, psteel)                # рычаг
	b.pipe(pp + Vector3(0.08, 1.78, 0.18), pp + Vector3(0.22, 1.78, 0.18), 0.018, Kit.flat(Color(0.3, 0.2, 0.12), 0.8))  # рукоятка
	b.pipe(pp + Vector3(-0.09, 1.43, 0), pp + Vector3(-0.3, 1.38, 0), 0.02, psteel)                  # слив
	b.pipe(pp + Vector3(-0.3, 1.38, 0), pp + Vector3(-0.42, 1.0, 0.05), 0.024, hose)                 # шланг
	b.pipe(pp + Vector3(-0.42, 1.0, 0.05), pp + Vector3(-0.46, 0.55, 0.12), 0.024, hose)
	var it := Interactable.make(root, pp + Vector3(-0.1, 1.0, 0.0), Vector3(1.0, 1.4, 1.1), "Накачать солярку", func() -> void: G.act("pump"), 8.0)
	it.on_hold = func(active: bool) -> void: G.act("pump_on" if active else "pump_off")
	w.things["pump"] = it
	w.things["pump_pos"] = pp
	Props.sign_board(root, c + Vector3(-2.47, 1.75, -2.0), -90.0, "ГСМ. ОГНЕОПАСНО", 0.075, Color(0.8, 0.72, 0.3))
	b.commit(root, "Static")
	Props.drift(root, c + Vector3(3.4, -0.1, 0), Vector3(1.4, 0.9, 3.2))
	Props.drift(root, c + Vector3(0.8, -0.1, -2.9), Vector3(3.0, 0.8, 1.3))
	w.places["depot_in"] = [c + Vector3(-2.6, 0, 0.6), -90.0]


# ------------------------------------------------------------------ мачта и фидерная будка

static func _mast(w: World) -> void:
	var root := Node3D.new()
	root.name = "Mast"
	w.add_child(root)
	var b := Batch.new()
	var steel := Kit.mat("metalrust", 1.0, Color(0.55, 0.5, 0.48))
	var m := Map.MAST
	var ht := 22.0
	var secs := 8
	var prev: Array = []
	for s in secs + 1:
		var t := float(s) / float(secs)
		var half := lerpf(0.85, 0.2, t)
		var y := ht * t
		var ring := [m + Vector3(-half, y, -half), m + Vector3(half, y, -half), m + Vector3(half, y, half), m + Vector3(-half, y, half)]
		for i in 4:
			b.beam(ring[i], ring[(i + 1) % 4], 0.035, steel)
			if not prev.is_empty():
				b.beam(prev[i], ring[i], 0.05, steel)
				b.beam(prev[i], ring[(i + 1) % 4], 0.025, steel)
		prev = ring
	b.solid(m + Vector3(0, 2.0, 0), Vector3(1.8, 4.0, 1.8))
	var wire := Kit.flat(Color(0.1, 0.1, 0.1), 0.5, 0.5)
	for ang in [20.0, 140.0, 260.0]:
		var dv := Kit.yaw(ang) * Vector3(11.0, 0, 0)
		b.beam(m + Vector3(0, 15.0, 0), m + dv, 0.015, wire)
		b.box(m + dv + Vector3(0, 0.1, 0), Vector3(0.3, 0.3, 0.3), Kit.mat("concrete", 1.0), false)
	# площадка на верхнем поясе и чашка под колпаком: шар маяка стоит на них
	b.box(m + Vector3(0, ht + 0.025, 0), Vector3(0.46, 0.05, 0.46), steel, false)
	b.cyl(m + Vector3(0, ht + 0.075, 0), 0.1, 0.05, steel, 10)
	# красный маяк наверху: мигает, виден сквозь пургу
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(1.0, 0.2, 0.1)
	gm.emission_enabled = true
	gm.emission = Color(1.0, 0.1, 0.05)
	gm.emission_energy_multiplier = 4.0
	Kit.sphere_node(root, m + Vector3(0, ht + 0.2, 0), 0.14, gm, Vector3.ONE, 8).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.things["beacon_mat"] = gm
	var hl := Kit.halo(root, m + Vector3(0, ht + 0.2, 0), Color(1.0, 0.12, 0.06), 2.6, 2.4)
	(hl.material_override as ShaderMaterial).set_shader_parameter("vis_scale", 2.6)
	w.things["beacon_halo"] = hl

	# будка
	var x0 := Map.HUT_MIN.x
	var x1 := Map.HUT_MAX.x
	var z0 := Map.HUT_MIN.z
	var z1 := Map.HUT_MAX.z
	var h := 2.2
	var ext := Kit.mat("corrugv", 2.0)   # гофролист на стенах — рёбрами вертикально
	var inn := Kit.mat("wallraw", 2.0, Color(0.6, 0.58, 0.55))
	b.box(Vector3((x0 + x1) * 0.5, FY - 0.1, (z0 + z1) * 0.5), Vector3(x1 - x0 + 0.2, 0.2, z1 - z0 + 0.2), Kit.mat("floorwood", 2.0))
	# стены по x0/x1 на 5 мм короче: их внутренний слой совпадал с наружной гранью стен wall_x (полоса 5 см на углах мерцала)
	Walls.wall_z(b, x0, z0 - 0.045, z1 + 0.045, 0, h, 0.1, ext, inn, [], true, false)
	Walls.wall_z(b, x1, z0 - 0.045, z1 + 0.045, 0, h, 0.1, inn, ext, [[13.5, 0.82, 0.0, 1.95]], false, true)
	Walls.wall_x(b, z0, x0, x1, 0, h, 0.1, ext, inn, [], true, false)
	Walls.wall_x(b, z1, x0, x1, 0, h, 0.1, inn, ext, [], false, true)
	b.box(Vector3((x0 + x1) * 0.5, h + 0.04, (z0 + z1) * 0.5), Vector3(2.9, 0.08, 2.9), Kit.mat("corrugrust", 2.0, Color(0.5, 0.48, 0.48)))
	b.box(Vector3((x0 + x1) * 0.5, h - 0.02, (z0 + z1) * 0.5), Vector3(2.3, 0.04, 2.3), inn, false)
	b.box(Vector3((x0 + x1) * 0.5, h + 0.18, (z0 + z1) * 0.5), Vector3(2.8, 0.2, 2.8), _snow(), false)
	var d := Door.make(root, Vector3(x1, FY, 13.5 - 0.41), -90.0, 0.82, 1.93, Kit.mat("plankold", 1.6), -100.0, 0.05)
	w.doors["hut"] = d
	# табличка на перемычке над дверью (проём до 1.95, свес крыши от 2.2), вплотную к гофре
	Props.sign_board(root, Vector3(x1 + 0.062, 2.075, 13.5), 90.0, "ФИДЕР", 0.07)
	# с тенью: окон в будке нет, а лампа без тени светила сквозь стены и крышу — тёплое кольцо на снегу и туман над будкой
	Props.ceil_lamp(w, root, Vector3(-79.4, h - 0.04, 13.5), 0.8, 4.0, Color(1.0, 0.8, 0.55), true)   # патрон под доской, а не в ней
	# шкаф задом к стене (лицо стены x = -80.55, зад шкафа в 0.216 от центра)
	var fb := Kit.put(root, "feeder", Vector3(-80.33, FY, 13.5), 90.0, 1.0, true)
	w.things["feeder_box"] = fb
	b.pipe(Vector3(-80.38, 1.15, 13.3), Vector3(-80.38, 2.1, 13.3), 0.025, wire)
	# кабель к восточной грани мачты и по ней вверх, прижат к поясам (грань x = -82.15 - 0.65 * y / 22)
	b.pipe(Vector3(-80.38, 2.1, 13.3), Vector3(-82.25, 2.3, 13.5), 0.025, wire)
	b.pipe(Vector3(-82.25, 2.3, 13.5), Vector3(-82.59, 13.75, 13.5), 0.02, wire)
	var it := Interactable.make(root, Vector3(-80.18, 0.9, 13.5), Vector3(0.6, 1.3, 0.7), "Починить фидер", func() -> void: G.act("feeder"), 20.0)
	it.keep_progress = true
	it.need_light = true
	it.on_hold = func(active: bool) -> void: G.act("feeder_on" if active else "feeder_off")
	w.things["feeder"] = it
	# полка вплотную к стене (лицо z = 14.65) на двух кронштейнах
	b.box(Vector3(-79.2, 0.9, 14.515), Vector3(0.9, 0.04, 0.28), Kit.mat("plankgrey", 1.5), false)
	b.box(Vector3(-79.5, 0.83, 14.56), Vector3(0.03, 0.12, 0.2), Kit.mat("plankgrey", 1.5), false)
	b.box(Vector3(-78.9, 0.83, 14.56), Vector3(0.03, 0.12, 0.2), Kit.mat("plankgrey", 1.5), false)
	var n4 := Props.paper(root, Vector3(-79.2, 0.925, 14.515), 10.0, "gr4", true, Vector2(0.17, 0.24), true)
	w.things["note_gr4"] = n4
	# табурет у северной стены: открытая внутрь дверь (полотно до z ≈ 12.95) его не задевает
	Kit.put(root, "stool2", Vector3(-78.8, FY, 12.62), 0.0, 1.0, true)
	b.commit(root, "Static")
	Props.drift_wall(root, Vector3(-79.4, -0.02, 12.24), Vector3(0, 0, -1), Vector3(2.6, 0.9, 1.4))
	Props.drift_wall(root, Vector3(-80.66, -0.02, 13.5), Vector3(-1, 0, 0), Vector3(2.6, 1.0, 1.5))
	w.add_zone("hut", Vector3(x0, -1, z0), Vector3(x1 + 0.08, h, z1), "wood", 1.0, 1.0)
	w.places["hut_in"] = [Vector3(-79.0, FY, 13.5), 90.0]


# ------------------------------------------------------------------ вертолётная площадка

static func _pad(w: World) -> void:
	var root := Node3D.new()
	root.name = "Pad"
	w.add_child(root)
	var b := Batch.new()
	var c := Map.PAD
	var wood := Kit.mat("plankgrey", 1.5)
	var rd := Kit.flat(Color(0.75, 0.08, 0.06), 0.7)
	for i in 12:
		# сдвиг на 15°: леер «Д» входит между столбиками, а не упирается в северный
		var p := c + Kit.yaw(i * 30.0 + 15.0) * Vector3(9.0, 0, 0)
		b.box(p + Vector3(0, 0.35, 0), Vector3(0.1, 0.9, 0.1), wood, false)
		b.box(p + Vector3(0, 0.84, 0), Vector3(0.11, 0.12, 0.11), rd, false)
	var spots := [c + Vector3(0, 0, -6.5), c + Vector3(5.6, 0, 3.3), c + Vector3(-5.6, 0, 3.3)]
	var barrels: Array = []
	for i in 3:
		var p: Vector3 = spots[i]
		Kit.put(root, "drumred", p, i * 50.0, 1.0, true)
		var fl := Kit.omni(root, p + Vector3(0, 1.3, 0), Color(1.0, 0.42, 0.12), 0.0, 13.0, true, 90.0)
		fl.visible = false
		var hl := Kit.halo(root, p + Vector3(0, 1.3, 0), Color(1.0, 0.45, 0.15), 2.4, 2.2)
		(hl.material_override as ShaderMaterial).set_shader_parameter("vis_scale", 1.6)
		hl.visible = false
		var snd := Snd.emitter("fire_loop", root, p + Vector3(0, 1.0, 0), -2.0, 30.0, 3.0)
		var idx := i
		var it := Interactable.make(root, p + Vector3(0, 0.7, 0), Vector3(0.8, 1.3, 0.8), "Зажечь бочку", func() -> void: G.act("barrel_%d" % idx), 3.0)
		barrels.append({"pos": p, "light": fl, "halo": hl, "snd": snd, "it": it, "lit": false, "t": 0.0})
	w.things["barrels"] = barrels
	# ветроуказатель
	var wp := c + Vector3(8.0, 0, -6.0)
	# мачта проходит кольцо раструба насквозь (низ 4,11, верх 4,49) и выходит штырём на 3 см
	b.cyl(wp + Vector3(0, 2.26, 0), 0.04, 4.52, wood, 6, true)
	var sx := Weather.WIND_DIR.cross(Vector3.UP).normalized()
	# конус открыт с обоих концов: ткань рисуется и изнутри, иначе сквозь раструб видно фон
	var cloth := Kit.flat(Color(0.9, 0.4, 0.08), 0.8).duplicate() as StandardMaterial3D
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	var sock := Kit.mesh_node(root, Kit.lathe(PackedVector2Array([Vector2(0.2, 0.0), Vector2(0.15, 0.5), Vector2(0.08, 1.2)]), 10), wp + Vector3(0, 4.3, 0),
		cloth, Basis(sx, Weather.WIND_DIR, sx.cross(Weather.WIND_DIR)))
	sock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# табличка лицом на север, к идущему по лееру «Д»: доска перед своим столбиком, в стороне от прохода у троса
	# (раньше столбик торчал сквозь доску, а доска стояла там, где идёт игрок, держась за трос)
	Props.sign_board(root, c + Vector3(-1.65, 1.5, -8.046), 180.0, "ПЛОЩАДКА", 0.075)
	b.box(c + Vector3(-1.65, 0.735, -8.0), Vector3(0.07, 1.67, 0.07), wood, false)
	b.commit(root, "Static")
	w.places["pad_in"] = [c + Vector3(0, 0, -2.0), 180.0]


# ------------------------------------------------------------------ старый балок

static func _balok(w: World) -> void:
	var root := Node3D.new()
	root.name = "Balok"
	w.add_child(root)
	var b := Batch.new()
	var ext := Kit.mat("sidebrown", 2.0, Color(0.75, 0.75, 0.78))
	var inn := Kit.mat("wallraw", 2.0, Color(0.5, 0.47, 0.44))
	var x0 := -50.5
	var x1 := -45.5
	var z0 := -91.0
	var z1 := -88.0
	var h := 2.15
	b.box(Vector3(-48.0, FY - 0.1, -89.5), Vector3(5.2, 0.2, 3.2), Kit.mat("floorwood", 2.0, Color(0.6, 0.6, 0.6)))
	# стены по x0/x1 на 5 мм короче: их внутренний слой совпадал с наружной гранью стен wall_x (полоса 6 см на углах мерцала)
	Walls.wall_z(b, x0, z0 - 0.055, z1 + 0.055, 0, h, 0.12, ext, inn, [], false, true)
	Walls.wall_z(b, x1, z0 - 0.055, z1 + 0.055, 0, h, 0.12, inn, ext, [[-89.5, 0.82, 0.0, 1.9]], true, false)
	# северная и южная стены на 2 мм наружу: обшивка перекрывает торцы боковых стен (была одна плоскость — мерцание у углов)
	Walls.wall_x(b, z0 - 0.002, x0, x1, 0, h, 0.12, ext, inn, [], false, true)
	Walls.wall_x(b, z1 + 0.002, x0, x1, 0, h, 0.12, inn, ext, [[-47.0, 0.6, 1.05, 1.6]], true, false)
	var gm := Walls.window(root, b, Vector3(-47.0, 1.325, z1), "x", 0.6, 0.55, 0.12, Vector3(0, 0, 1))
	# окно брошенного балка затянуто почти целиком
	(gm.get_meta("inner") as ShaderMaterial).set_shader_parameter("frost", 0.85)
	gm.emission_enabled = false
	b.box(Vector3(-48.0, h + 0.05, -89.5), Vector3(5.4, 0.1, 3.5), Kit.mat("corrugrust", 2.0, Color(0.5, 0.48, 0.48)))
	b.box(Vector3(-48.0, h - 0.02, -89.5), Vector3(4.9, 0.04, 2.9), inn, false)
	b.box(Vector3(-48.0, h + 0.3, -89.5), Vector3(5.3, 0.45, 3.4), _snow(), false)
	# доска на 5 мм выступает за торец пола: раньше их грани z = −87,9 совпадали (мерцала полоса 3 см у земли)
	b.box(Vector3(-48.0, 0.06, -87.995), Vector3(5.6, 0.14, 0.2), Kit.mat("plankgrey", 1.5), false)
	var d := Door.make(root, Vector3(x1, FY, -89.5 - 0.41), -90.0, 0.82, 1.88, Kit.mat("plankold", 1.6), -100.0, 0.05)
	w.doors["balok"] = d
	# вплотную к обшивке: наружная грань стены x1 + 0,06, доска 2 см
	Props.sign_board(root, Vector3(x1 + 0.071, 1.98, -88.6), 90.0, "СТ. «ТИХАЯ» 1961", 0.06, Color(0.5, 0.48, 0.42))
	# печь в северо-западном углу
	Kit.put(root, "stove", Vector3(-49.95, FY, -90.45), 45.0, 1.0, true)
	var rust := Kit.mat("metalrust", 1.0, Color(0.5, 0.45, 0.42))
	b.cyl(Vector3(-49.95, 1.9, -90.45), 0.07, 2.2, rust, 8, false)
	# у бочки открытый верх: крышка под закаткой (r 0,288 — в толще стенки), труба входит в неё
	b.cyl(Vector3(-49.95, FY + 0.82, -90.45), 0.288, 0.02, rust, 24, false)
	var fl := Kit.omni(root, Vector3(-49.5, 0.5, -90.0), Color(1.0, 0.45, 0.15), 0.0, 4.5, true, 30.0)
	fl.visible = false
	w.things["balok_stove_light"] = fl
	w.things["balok_stove"] = Interactable.make(root, Vector3(-49.95, 0.55, -90.45), Vector3(0.7, 0.95, 0.7), "Затопить печь", func() -> void: G.act("balok_stove"))
	w.things["balok_stove_snd"] = Snd.emitter("fire_loop", root, Vector3(-49.9, 0.5, -90.4), -80.0, 9.0, 1.6)
	Props.logs(b, Vector3(-49.3, FY, -90.85), true, 3, 2, 0.4, 31)
	# койка, стол с журналами, ящик НЗ
	Kit.lighten(Kit.put(root, "bed", Vector3(-47.6, FY, -90.5), 90.0, 1.0, true), 0.5)
	var bd := Batch.new()
	# полосы тика — вдоль матраса (uvrot): матрас здесь длинный по X, а полосы mattress.jpg идут по v (по Z) — шли поперёк
	bd.box(Vector3(-47.6, FY + 0.42, -90.5), Vector3(1.86, 0.1, 0.8), Kit.img("res://tex/mattress", false, false, 0.5), false, Basis.IDENTITY, true)
	bd.commit(root, "OldMattress", false)
	var wood := Kit.mat("plankgrey", 1.5)
	b.box(Vector3(-47.0, 0.74, -88.42), Vector3(1.3, 0.05, 0.6), wood)
	for lx in [-47.58, -46.42]:
		b.box(Vector3(lx, 0.36, -88.42), Vector3(0.06, 0.72, 0.5), wood, false)
	w.things["note_log61a"] = Props.paper(root, Vector3(-47.25, 0.77, -88.42), 6.0, "log61a", true, Vector2(0.21, 0.29))
	w.things["note_log61b"] = Props.paper(root, Vector3(-46.95, 0.772, -88.38), -12.0, "log61b", true, Vector2(0.21, 0.29))
	Kit.put(root, "lantern", Vector3(-46.55, 0.765, -88.35), 0.0, 1.0, false, false)
	Kit.put(root, "compass", Vector3(-47.5, 0.765, -88.28), 40.0, 1.0, false, false)
	Kit.put(root, "stool2", Vector3(-47.0, FY, -89.1), 0.0, 1.0, true)
	var nz := Kit.put(root, "crate1", Vector3(-46.1, FY, -90.55), 0.0, 1.0, true)
	w.things["nz_crate"] = nz
	# краска на передней доске ящика (z −90,363), без тени; ниже накладки замка
	Kit.label(root, Vector3(-46.1, 0.205, -90.36), "НЗ", 0.12, Color(0.75, 0.1, 0.08), "head").cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.things["nz"] = Interactable.make(root, Vector3(-46.1, 0.3, -90.5), Vector3(0.9, 0.6, 0.5), "Ящик НЗ", func() -> void: G.act("nz"))
	# люк в ледник
	var hp := Vector3(-49.2, FY, -88.9)
	var hm := Batch.new()
	# доски крышки — поперёк железных полос (uvrot): в plankold доски идут по u и без поворота лежали вдоль полос по X
	hm.box(hp + Vector3(0, 0.02, 0), Vector3(0.9, 0.04, 0.9), Kit.mat("plankold", 1.2), false, Basis.IDENTITY, true)
	hm.box(hp + Vector3(0, 0.045, -0.3), Vector3(0.9, 0.012, 0.06), Kit.flat(Color(0.1, 0.1, 0.1), 0.5, 0.7), false)
	hm.box(hp + Vector3(0, 0.045, 0.3), Vector3(0.9, 0.012, 0.06), Kit.flat(Color(0.1, 0.1, 0.1), 0.5, 0.7), false)
	var hatch := hm.commit(root, "Hatch", false)
	w.things["hatch"] = hatch
	var ring := TorusMesh.new()
	ring.inner_radius = 0.045
	ring.outer_radius = 0.06
	# кольцо лежит на досках: верх крышки hp+0,04, полутолщина кольца 0,0075
	Kit.mesh_node(hatch, ring, hp + Vector3(0.3, 0.047, 0), Kit.flat(Color(0.1, 0.1, 0.1), 0.5, 0.7))
	w.things["hatch_it"] = Interactable.make(root, hp + Vector3(0, 0.15, 0), Vector3(0.95, 0.35, 0.95), "Открыть люк", func() -> void: G.act("hatch"), 2.5)
	w.things["hatch_pos"] = hp
	b.commit(root, "Static")
	# занесён по крышу с наветренной стороны
	# срез полукупола открыт: западный и южный кончаются ровно у юго-западного угла (z −87,94, x −50,56)
	Props.drift_wall(root, Vector3(-50.57, -0.02, -89.57), Vector3(-1, 0, 0), Vector3(3.26, 2.1, 2.6))
	Props.drift_wall(root, Vector3(-48.2, -0.02, -91.07), Vector3(0, 0, -1), Vector3(5.2, 2.0, 2.4))
	Props.drift_wall(root, Vector3(-49.38, -0.02, -87.93), Vector3(0, 0, 1), Vector3(2.36, 0.7, 1.2))
	w.add_zone("balok", Vector3(x0, -1, z0), Vector3(x1 + 0.08, h, z1), "wood", 1.0, 1.0)
	# капсула 0,3 м не задевает табурет (z ≥ −89,32) и койку (z ≤ −90,05)
	w.places["balok_in"] = [Vector3(-46.6, FY, -89.62), 90.0]


# ------------------------------------------------------------------ ледник

static func _cellar(w: World) -> void:
	var root := Node3D.new()
	root.name = "Cellar"
	w.add_child(root)
	root.position = CELLAR
	var b := Batch.new()
	# лёд темнее: в луче фонаря ледник не должен светиться, как кафель
	# тёмный лёд с глубиной, трещинами и пузырьками (ice.gdshader); раньше — светлый «кафель» с яркими швами
	var ice := ShaderMaterial.new()
	ice.shader = load("res://src/shaders/ice.gdshader")
	ice.set_shader_parameter("crack_tex", Kit.tex("res://tex/ice_d"))
	ice.set_shader_parameter("noise_tex", Kit.tex("res://tex/noise"))
	ice.set_shader_parameter("floor_y", CELLAR.y)
	ice.set_shader_parameter("ceil_y", CELLAR.y + 2.05)
	var icef := ice.duplicate() as ShaderMaterial
	icef.set_shader_parameter("is_floor", true)
	icef.set_shader_parameter("meters", 2.0)
	var dark := Kit.flat(Color(0.0, 0.0, 0.0), 1.0)
	var wood := Kit.mat("plankold", 1.5, Color(0.6, 0.6, 0.6))
	var hh := 2.05
	# помещения: [x0, x1, z0, z1, высота]
	var rooms := [[-1.0, 1.0, -1.0, 1.0, 2.6], [-0.5, 1.0, 1.0, 7.5, hh], [-0.5, 2.5, 6.0, 7.5, hh], [1.0, 2.5, 7.5, 14.0, hh],
		[0.0, 3.5, 14.0, 17.5, 2.3], [-2.0, -0.5, 3.0, 5.0, hh], [2.5, 4.0, 9.5, 11.5, hh]]
	# пол и потолок одной плитой на всё, стены — по контурам помещений
	b.box(Vector3(0.75, FY - 0.15, 8.2), Vector3(8.0, 0.3, 21.0), icef)
	for r in rooms:
		var rx0 := float(r[0])
		var rx1 := float(r[1])
		var rz0 := float(r[2])
		var rz1 := float(r[3])
		var rh := float(r[4])
		# низ и бока без верха: бок низкого потолка закрывает ступеньку к высокому (у люка 2,05→2,6 м, у скважины 2,05→2,3 м), иначе там чёрная щель
		b.box(Vector3((rx0 + rx1) * 0.5, rh + 0.2, (rz0 + rz1) * 0.5), Vector3(rx1 - rx0 + 0.6, 0.4, rz1 - rz0 + 0.6), ice, true, Basis.IDENTITY, false, 59)
	# стены: сетка 0,5 м — где клетка пустая, а сосед занят помещением, ставим лёд
	var cell := 0.5
	var gx0 := -3.0
	var gz0 := -2.0
	var nx := 15
	var nz := 41
	var open := {}
	for iz in nz:
		for ix in nx:
			var cx := gx0 + (ix + 0.5) * cell
			var cz := gz0 + (iz + 0.5) * cell
			for r in rooms:
				if cx > float(r[0]) and cx < float(r[1]) and cz > float(r[2]) and cz < float(r[3]):
					open[Vector2i(ix, iz)] = true
					break
	for iz in nz:
		for ix in nx:
			if open.has(Vector2i(ix, iz)):
				continue
			var near := false
			for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
				if open.has(Vector2i(ix, iz) + dv):
					near = true
					break
			if near:
				var jit := Vector3(sin(ix * 12.9 + iz * 78.2) * 0.06, 0, cos(ix * 3.7 + iz * 9.1) * 0.06)
				b.box(Vector3(gx0 + (ix + 0.5) * cell, 1.4, gz0 + (iz + 0.5) * cell) + jit, Vector3(cell + 0.14, 2.9, cell + 0.14), ice)
	# шахта люка: чёрный проём наверху и лестница
	b.box(Vector3(0, 2.58, -0.4), Vector3(0.95, 0.02, 0.95), dark, false)
	# лестница на 7 см дальше от стены: при z = -0,9 правая тетива и полступеней тонули в ледяном блоке (грань z = -0,870)
	for sx in [-0.28, 0.28]:
		b.box(Vector3(sx, 1.4, -0.83), Vector3(0.06, 2.8, 0.06), wood, false)
	for i in 8:
		b.box(Vector3(0, 0.3 + i * 0.32, -0.83), Vector3(0.6, 0.04, 0.05), wood, false)
	w.things["ladder_up"] = Interactable.make(root, Vector3(0, 1.2, -0.73), Vector3(0.8, 2.2, 0.4), "Подняться", func() -> void: G.act("ladder_up"), 1.2)
	# крепь: рамы из бруса вдоль хода
	for fz in [2.2, 4.4, 5.9]:
		_frame(b, wood, Vector3(0.25, 0, fz), 1.3, hh)
	for fz in [8.8, 11.9, 13.6]:
		_frame(b, wood, Vector3(1.75, 0, fz), 1.3, hh)
	# ниши: туши под мешковиной и ящики
	# туши — капсулы: у CapsuleMesh полусферам и цилиндру отдано по трети v, мешковина тянулась вдоль туши
	# вдвое (1,15–1,24 м на повтор вместо 0,6). Своя копия с трипланаром в локальных координатах — 0,6 м во все стороны
	var sack := Kit.mat("hessian", 0.6, Color(0.5, 0.47, 0.42)).duplicate() as StandardMaterial3D
	sack.uv1_triplanar = true
	sack.uv1_triplanar_sharpness = 4.0
	for e in [[Vector3(-1.45, 1.2, 3.55), 0.25], [Vector3(-1.4, 1.15, 4.4), 0.22], [Vector3(3.3, 1.2, 10.0), 0.26], [Vector3(3.45, 1.1, 10.6), 0.2]]:
		var cp: Vector3 = e[0]
		var cr := float(e[1])
		Kit.capsule_node(root, cp, cr, 1.35, sack)
		# верёвка входит в макушку туши (верх капсулы — cp.y + 0,675; с 0,7 туша висела в 2,5 см под ней)
		b.beam(cp + Vector3(0, 0.65, 0), Vector3(cp.x, hh, cp.z), 0.012, Kit.flat(Color(0.1, 0.1, 0.1), 0.6, 0.6))
	# ящик не в ледяной стене ниши (дальний край был на 5–7 см в блоке)
	Kit.put(root, "crate1", Vector3(-1.1, FY, 4.62), 5.0, 1.0, true)
	# торец ящика не в восточной стене ниши
	Kit.put(root, "mcrate", Vector3(3.38, FY, 11.15), 0.0, 0.8, true)
	# бочка у входа в нишу: под тушей она торчала в мешковину на 19 см и в южную стену на 4 см
	Kit.put(root, "drumblue", Vector3(2.82, FY, 10.42), 0.0, 1.0, true)
	# камера со скважиной
	var bh := Vector3(1.75, 0, 15.5)
	var steel := Kit.mat("metalrust", 1.0, Color(0.45, 0.42, 0.42))
	# обсадная труба открыта сверху: с правильным обходом Batch.cyl её внутренняя стенка не рисовалась бы — материал с двух сторон
	var steel2 := steel.duplicate() as StandardMaterial3D
	steel2.cull_mode = BaseMaterial3D.CULL_DISABLED
	b.cyl(bh + Vector3(0, 0.14, 0), 0.34, 0.28, steel2, 16, false, Basis.IDENTITY, false)
	b.cyl(bh + Vector3(0, 0.05, 0), 0.29, 0.12, dark, 16, false)
	b.solid(bh + Vector3(0, 0.15, 0), Vector3(0.7, 0.3, 0.7))
	for ang in [0.0, 120.0, 240.0]:
		var dv := Kit.yaw(ang) * Vector3(0.9, 0, 0)
		b.beam(bh + dv, bh + Vector3(0, 2.2, 0), 0.05, steel)
	w.things["borehole"] = CELLAR + bh
	w.things["gromov_spot"] = [CELLAR + Vector3(1.75, FY, 17.1), 0.0]
	var n7 := Props.paper(root, Vector3(1.05, FY + 0.005, 16.75), 40.0, "gr7", true, Vector2(0.17, 0.24), true)
	w.things["note_gr7"] = n7
	w.things["flaregun"] = Interactable.make(root, Vector3(1.75, 0.5, 16.75), Vector3(0.6, 0.7, 0.5), "Взять ракетницу", func() -> void: G.act("flaregun"), 1.5)
	b.commit(root, "Static")
	w.add_zone("cellar", CELLAR + Vector3(-3.2, -1, -2.2), CELLAR + Vector3(4.6, 3.5, 18.6), "ice", 1.0, 1.0)
	w.places["cellar"] = [CELLAR + Vector3(0, FY, 0.3), 180.0]
	w.places["cellar_end"] = [CELLAR + Vector3(1.75, FY, 14.3), 180.0]


static func _frame(b: Batch, wood: Material, c: Vector3, width: float, hh: float) -> void:
	b.box(c + Vector3(-width * 0.5, hh * 0.5, 0), Vector3(0.12, hh, 0.12), wood, false)
	b.box(c + Vector3(width * 0.5, hh * 0.5, 0), Vector3(0.12, hh, 0.12), wood, false)
	b.box(c + Vector3(0, hh - 0.07, 0), Vector3(width + 0.1, 0.14, 0.14), wood, false)
