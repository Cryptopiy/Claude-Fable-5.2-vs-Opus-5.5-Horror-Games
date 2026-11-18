class_name BuildHouse
extends RefCounted
## Жилой дом станции: 10×6,4 м. Тамбур (ю-в), спальня (с-в), кают-компания (середина),
## радиорубка (с-з), кладовая (ю-з). Дверь наружу — в восточной стене.

const FY := 0.03       # верх пола
const H := 2.5         # высота потолка


static func build(w: World) -> void:
	var root := Node3D.new()
	root.name = "House"
	w.add_child(root)
	var b := Batch.new()
	_shell(w, root, b)
	_main_room(w, root, b)
	_radio_room(w, root, b)
	_bunk_room(w, root, b)
	_store_room(w, root, b)
	_vestibule(w, root, b)
	_outside(w, root, b)
	_life(root, b)
	b.commit(root, "Static")
	# пыль в свете ламп
	w.things["dust"] = [_dust(root, Vector3(0.0, 1.3, 0.0), Vector3(1.8, 1.1, 3.0), 110),
		_dust(root, Vector3(-3.5, 1.3, -1.6), Vector3(1.4, 1.0, 1.5), 60),
		_dust(root, Vector3(3.5, 1.3, -1.6), Vector3(1.4, 1.0, 1.5), 60)]
	w.add_zone("vest", Vector3(2.0, -1, 0.0), Vector3(5.12, H, 3.3), "wood", 0.8, 0.6)
	w.add_zone("bunk", Vector3(2.0, -1, -3.3), Vector3(5.1, H, 0.0), "wood", 1.0, 0.0)
	w.add_zone("radio", Vector3(-5.1, -1, -3.3), Vector3(-2.0, H, 0.0), "wood", 1.0, 0.0)
	w.add_zone("store", Vector3(-5.1, -1, 0.0), Vector3(-2.0, H, 3.3), "wood", 1.0, 0.2)
	w.add_zone("house", Vector3(-2.0, -1, -3.3), Vector3(2.0, H, 3.3), "wood", 1.0, 0.0)
	w.places["bed"] = [Vector3(3.5, FY, -1.2), -90.0]
	w.places["main"] = [Vector3(0.0, FY, -1.4), 180.0]
	w.places["radio"] = [Vector3(-3.3, FY, -1.3), 90.0]
	w.places["store"] = [Vector3(-3.4, FY, 1.6), 90.0]
	w.places["vest"] = [Vector3(3.3, FY, 1.6), -90.0]
	w.places["door_out"] = [Vector3(6.4, 0, 1.6), 90.0]


static func _shell(w: World, root: Node3D, b: Batch) -> void:
	# вагонка: в текстуре 5 досок на повтор; при 2,2 м доска выходила 0,44 м (дверь — 4,5 доски). 1,1 м — доска 0,22 м
	var ext := Kit.mat("sidegreen", 1.1)
	# крашеные доски: грязь у пола, копоть под потолком, рыжие пятна приглушены, комнаты изношены по-разному
	var inn := ShaderMaterial.new()
	inn.shader = load("res://src/shaders/interior.gdshader")
	inn.set_shader_parameter("albedo_tex", Kit.tex("res://tex/wallpaint_d"))
	inn.set_shader_parameter("normal_tex", Kit.tex("res://tex/wallpaint_n"))
	inn.set_shader_parameter("rough_tex", Kit.tex("res://tex/wallpaint_r"))
	inn.set_shader_parameter("ceil_y", H)
	var flo := Kit.mat("floorwood", 2.0)
	var cei := Kit.mat("ceilwood", 2.2, Color(0.5, 0.48, 0.43))
	b.box(Vector3(0, FY - 0.115, 0), Vector3(10.2, 0.23, 6.6), flo)
	# потолок на 2 см короче щипцов с каждой стороны: торцы плиты совпадали с треугольниками щипцов (x = ±5,1) и мерцали полосой 12 см
	b.box(Vector3(0, H + 0.06, 0), Vector3(10.16, 0.12, 6.6), cei)
	# наружные стены: снаружи вагонка, внутри крашеные доски
	# наружные стены стоят на полу (от FY): снизу они совпадали с торцами плиты пола — полоса 3 см по периметру мерцала
	Walls.wall_x(b, -3.2, -5.1, 5.1, FY, H, 0.2, ext, inn, [[0.0, 1.0, 1.0, 1.9], [3.4, 0.8, 1.05, 1.85]], false, true)
	Walls.wall_x(b, 3.2, -5.1, 5.1, FY, H, 0.2, inn, ext, [[0.0, 1.0, 1.0, 1.9]], true, false)
	Walls.wall_z(b, -5.0, -3.1, 3.1, FY, H, 0.2, ext, inn, [[-1.6, 0.9, 1.0, 1.9]], false, true)
	Walls.wall_z(b, 5.0, -3.1, 3.1, FY, H, 0.2, inn, ext, [[1.6, 0.95, 0.0, 2.0], [2.62, 0.42, 1.25, 1.68]], true, false)
	# перегородки
	Walls.wall_z(b, -2.0, -3.1, 3.1, 0, H, 0.12, inn, inn, [[-1.6, 0.86, 0.0, 1.99], [1.6, 0.86, 0.0, 1.99]], true, true)
	Walls.wall_z(b, 2.0, -3.1, 3.1, 0, H, 0.12, inn, inn, [[-1.6, 0.86, 0.0, 1.99], [1.6, 0.86, 0.0, 1.99]], true, true)
	Walls.wall_x(b, 0.0, -4.9, -2.06, 0, H, 0.12, inn, inn, [], true, true)
	Walls.wall_x(b, 0.0, 2.06, 4.9, 0, H, 0.12, inn, inn, [], true, true)
	# окна
	for e in [[Vector3(0, 1.45, -3.2), "x", 1.0, 0.9, Vector3(0, 0, -1)], [Vector3(3.4, 1.45, -3.2), "x", 0.8, 0.8, Vector3(0, 0, -1)],
			[Vector3(0, 1.45, 3.2), "x", 1.0, 0.9, Vector3(0, 0, 1)], [Vector3(-5.0, 1.45, -1.6), "z", 0.9, 0.9, Vector3(-1, 0, 0)],
			[Vector3(5.0, 1.465, 2.62), "z", 0.42, 0.43, Vector3(1, 0, 0)]]:
		var gm := Walls.window(root, b, e[0], String(e[1]), float(e[2]), float(e[3]), 0.2, e[4])
		w.reg_glow(gm)
		w.window_mats.append(gm.get_meta("inner"))
		# окно видно издалека: по нему находят дом, когда леера нет
		var wc: Vector3 = e[0]
		var wo: Vector3 = e[4]
		var wh := Kit.halo(root, wc + wo * 0.25, Color(1.0, 0.72, 0.36), 1.1, 1.2)
		(wh.material_override as ShaderMaterial).set_shader_parameter("vis_scale", 1.8)
		(wh.material_override as ShaderMaterial).set_shader_parameter("face", wo)
		w.reg_halo(wh)
	# крыша: два ската, снег, щипцы, труба
	var roof := Kit.mat("corrug", 2.0, Color(0.7, 0.72, 0.75))
	var snow := Kit.snow()
	var a := deg_to_rad(18.43)
	for sgn in [-1.0, 1.0]:
		var rot := Basis(Vector3.RIGHT, sgn * a)
		var c := Vector3(0, 3.225, sgn * 1.875)
		b.box(c, Vector3(11.0, 0.07, 3.98), roof, false, rot)
		b.box(c + rot * Vector3(0, 0.13, 0.12), Vector3(10.9, 0.2, 3.7), snow, false, rot)
	for x in [-5.1, 5.1]:
		b.tri(Vector3(x, H, -3.3), Vector3(x, H, 3.3), Vector3(x, 3.6, 0), Vector3(signf(x), 0, 0), ext, Vector3(0, 0, 1), Vector3(0, -1, 0))
	var rust := Kit.mat("metalrust", 1.0, Color(0.5, 0.45, 0.42))
	# труба - от крышки печи (0,886) до 4,5
	b.cyl(Vector3(-1.5, 2.693, 0), 0.075, 3.614, rust, 10, false)
	b.cyl(Vector3(-1.5, 4.56, 0), 0.13, 0.1, rust, 10, false)
	# двери
	var dm := Kit.mat("plankold", 1.6)
	var out := Door.make(root, Vector3(5.0, FY, 1.125), -90.0, 0.95, 1.97, dm, -100.0, 0.06)
	out.add_bar(1.0)
	w.doors["house"] = out
	var bar := Interactable.make(root, Vector3(4.82, 1.05, 2.3), Vector3(0.22, 0.4, 0.3), "Задвинуть засов", func() -> void: G.act("bar"))
	w.things["bar"] = bar
	var dmi := Kit.mat("wallblue", 1.6, Color(0.85, 0.85, 0.85))
	var d_bunk := Door.make(root, Vector3(2.0, FY, -2.03), -90.0, 0.86, 1.96, dmi, 96.0, 0.04)
	var d_vest := Door.make(root, Vector3(2.0, FY, 1.17), -90.0, 0.86, 1.96, dmi, 96.0, 0.04)
	var d_radio := Door.make(root, Vector3(-2.0, FY, -2.03), -90.0, 0.86, 1.96, dmi, -96.0, 0.04)
	var d_store := Door.make(root, Vector3(-2.0, FY, 1.17), -90.0, 0.86, 1.96, dmi, -96.0, 0.04)
	w.doors["bunk"] = d_bunk
	w.doors["vest"] = d_vest
	w.doors["radio"] = d_radio
	w.doors["store"] = d_store
	d_bunk.set_open(true, true)
	d_radio.set_open(true, true)
	d_store.set_open(true, true)


static func _main_room(w: World, root: Node3D, b: Batch) -> void:
	# свет тусклее и с тенью: тёмные углы, мебель отбрасывает тени (раньше ровная заливка)
	w.things["main_lamp"] = Props.ceil_lamp(w, root, Vector3(0.0, H, -0.2), 1.15, 6.0, Color(1.0, 0.78, 0.5), true)
	# печь-бочка у западной перегородки, между дверями
	var stove := Kit.put(root, "stove", Vector3(-1.52, FY, 0.0), 90.0, 1.0, true)
	b.box(Vector3(-1.5, FY + 0.01, 0.0), Vector3(0.9, 0.02, 1.0), Kit.mat("metalplate", 1.0, Color(0.5, 0.5, 0.5)), false)
	# с тенью, как печь в балке: огонь стоит в 0,9 м от западной перегородки и без тени рыжим мерцанием светил
	# сквозь неё (ящик в кладовой 0,79 при нуле от её лампы, стул радиста 0,16 против 0,03; в ночи 2 и 5 без дизеля
	# тёмные комнаты мерцали). Прожектор не годится: он гасит переднюю стенку печи и лист перед ней
	var fire := Kit.omni(root, Vector3(-1.05, 0.5, 0.0), Color(1.0, 0.45, 0.15), 0.0, 4.5, true, 30.0)
	fire.visible = false
	w.things["stove_light"] = fire
	w.things["stove"] = Interactable.make(root, Vector3(-1.5, 0.55, 0.0), Vector3(0.7, 0.95, 0.7), "Подбросить дров", func() -> void: G.act("stove"))
	w.things["stove_snd"] = Snd.emitter("fire_loop", root, Vector3(-1.4, 0.5, 0.0), -8.0, 9.0, 1.6)
	# у модели печи открытый верх (бортик 0,886 при r 0,28..0,296): кладём крышку на бортик,
	# чайник - сбоку от трубы (труба r 0,075 шла прямо сквозь чайник)
	b.cyl(Vector3(-1.52, FY + 0.85, 0.0), 0.29, 0.012, Kit.mat("metalrust", 1.0, Color(0.5, 0.45, 0.42)), 24, false)
	Kit.put(root, "kettle", Vector3(-1.52, FY + 0.856, 0.19), 30.0, 0.8, false, false)
	# торцы поленьев (полудлина до 0,21 + сдвиг 0,02) не уходят в перегородку (грань x = -1,94)
	Props.logs(b, Vector3(-1.71, FY, 0.52), true, 3, 2, 0.4, 5)
	# стол и стулья
	Kit.put(root, "table", Vector3(0.78, FY, 0.9), 90.0, 0.72, true)
	Kit.put(root, "chair", Vector3(-0.02, FY, 0.55), -90.0, 0.75, true)
	# второй стул — в торце стола, у шахмат. Не ставить между столом и восточной перегородкой:
	# там проход 0,75 м к двери в тамбур — единственный выход из дома, стул его перекрывал.
	Kit.tint(Kit.put(root, "chairw", Vector3(0.78, FY, 2.1), 180.0, 1.0, true), Color(0.62, 0.6, 0.55), 0.1)
	# верх столешницы 0,7202: предметы ставим на него (было +5 мм над столом)
	var ty := FY + 0.691
	var lant := Kit.put(root, "lantern", Vector3(0.62, ty, 0.3), 20.0, 1.0, false, false)
	w.things["lantern"] = lant
	var ll := Kit.omni(root, Vector3(0.62, ty + 0.22, 0.3), Color(1.0, 0.62, 0.25), 0.0, 5.0, true, 30.0)
	ll.visible = false
	w.things["lantern_light"] = ll
	w.things["lantern_it"] = Interactable.make(root, Vector3(0.62, ty + 0.15, 0.3), Vector3(0.22, 0.34, 0.22), "Зажечь лампу", func() -> void: G.act("lantern"))
	Kit.put(root, "journal", Vector3(0.82, ty, 0.82), 80.0, 1.0, false, false)
	w.things["journal"] = Interactable.make(root, Vector3(0.82, ty + 0.05, 0.82), Vector3(0.36, 0.14, 0.5), "Журнал станции", func() -> void: G.act("journal"))
	w.things["note_gr1"] = Props.paper(root, Vector3(0.56, ty + 0.004, 1.22), 25.0, "gr1", true, Vector2(0.17, 0.24), true)
	var chess := Kit.put(root, "chess", Vector3(0.9, ty, 1.52), 0.0, 0.52, false, false)
	Kit.lighten(chess, 0.35)
	w.things["chess"] = chess
	Kit.put(root, "thermos", Vector3(1.05, ty, 0.3), 0.0, 1.0, false, false)
	# буфет у северной стены, справа от окна
	Kit.put(root, "cabinet", Vector3(1.28, FY, -2.75), 0.0, 1.0, true)
	var cy := FY + 1.18
	Kit.put(root, "mclock", Vector3(1.3, cy, -2.8), 0.0, 1.0, false, false)
	w.things["clock_snd"] = Snd.emitter("clock_loop", root, Vector3(1.3, cy + 0.1, -2.8), -14.0, 7.0, 1.2)
	Kit.put(root, "pot", Vector3(0.88, cy, -2.74), 0.0, 1.0, false, false)
	# три набора консервов (длина набора 0,14) с промежутками около 4,5 см - раньше шаг 8 см, наборы входили друг в друга на 2,5 см
	for e in [[1.64, -2.6, 0.0], [1.69, -2.72, 25.0], [1.66, -2.86, -15.0]]:
		Kit.put(root, "cans", Vector3(float(e[0]), cy, float(e[1])), float(e[2]), 1.0, false, false)
	# стеллаж с книгами у южной стены, слева от окна
	Kit.put(root, "bookshelf", Vector3(-1.2, FY, 2.78), 180.0, 0.92, true)
	# верх полок стеллажа: 0,13 / 0,39 / 0,65 / 0,914 / 1,204 / 1,56; книги (0,237) помещаются только с 0,914
	for sy in [0.884, 1.174, 1.53]:
		var bk := Kit.put(root, "books", Vector3(-1.35, FY + sy, 2.8), 180.0, 1.0, false, false)
		Kit.lighten(bk, 0.3)
	# на стенах: схема станции, календарь, памятка
	var mapq := Kit.quad_node(root, Vector3(1.1, 1.5, 3.094), Vector2(0.8, 0.8), Kit.img("res://tex/map"), Kit.yaw(180))
	w.things["wallmap"] = Interactable.make(root, Vector3(1.1, 1.5, 3.0), Vector3(0.9, 0.64, 0.2), "Схема станции", func() -> void: G.act("wallmap"))
	mapq.name = "WallMap"
	Kit.quad_node(root, Vector3(-0.95, 1.55, -3.094), Vector2(0.3, 0.42), Kit.img("res://tex/calendar"))
	var memo := Props.paper(root, Vector3(1.936, 1.5, 0.72), -90.0, "memo", false, Vector2(0.26, 0.36))
	w.things["note_memo"] = memo


static func _radio_room(w: World, root: Node3D, b: Batch) -> void:
	Props.ceil_lamp(w, root, Vector3(-3.4, H, -1.5), 0.75, 4.2)
	# стол радиста у западной стены, под окном
	Kit.put(root, "desk", Vector3(-4.5, FY, -1.6), 90.0, Vector3(0.85, 1.0, 0.78), true)
	var ty := FY + 0.7875   # верх столешницы (замер: 0,8175)
	var radio := Kit.put(root, "radio", Vector3(-4.58, ty, -1.82), 90.0, 1.0, false, false)
	Kit.lighten(radio, 0.5)
	Kit.put(root, "rxpanel", Vector3(-4.66, ty, -1.05), 90.0, 1.0, false, false)
	# стол кончается на z = -0,75: прибор целиком на столешнице, между приёмником и краем
	Kit.put(root, "meter", Vector3(-4.42, ty, -0.88), 70.0, 1.0, false, false)
	var dl := Kit.put(root, "desklamp", Vector3(-4.72, ty, -2.42), 135.0, 0.7, false, false)
	Kit.lighten(dl, 0.4)
	var dll := Kit.omni(root, Vector3(-4.45, ty + 0.42, -2.2), Color(1.0, 0.82, 0.55), 0.7, 2.6, false, 30.0)
	w.reg_light(dll)
	# ключ Морзе: дощечка, рычаг, головка
	var brass := Kit.flat(Color(0.55, 0.45, 0.2), 0.4, 0.8)
	b.box(Vector3(-4.3, ty + 0.012, -1.45), Vector3(0.09, 0.024, 0.16), Kit.flat(Color(0.12, 0.1, 0.08), 0.6), false)
	b.box(Vector3(-4.3, ty + 0.045, -1.45), Vector3(0.016, 0.012, 0.14), brass, false)
	b.cyl(Vector3(-4.3, ty + 0.062, -1.39), 0.02, 0.014, Kit.flat(Color(0.05, 0.05, 0.05), 0.5), 10, false)
	w.things["radio"] = Interactable.make(root, Vector3(-4.5, ty + 0.25, -1.65), Vector3(0.7, 0.6, 1.1), "Сесть за радио", func() -> void: G.act("radio"))
	w.things["radio_snd"] = Snd.emitter("radio_static", root, Vector3(-4.58, ty + 0.2, -1.82), -80.0, 14.0, 1.5)
	Kit.tint(Kit.put(root, "chairw", Vector3(-3.78, FY, -1.62), -90.0, 1.0, true), Color(0.62, 0.6, 0.55), 0.1)
	w.things["note_radiogram"] = Props.paper(root, Vector3(-4.28, ty + 0.004, -1.12), 80.0, "radiogram", true, Vector2(0.2, 0.15))
	w.things["note_gr2"] = Props.paper(root, Vector3(-4.3, ty + 0.004, -2.12), 100.0, "gr2", true, Vector2(0.17, 0.24), true)
	w.things["note_freq"] = Props.paper(root, Vector3(-4.894, 1.42, -0.62), 90.0, "freq", false, Vector2(0.22, 0.3))
	# отпечаток ладони на стекле изнутри (появляется на третью ночь)
	var hp := Kit.quad_node(root, Vector3(-4.975, 1.5, -1.38), Vector2(0.17, 0.23), Kit.img("res://tex/handprint", true), Kit.yaw(90))
	hp.visible = false
	w.things["handprint"] = hp
	# картотека сводок
	Kit.put(root, "drawers", Vector3(-3.0, FY, -2.84), 0.0, 1.0, true)
	# на крышке картотеки (1,785), а не на высоте боковых стоек (1,91); вершины бинокля на 5,6 мм выше низа его AABB
	Kit.put(root, "binoc", Vector3(-3.25, FY + 1.75, -2.84), 30.0, 1.0, false, false)


static func _bunk_room(w: World, root: Node3D, b: Batch) -> void:
	Props.ceil_lamp(w, root, Vector3(3.3, H, -1.4), 0.7, 4.2)
	# моя койка у восточной стены, головой на юг
	Kit.lighten(Kit.put(root, "bed", Vector3(4.4, FY, -1.15), 180.0, 1.0, true), 0.5)
	# матрас лежит на сетке койки (проволока до 0,526): низ 0,50, верх 0,62 - раньше сетка торчала сквозь матрас
	Props.bedding(root, Vector3(4.4, FY + 0.11, -1.15), 180.0, false)
	w.things["bed"] = Interactable.make(root, Vector3(4.4, 0.6, -1.15), Vector3(0.95, 0.7, 1.9), "Лечь спать", func() -> void: G.act("bed"))
	# коллизия койки накрывает этот объём сверху: без reach_in лечь можно было, только целясь в самый край
	(w.things["bed"] as Interactable).reach_in = 0.45
	# койка Громова у северной стены — заправлена
	Kit.lighten(Kit.put(root, "bed", Vector3(3.2, FY, -2.62), 90.0, 1.0, true), 0.5)
	w.things["gromov_bed"] = Props.bedding(root, Vector3(3.2, FY + 0.11, -2.62), 90.0, true)
	# та же койка, но на ней кто-то лежал: одеяло сбито, на матрасе иней
	var used := Props.bedding(root, Vector3(3.2, FY + 0.11, -2.62), 90.0, false)
	# иней на матрасе — по форме лежавшего тела
	var frost := Kit.flat(Color(0.82, 0.88, 0.95), 0.5)
	Kit.sphere_node(used, Vector3(-0.05, 0.485, -0.05), 1.0, frost, Vector3(0.24, 0.012, 0.74), 12).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Kit.sphere_node(used, Vector3(-0.05, 0.5, -0.74), 1.0, frost, Vector3(0.12, 0.012, 0.13), 10).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	used.visible = false
	w.things["gromov_bed_used"] = used
	# тумбочка Громова
	Kit.put(root, "nstand", Vector3(2.36, FY, -0.4), 90.0, 1.0, true)
	Kit.put(root, "alarm", Vector3(2.34, FY + 0.616, -0.3), 110.0, 1.0, false, false)   # верх тумбочки 0,6455
	w.things["nstand"] = Interactable.make(root, Vector3(2.36, 0.4, -0.4), Vector3(0.55, 0.7, 0.55), "Тумбочка Громова", func() -> void: G.act("nstand"))
	Kit.put(root, "stool", Vector3(3.62, FY, -0.42), 0.0, 1.0, true)
	Kit.put(root, "sigflash", Vector3(3.62, FY + 0.58, -0.42), 40.0, 1.0, false, false)
	var pc := Kit.place(root, "postcards", Vector3(4.89, 1.55, -1.5), -90.0, 0.8, false, false)
	if pc != null:
		# плоскость открыток в модели на z = 0,22: после поворота -90 она на 0,176 м ближе к комнате, чем узел,
		# поэтому узел ставим за грань стены (x = 4,90): открытки ложатся на стену с зазором 6 мм
		pc.position = Vector3(4.894 + 0.22 * 0.8, 1.55, -1.5 - 0.3)


static func _store_room(w: World, root: Node3D, b: Batch) -> void:
	Props.ceil_lamp(w, root, Vector3(-3.4, H, 1.6), 0.5, 4.0)
	Kit.put(root, "rack", Vector3(-4.56, FY, 0.72), 90.0, 1.0, true)
	Kit.put(root, "rack", Vector3(-4.56, FY, 1.72), 90.0, 1.0, true)
	Kit.put(root, "shelves", Vector3(-3.3, FY, 2.8), 180.0, 0.1, true)
	Kit.put(root, "mcrate", Vector3(-2.9, FY, 0.42), 0.0, 1.0, true)
	Kit.put(root, "crate1", Vector3(-2.95, FY + 0.46, 0.42), 8.0, 1.0, false)
	# верх полок стеллажей: 0,46 / 0,95 / 1,44 / 1,93; полок этажерки: 0,165 / 0,67 / 1,175 / 1,68 / 2,16
	Kit.put(root, "toolbox", Vector3(-4.55, FY + 0.92, 0.7), 80.0, 1.0, false, false)
	Kit.put(root, "medbox", Vector3(-4.55, FY + 1.41, 1.7), 90.0, 1.0, false, false)
	Kit.put(root, "gastank", Vector3(-4.6, FY, 2.72), 0.0, 1.0, true)
	for i in 4:
		Kit.put(root, "oiltin", Vector3(-4.56, FY + 0.43, 1.45 + i * 0.17), i * 25.0, 1.0, false, false)
	for i in 6:
		Kit.put(root, "cans", Vector3(-3.6 + (i % 3) * 0.2, FY + 1.146 + (i / 3) * 0.505, 2.78), i * 33.0, 1.3, false, false)
	Kit.put(root, "ammobox", Vector3(-3.0, FY + 0.64, 2.8), 90.0, 1.0, false, false)
	# моток запасного кабеля на стеллаже
	var cable := Node3D.new()
	# моток (полутолщина 0,026) лежит на полке стеллажа 0,95, а не висит над ней
	cable.position = Vector3(-4.52, FY + 0.946, 1.72)
	root.add_child(cable)
	var tm := TorusMesh.new()
	tm.inner_radius = 0.11
	tm.outer_radius = 0.17
	tm.rings = 14
	tm.ring_segments = 6
	Kit.mesh_node(cable, tm, Vector3.ZERO, Kit.flat(Color(0.04, 0.04, 0.04), 0.5))
	w.things["cable"] = cable
	w.things["cable_it"] = Interactable.make(root, Vector3(-4.52, FY + 0.996, 1.72), Vector3(0.45, 0.3, 0.45), "Взять кабель", func() -> void: G.act("cable"))
	# кабель лежит на полке стеллажа — внутри его коллизии: без reach_in луч упирался в стеллаж и кабель не брался
	(w.things["cable_it"] as Interactable).reach_in = 0.2
	# пирамида для карабина — пустая
	var wood := Kit.flat(Color(0.3, 0.22, 0.14), 0.85)
	b.box(Vector3(-2.5, 1.05, 0.085), Vector3(0.5, 0.06, 0.05), wood, false)
	b.box(Vector3(-2.5, 0.25, 0.1), Vector3(0.5, 0.08, 0.1), wood, false)
	w.things["note_gr5"] = Props.paper(root, Vector3(-2.5, 1.32, 0.066), 0.0, "gr5", false, Vector2(0.15, 0.1), true)


static func _vestibule(w: World, root: Node3D, b: Batch) -> void:
	Props.ceil_lamp(w, root, Vector3(3.4, H, 1.6), 0.45, 3.8)
	Kit.put(root, "bench", Vector3(3.3, FY, 2.82), 180.0, 1.0, true)
	# левый сапог не заходит в торец скамьи (x 3,847..3,882): сдвиг на 4,5 см к стене, до стены 11 см
	Kit.put(root, "boots", Vector3(4.345, FY, 2.6), 170.0, 1.0, false, false)
	# метла щёткой вдоль северной перегородки, левее лопаты: стоит на полу (раньше висела на 12 см и уходила щёткой в стену)
	Kit.put(root, "broom", Vector3(4.18, FY, 0.12), 0.0, 1.0, false, false)
	# лопата прислонена черенком к перегородке (верх у стены, низ в 18 см от неё); раньше наклон был от стены
	var sp := Kit.place(root, "spade", Vector3(4.55, FY + 0.496, 0.166), 0.0, 1.0, false, false)
	if sp != null:
		sp.rotation.x = deg_to_rad(-8)
	# ящик с дровами
	Kit.put(root, "crate2", Vector3(2.42, FY, 2.38), 0.0, 1.0, true)
	Props.logs(b, Vector3(2.24, FY + 0.46, 2.0), false, 3, 2, 0.5, 9)
	Props.logs(b, Vector3(2.24, FY + 0.46, 2.6), false, 3, 2, 0.5, 11)
	w.things["woodbox"] = Interactable.make(root, Vector3(2.42, 0.6, 2.38), Vector3(0.6, 0.6, 1.25), "Взять дрова", func() -> void: G.act("woodbox"))
	# вешалка: доска с крючками на северной перегородке
	var wood := Kit.flat(Color(0.3, 0.22, 0.14), 0.85)
	b.box(Vector3(3.5, 1.78, 0.075), Vector3(1.9, 0.1, 0.03), wood, false)   # вплотную к перегородке (грань z = 0,06)
	for i in 4:
		b.box(Vector3(2.8 + i * 0.47, 1.76, 0.12), Vector3(0.02, 0.02, 0.07), Kit.flat(Color(0.1, 0.1, 0.1), 0.5, 0.6), false)
	Props.parka(root, Vector3(2.8, 1.74, 0.1), 0.0, Color(0.16, 0.2, 0.3))
	var gp := Props.parka(root, Vector3(3.74, 1.74, 0.1), 0.0, Color(0.95, 0.42, 0.1))
	gp.visible = false
	w.things["gromov_parka"] = gp
	var br := Kit.place(root, "breaker", Vector3(4.89, 1.5, 0.55), -90.0, 1.0, false, false)
	w.things["breaker"] = br


## Следы жизни: кружки и миска на столе, бельё сушится на верёвке у печи.
static func _life(root: Node3D, b: Batch) -> void:
	var ty := FY + 0.691   # верх столешницы 0,7202
	var enamel := Kit.flat(Color(0.82, 0.8, 0.74), 0.35)
	var rim := Kit.flat(Color(0.12, 0.16, 0.3), 0.4)
	for e in [[Vector3(0.95, ty, 1.05), 20.0], [Vector3(0.48, ty, 0.62), 160.0]]:
		var p: Vector3 = e[0]
		b.cyl(p + Vector3(0, 0.045, 0), 0.04, 0.09, enamel, 10, false)
		b.cyl(p + Vector3(0, 0.091, 0), 0.041, 0.006, rim, 10, false)
		var hd := Kit.yaw(float(e[1])) * Vector3(0.05, 0, 0)
		b.box(p + hd + Vector3(0, 0.05, 0), Vector3(0.012, 0.05, 0.012), enamel, false)
	b.cyl(Vector3(0.62, ty + 0.02, 1.4), 0.09, 0.04, enamel, 12, false)
	b.cyl(Vector3(0.62, ty + 0.041, 1.4), 0.092, 0.005, rim, 12, false)
	# верёвка вдоль западной перегородки над печью и что на ней сушится
	var cord := Kit.flat(Color(0.5, 0.47, 0.4), 0.9)
	b.box(Vector3(-1.86, 2.05, 0.0), Vector3(0.008, 0.008, 1.7), cord, false)
	# концы верёвки - на гвоздях, вбитых в перегородку (грань x = -1,94); раньше верёвка висела в воздухе
	for zc in [-0.85, 0.85]:
		b.box(Vector3(-1.9, 2.05, float(zc)), Vector3(0.08, 0.01, 0.01), Kit.flat(Color(0.1, 0.1, 0.1), 0.5, 0.6), false)
	var towel := Kit.flat(Color(0.62, 0.6, 0.56), 0.95)
	var shirt := Kit.flat(Color(0.2, 0.24, 0.3), 0.95)
	var sock := Kit.flat(Color(0.35, 0.33, 0.3), 1.0)
	# полотенце наклонено на 3 градуса: верхний край уходит на 1,3 см - центр сдвинут, чтобы край лёг на верёвку (x = -1,86)
	b.box(Vector3(-1.873, 1.8, -0.45), Vector3(0.015, 0.5, 0.34), towel, false, Basis(Vector3.FORWARD, deg_to_rad(3)))
	b.box(Vector3(-1.85, 1.76, 0.2), Vector3(0.02, 0.58, 0.46), shirt, false)
	b.box(Vector3(-1.85, 1.95, 0.2), Vector3(0.018, 0.12, 0.72), shirt, false)
	# носки верхом на верёвке (верх 2,05), раньше висели на 2 см ниже неё
	for i in 2:
		b.box(Vector3(-1.85, 1.88, 0.62 + i * 0.11), Vector3(0.03, 0.34, 0.08), sock, false)


## Пыль: редкие пылинки медленно плавают в объёме комнаты; светятся только в настоящем свете.
static func _dust(root: Node3D, c: Vector3, ext: Vector3, n: int) -> GPUParticles3D:
	var gp := GPUParticles3D.new()
	gp.amount = n
	gp.lifetime = 14.0
	gp.preprocess = 14.0
	gp.local_coords = false
	gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gp.visibility_aabb = AABB(-ext - Vector3.ONE, ext * 2.0 + Vector3.ONE * 2.0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = ext
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.005
	pm.initial_velocity_max = 0.04
	pm.gravity = Vector3(0, -0.004, 0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.4
	pm.turbulence_noise_scale = 1.5
	pm.turbulence_influence_min = 0.01
	pm.turbulence_influence_max = 0.04
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0))
	grad.add_point(0.2, Color(1, 1, 1, 1))
	grad.add_point(0.8, Color(1, 1, 1, 1))
	grad.set_color(grad.get_point_count() - 1, Color(1, 1, 1, 0))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	gp.process_material = pm
	var qm := QuadMesh.new()
	qm.size = Vector2(0.007, 0.007)
	var sm := ShaderMaterial.new()
	sm.shader = load("res://src/shaders/dust.gdshader")
	qm.material = sm
	gp.draw_pass_1 = qm
	gp.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD
	gp.position = c
	root.add_child(gp)
	return gp


static func _outside(w: World, root: Node3D, b: Batch) -> void:
	var wood := Kit.mat("plankgrey", 1.5)
	# крыльцо и навес
	b.box(Vector3(5.75, -0.02, 1.6), Vector3(1.3, 0.1, 1.6), wood)
	# рёбра гофры — вдоль ската (uvrot): навес падает по +X, а рёбра corrug идут по v картинки — без поворота шли по Z, вдоль стены
	b.box(Vector3(5.7, 2.34, 1.6), Vector3(1.25, 0.06, 1.7), Kit.mat("corrug", 2.0, Color(0.7, 0.72, 0.75)), false, Basis(Vector3.BACK, deg_to_rad(-9)), true)
	# снег лежит на навесе (раньше зазор 2,2 см по нормали ската)
	b.box(Vector3(5.72, 2.44, 1.6), Vector3(1.2, 0.16, 1.6), Kit.snow(), false, Basis(Vector3.BACK, deg_to_rad(-9)))
	b.box(Vector3(6.28, 1.12, 0.84), Vector3(0.08, 2.24, 0.08), wood)
	b.box(Vector3(6.28, 1.12, 2.36), Vector3(0.08, 2.24, 0.08), wood)
	# лампа над дверью: 0,9 — плафон 0,39 м встаёт между проёмом (верх 2,0) и навесом (низ 2,40)
	var plamp := Kit.place(root, "walllamp", Vector3(5.1, 2.2, 1.6), 90.0, 0.9, false, false)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(1.0, 0.9, 0.7)
	gm.emission_enabled = true
	gm.emission = Color(1.0, 0.75, 0.42)
	gm.emission_energy_multiplier = 3.0
	gm.cull_mode = BaseMaterial3D.CULL_DISABLED
	# светится стекло плафона (в модели оно непрозрачное); колба внутри видна издали, когда модель скрыта
	if plamp != null:
		for mi in Kit.meshes(plamp):
			var m3: MeshInstance3D = mi
			if m3.mesh.get_surface_count() > 1:
				m3.set_surface_override_material(1, gm)
	Kit.sphere_node(root, Vector3(5.165, 2.2, 1.6), 0.04, gm, Vector3(1, 1.6, 1), 8).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.reg_glow(gm)
	# с тенью: без неё лампа (7,5 м, в 0,7 м от внутренней стороны стены) светила сквозь восточную стену —
	# пол тамбура был в 3 раза светлее, чем от его лампы, койка в спальне — вдвое; через открытую дверь свет по-прежнему входит
	var l := Kit.omni(root, Vector3(5.6, 2.1, 1.6), Color(1.0, 0.76, 0.42), 2.4, 7.5, true, 70.0)
	w.reg_light(l)
	var hl := Kit.halo(root, Vector3(5.3, 2.12, 1.6), Color(1.0, 0.72, 0.38), 1.4, 1.6)
	w.reg_halo(hl)
	w.things["porch_halo"] = hl
	# дровяник у восточной стены: навес и поленница
	# рёбра гофры — вдоль ската (uvrot): без поворота шли по Z, вдоль стены
	b.box(Vector3(5.75, 1.7, -2.1), Vector3(1.3, 0.05, 2.0), Kit.mat("corrugrust", 2.0, Color(0.5, 0.48, 0.48)), false, Basis(Vector3.BACK, deg_to_rad(-10)), true)
	# снег лежит на навесе (раньше зазор 1,3 см по нормали ската)
	b.box(Vector3(5.75, 1.8, -2.1), Vector3(1.25, 0.16, 1.9), Kit.snow(), false, Basis(Vector3.BACK, deg_to_rad(-10)))
	b.box(Vector3(6.32, 0.8, -3.02), Vector3(0.08, 1.6, 0.08), wood)
	b.box(Vector3(6.32, 0.8, -1.18), Vector3(0.08, 1.6, 0.08), wood)
	Props.logs(b, Vector3(5.42, 0.0, -2.95), true, 12, 7, 0.55, 21)
	b.solid(Vector3(5.45, 0.35, -2.1), Vector3(0.6, 0.7, 1.7))   # по верху поленницы (0,69 м), без невидимой стенки над ней
	b.cyl(Vector3(6.05, 0.2, -1.35), 0.2, 0.4, Kit.flat(Color(0.25, 0.19, 0.13), 0.9), 10, true)
	# топор воткнут в чурбак носком лезвия на 4 см, топорище приподнято на 15 градусов, смотрит на северо-восток.
	# Раньше стоял обухом вниз: голова целиком в чурбаке (на 19 см), лезвие торчало из его бока на 4 см
	var axe := Kit.place(root, "axe", Vector3(6.295, 0.633, -1.4915), -60.0, 1.0, false, false)
	if axe != null:
		axe.rotation.x = deg_to_rad(105)
	w.things["woodpile"] = Interactable.make(root, Vector3(5.5, 0.6, -2.1), Vector3(0.8, 1.2, 1.9), "Взять дрова", func() -> void: G.act("woodpile"))
	# лыжи у стены, бочка, сугробы
	# верхние концы лыж касаются обшивки (x = 5,1), а не уходят в неё на 4 см
	b.box(Vector3(5.176, 0.95, 2.95), Vector3(0.02, 1.9, 0.09), Kit.flat(Color(0.5, 0.3, 0.12), 0.6), false, Basis(Vector3.BACK, deg_to_rad(4)))
	b.box(Vector3(5.209, 0.95, 3.08), Vector3(0.02, 1.9, 0.09), Kit.flat(Color(0.5, 0.3, 0.12), 0.6), false, Basis(Vector3.BACK, deg_to_rad(6)))
	Kit.put(root, "drumblue", Vector3(5.6, 0.0, 3.9), 20.0, 1.0, true)
	# сугробы намело к стенам снаружи (с наветренной, северо-западной стороны — выше)
	Props.drift_wall(root, Vector3(-5.11, -0.02, -0.8), Vector3(-1, 0, 0), Vector3(4.6, 1.1, 2.0))
	Props.drift_wall(root, Vector3(-2.4, -0.02, -3.31), Vector3(0, 0, -1), Vector3(4.8, 0.95, 1.8))
	Props.drift_wall(root, Vector3(2.9, -0.02, -3.31), Vector3(0, 0, -1), Vector3(3.6, 0.6, 1.3))
	Props.drift_wall(root, Vector3(-3.6, -0.02, 3.31), Vector3(0, 0, 1), Vector3(3.0, 0.4, 1.2))
	Props.drift_wall(root, Vector3(1.6, -0.02, 3.31), Vector3(0, 0, 1), Vector3(3.6, 0.3, 1.0))
