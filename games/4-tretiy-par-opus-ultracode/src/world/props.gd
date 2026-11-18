class_name Props
## Мебель и предметы: общие помощники. Сами комнаты — PropsGround (первый этаж) и PropsBase (подвал, улица).

static var _models := {}
static var _cut_tex: Texture2D = null          # срезанные волосы на полу (рисуется в коде)
static var _cut_mat: StandardMaterial3D = null


static func furnish(w: Node3D) -> void:
	PropsGround.build(w)
	PropsBase.build(w)
	PropsBase.exterior(w)


## Угол поворота (rotation.y), чтобы «перед» (-Z) смотрел в направлении dir.
static func yaw_to(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)


## Модель Poly Haven (CC0) из mdl/ph/<id>.
static func model(parent: Node3D, id: String, pos: Vector3, yaw := 0.0, sc := 1.0, solid := false) -> Node3D:
	var path := "res://mdl/ph/%s/%s.gltf" % [id, id]
	var fresh := false
	if not _models.has(path):
		_models[path] = load(path) if ResourceLoader.exists(path) else null
		fresh = true
	var ps: PackedScene = _models[path]
	if ps == null:
		return Node3D.new()
	var n: Node3D = ps.instantiate()
	if fresh:
		_fix_glass(n)
	parent.add_child(n)
	n.global_position = pos
	n.rotation.y = yaw
	n.scale = Vector3.ONE * sc
	if solid:
		# коробка по габаритам модели в её собственных осях
		var inv := n.global_transform.affine_inverse()
		var la := AABB()
		var first := true
		for c in n.find_children("*", "MeshInstance3D", true, false):
			var mi := c as MeshInstance3D
			var a := inv * (mi.global_transform * mi.get_aabb())
			la = a if first else la.merge(a)
			first = false
		if not first and la.size.length() > 0.01:
			var bd := StaticBody3D.new()
			bd.collision_layer = 1
			n.add_child(bd)
			var cs := CollisionShape3D.new()
			var sh := BoxShape3D.new()
			sh.size = la.size
			cs.shape = sh
			cs.position = la.get_center()
			bd.add_child(cs)
	return n


## Стекло и пламя моделей Poly Haven: в glTF они «смешиваемые» (BLEND), но альфы в текстурах нет, а пропускание
## Blender не экспортируется — Godot рисовал их непрозрачными: чёрная колба лампы, чёрный диск на циферблате
## будильника, глухое окошко кассы и чайника, пламя — чёрная карточка. Материалы общие у всех копий модели
## (из одной PackedScene) — правятся один раз при первой загрузке.
## Godot импортирует glTF BLEND как ALPHA_DEPTH_PRE_PASS, а не ALPHA: проверять «прозрачный вообще», а ставить
## обычный ALPHA — в пре-пассе карточка пламени (альфа 1) писала глубину и закрывала комнату за собой.
static func _fix_glass(n: Node3D) -> void:
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(s) as StandardMaterial3D
			if m == null:
				m = mi.mesh.surface_get_material(s) as StandardMaterial3D
			# непрозрачные (стекло лампы-«тарелки» с пропусканием) не трогаем
			if m == null or m.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
				continue
			var nm := m.resource_name.to_lower()
			if nm.contains("glass"):
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				m.albedo_texture = null
				m.albedo_color = Color(0.75, 0.8, 0.8, 0.35 if nm.contains("kettle") else 0.18)
				m.metallic = 0.0
				m.metallic_texture = null
				m.roughness = 0.05
				m.roughness_texture = null
			elif nm.contains("flame"):
				# пламя на чёрном фоне: сложением чёрное ничего не добавляет, остаётся язычок
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
				m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				m.cull_mode = BaseMaterial3D.CULL_DISABLED
				m.albedo_color = Color(1.3, 1.25, 1.2)


static func _aabb(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var a := mi.global_transform * mi.get_aabb()
		if first:
			out = a
			first = false
		else:
			out = out.merge(a)
	return out


## Картинка на стене (табличка, плакат, фото). normal — куда смотрит лицо.
static func picture(parent: Node3D, tex: String, pos: Vector3, normal: Vector3, size: Vector2, opts := {}) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = size
	mi.mesh = qm
	mi.material_override = Mat.picture(tex, opts)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos + normal * 0.012
	mi.rotation.y = yaw_to(-normal)
	return mi


## Трап (сливная решётка в полу) — отсюда она выходит. Чугунная рамка и прутья над чёрной дырой: сквозь щели
## видна темнота (сплошная плита с рифлёной текстурой читалась рыжей плиткой на полу).
static func drain(w: World, b: Geo.Batch, pos: Vector3, room: String, register := true) -> void:
	var iron := Mat.m("rust", {"metal": 0.35, "tint": Color(0.4, 0.36, 0.33), "scale": 0.5, "wet": 0.5})
	b.box(Mat.flat(Color(0.02, 0.02, 0.02), 0.9), pos + Vector3(0, 0.002, 0), Vector3(0.32, 0.006, 0.32))
	for s in [-1.0, 1.0]:
		b.box(iron, pos + Vector3(0, 0.008, s * 0.13), Vector3(0.28, 0.012, 0.02))
		b.box(iron, pos + Vector3(s * 0.13, 0.008, 0), Vector3(0.02, 0.012, 0.24))
	for i in 5:
		b.box(iron, pos + Vector3(-0.084 + i * 0.042, 0.0075, 0), Vector3(0.018, 0.011, 0.24))
	if register:
		w.drains.append({"pos": pos, "room": room})
		if bool(w.rooms.get(room, {}).get("def", {}).get("wet", false)) or w.rooms.get(room, {}).get("def", {}).has("water"):
			if not w.rooms[room]["def"].has("water"):
				puddle(w.rooms[room]["node"], pos, randf_range(0.9, 1.6))


## Лужа у трапа: тёмное мокрое пятно с бликом (декаль меняет шероховатость пола). Только среднее/высокое качество.
static func puddle(parent: Node3D, pos: Vector3, size := 1.2) -> void:
	if Settings.quality < 1:
		return
	var dc := Decal.new()
	dc.size = Vector3(size, 0.3, size * randf_range(0.6, 1.0))
	dc.texture_albedo = Mat.tex("res://tex/gen/puddle.png")
	dc.texture_orm = Mat.tex("res://tex/gen/puddle_orm.png")
	dc.modulate = Color(0.55, 0.58, 0.6, 0.45)
	dc.albedo_mix = 0.8
	dc.cull_mask = 1
	dc.upper_fade = 0.2
	dc.lower_fade = 0.2
	# только на то, что смотрит вверх: у стены и перегородки лужа не «заползает» на них вертикальными потёками
	dc.normal_fade = 0.6
	parent.add_child(dc)
	dc.global_position = pos + Vector3(randf_range(-0.2, 0.2), 0.05, randf_range(-0.2, 0.2))
	dc.rotation.y = randf() * TAU


## Копоть на стене над топкой/дверцей. normal — куда смотрит стена.
static func soot(parent: Node3D, pos: Vector3, normal: Vector3, size := Vector2(1.0, 1.4)) -> void:
	if Settings.quality < 1:
		return
	var dc := Decal.new()
	dc.size = Vector3(size.x, 0.5, size.y)
	dc.texture_albedo = Mat.tex("res://tex/gen/soot.png")
	dc.modulate = Color(0.1, 0.09, 0.08, 0.9)
	dc.albedo_mix = 1.0
	dc.cull_mask = 1
	parent.add_child(dc)
	dc.global_position = pos
	# декаль проецирует вдоль своей -Y: повернуть её «лицом» к стене
	# декаль проецирует вдоль своей -Y: Y — наружу из стены, Z — вниз (верх картинки — вверху)
	dc.basis = Basis(normal.cross(Vector3.DOWN), normal, Vector3.DOWN)


## Соль на пороге: насыпанная неровная полоса — зернистая (снежная текстура), низкий валик посередине, края
## рассыпаются отдельными крупинками. Не белая лента: та в тёмных комнатах читалась светом из-под двери.
static func salt(b: Geo.Batch, center: Vector3, along_x: bool, length: float) -> void:
	var m := Mat.m("snow", {"tint": Color(0.85, 0.84, 0.8), "scale": 0.25})
	var turn := 0.0 if along_x else PI * 0.5
	var n := int(length / 0.03)
	for i in n:
		var t := -length * 0.5 + (i + randf()) * length / n
		var a := (randf() - randf()) * 0.06
		var h := lerpf(0.014, 0.004, absf(a) / 0.06) * randf_range(0.7, 1.0)
		var off := Vector3(t, h * 0.5, a) if along_x else Vector3(a, h * 0.5, t)
		b.box(m, center + off, Vector3(randf_range(0.03, 0.06), h, randf_range(0.02, 0.045)), Basis(Vector3.UP, turn + randf_range(-0.5, 0.5)))
	for i in int(length * 5.0):
		var t := randf_range(-0.5, 0.5) * length
		var a := randf_range(0.05, 0.12) * (1.0 if randf() < 0.5 else -1.0)
		var g := randf_range(0.012, 0.025)
		var off := Vector3(t, g * 0.2, a) if along_x else Vector3(a, g * 0.2, t)
		b.box(m, center + off, Vector3(g, g * 0.4, g), Basis(Vector3.UP, randf() * TAU))


## Деревянная скамья (простая).
static func bench(b: Geo.Batch, body: StaticBody3D, pos: Vector3, length: float, along_x: bool, back := false, mat: Material = null, seat_mat: Material = null) -> void:
	var m := mat if mat else Mat.m("planks_weather", {"tint": Color(0.85, 0.75, 0.6), "scale": 1.2})
	# ножки — крашеный металл шкафчиков (тот же материал — тот же меш в пакете), а не чёрные однотонные плиты
	var leg := Mat.m("metal_green", {"metal": 0.1, "tint": Color(0.75, 0.82, 0.78), "scale": 1.2})
	var sz := Vector3(length, 0.05, 0.42) if along_x else Vector3(0.42, 0.05, length)
	b.box(seat_mat if seat_mat else m, pos + Vector3(0, 0.45, 0), sz)
	var n := maxi(2, int(length / 1.5) + 1)
	for i in n:
		var t := -length * 0.5 + 0.1 + i * (length - 0.2) / (n - 1)
		var lp := pos + (Vector3(t, 0.22, 0) if along_x else Vector3(0, 0.22, t))
		b.box(leg, lp, Vector3(0.05, 0.44, 0.38) if along_x else Vector3(0.38, 0.44, 0.05))
	if back:
		# спинка нижним краем уходит в сиденье (низ 0.45): без просвета между ними
		var bp := pos + (Vector3(0, 0.925, 0.2) if along_x else Vector3(0.2, 0.925, 0))
		b.box(m, bp, Vector3(length, 0.95, 0.04) if along_x else Vector3(0.04, 0.95, length))
	if body:
		Geo.col_box(body, pos + Vector3(0, 0.25, 0), Vector3(sz.x, 0.5, sz.z))


## Ряд декоративных шкафчиков вдоль стены. normal — куда смотрят дверцы.
static func lockers(b: Geo.Batch, body: StaticBody3D, start: Vector3, count: int, dir: Vector3, normal: Vector3, tint := Color(0.75, 0.82, 0.78)) -> void:
	# краска по металлу: металличность 0.4 без отражений в окружении съедала почти половину и без того тёмного цвета
	var m := Mat.m("metal_green", {"metal": 0.1, "tint": tint, "scale": 1.2})
	var dark := Mat.flat(Color(0.05, 0.05, 0.05), 0.8)
	var W := 0.45
	var ax := absf(dir.x) > 0.5
	for i in count:
		var c := start + dir * (W * (i + 0.5))
		var size := Vector3(W - 0.01, 1.85, 0.5) if ax else Vector3(0.5, 1.85, W - 0.01)
		b.box(m, c + Vector3(0, 0.925, 0), size)
		for k in 4:
			b.box(dark, c + normal * 0.252 + Vector3(0, 1.45 + k * 0.04, 0), Vector3(W * 0.5, 0.012, 0.004) if ax else Vector3(0.004, 0.012, W * 0.5))
		# контур дверцы тёмной щелью: ряд читается отдельными шкафчиками, а не одним ящиком
		for sd in [-0.5, 0.5]:
			b.box(dark, c + normal * 0.251 + dir * ((W - 0.05) * sd) + Vector3(0, 0.95, 0), Vector3(0.006, 1.7, 0.004) if ax else Vector3(0.004, 1.7, 0.006))
		for yy in [0.1, 1.8]:
			b.box(dark, c + normal * 0.251 + Vector3(0, yy, 0), Vector3(W - 0.05, 0.006, 0.004) if ax else Vector3(0.004, 0.006, W - 0.05))
		b.box(Mat.flat(Color(0.5, 0.5, 0.45), 0.4, 0.9), c + normal * 0.255 + dir * (W * 0.35) + Vector3(0, 1.0, 0), Vector3(0.02, 0.08, 0.02))
	if body:
		var total := W * count
		var cc := start + dir * total * 0.5 + Vector3(0, 0.925, 0)
		Geo.col_box(body, cc, Vector3(total, 1.85, 0.5) if absf(dir.x) > 0.5 else Vector3(0.5, 1.85, total))


## Каменная (кафельная) лавка мыльной.
static func stone_bench(b: Geo.Batch, body: StaticBody3D, pos: Vector3, length: float, along_x: bool) -> void:
	var top := Mat.m("tile_dark", {"wet": 0.7, "scale": 1.0, "tint": Color(1.1, 1.1, 1.1)})
	var side := Mat.m("tile_wall", {"wet": 0.4})
	var sz := Vector3(length, 0.5, 0.6) if along_x else Vector3(0.6, 0.5, length)
	b.box(side, pos + Vector3(0, 0.22, 0), sz - Vector3(0.06, 0.06, 0.06))
	b.box(top, pos + Vector3(0, 0.48, 0), Vector3(sz.x, 0.06, sz.z))
	if body:
		# верх коллизии вровень с плитой (0.51): шайка стоит на лавке, а не тонет в ней
		Geo.col_box(body, pos + Vector3(0, 0.255, 0), sz + Vector3(0, 0.01, 0))


## Металлический стеллаж: стойки и полки. along_x — длинная сторона вдоль x.
static func shelves(b: Geo.Batch, body: StaticBody3D, pos: Vector3, length: float, depth: float, height: float, levels: int, along_x := true) -> void:
	# тёмная краска × оттенок 0.55 × металличность 0.5 давали чёрный силуэт без текстуры
	var m := Mat.m("metal_green", {"metal": 0.15, "tint": Color(0.8, 0.85, 0.8), "scale": 1.0})
	var lx := length if along_x else depth
	var lz := depth if along_x else length
	for sx in [-0.5, 0.5]:
		for sz in [-0.5, 0.5]:
			b.box(m, pos + Vector3(sx * (lx - 0.04), height * 0.5, sz * (lz - 0.04)), Vector3(0.04, height, 0.04))
	for i in levels:
		var y := 0.12 + i * (height - 0.2) / maxf(1.0, levels - 1)
		b.box(m, pos + Vector3(0, y, 0), Vector3(lx, 0.025, lz))
	if body:
		Geo.col_box(body, pos + Vector3(0, height * 0.5, 0), Vector3(lx, height, lz))


## Труба вдоль пути. Концы заглушены; на изгибах — круглая муфта (два коротких толстых патрубка по обе стороны
## колена), а не кубик поперёк круглой трубы.
static func pipe(b: Geo.Batch, pts: Array, r: float, mat: Material = null) -> void:
	var m := mat if mat else Mat.m("rust", {"metal": 0.5, "scale": 1.0})
	for i in range(1, pts.size()):
		b.cyl(m, pts[i - 1], pts[i], r, 10, true)
	for i in range(1, pts.size() - 1):
		var p: Vector3 = pts[i]
		var prev: Vector3 = pts[i - 1]
		var nxt: Vector3 = pts[i + 1]
		var d0 := (p - prev).normalized()
		var d1 := (nxt - p).normalized()
		b.cyl(m, p - d0 * r * 1.3, p + d0 * r * 0.25, r * 1.18, 10, true)
		b.cyl(m, p - d1 * r * 0.25, p + d1 * r * 1.3, r * 1.18, 10, true)


## Кран на стене + полочка. Возвращает Tap.
static func wall_tap(w: World, room: String, pos: Vector3, normal: Vector3, line: String) -> Tap:
	var y0: float = w.rooms[room]["y"]
	return Tap.make(w.rooms[room]["node"], pos, yaw_to(normal), false, line, room, y0)


static func shower(w: World, room: String, pos: Vector3, normal: Vector3, line: String) -> Tap:
	var y0: float = w.rooms[room]["y"]
	return Tap.make(w.rooms[room]["node"], pos, yaw_to(normal), true, line, room, y0)


## Мокрые босые следы (декали).
static func footprints(parent: Node3D, from: Vector3, to: Vector3, tag := "") -> Node3D:
	var n := Node3D.new()
	n.name = "footprints_" + tag
	parent.add_child(n)
	var d := to - from
	d.y = 0
	var len := d.length()
	var dir := d.normalized()
	var side := Vector3(-dir.z, 0, dir.x)
	var steps := int(len / 0.62)
	var tex: Texture2D = Mat.tex("res://tex/gen/footprint.png")
	for i in steps:
		var dc := Decal.new()
		dc.size = Vector3(0.16, 0.2, 0.34)
		dc.texture_albedo = tex
		dc.modulate = Color(0.25, 0.27, 0.28, 0.85)
		dc.albedo_mix = 0.9
		dc.cull_mask = 1
		dc.normal_fade = 0.6
		n.add_child(dc)
		var lr := 1.0 if i % 2 == 0 else -1.0
		dc.global_position = from + dir * (0.3 + i * 0.62) + side * lr * 0.12 + Vector3(0, 0.05, 0)
		# верх картинки (пальцы) декаль кладёт на свою −Z, а yaw_to направляет −Z по ходу: пальцы смотрят вперёд,
		# правый след — справа от пути, левый (отражённый scale.x) — слева
		dc.rotation.y = yaw_to(dir)
		dc.scale.x = lr
	return n


## Комок волос (свисает с потолка или лежит).
static func hair_clump(parent: Node3D, pos: Vector3, length := 1.0, hanging := true) -> void:
	if not hanging:
		_hair_floor(parent, pos, length)
		return
	var m := StandardMaterial3D.new()
	var ct: Texture2D = Mat.tex("res://tex/ui/hair_clump.png")
	m.albedo_texture = ct if ct else Mat.tex("res://tex/ui/hair.png")
	m.albedo_color = Color(0.16, 0.15, 0.14)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.4
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.5
	m.metallic_specular = 0.3
	for k in 2:
		var mi := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.22, length)
		mi.mesh = qm
		mi.material_override = m
		parent.add_child(mi)
		mi.global_position = pos - Vector3(0, length * 0.5, 0)
		mi.rotation.y = k * PI / 2.0 + randf() * 0.4


## Срезанные волосы плашмя: одна декаль (или одна карточка на воде и на низком качестве) с россыпью прядей.
## Свисающий комок (hair_clump.png с узлом) плашмя читался чёрной кляксой-звездой из трёх скрещённых карточек.
static func _hair_floor(parent: Node3D, pos: Vector3, length: float) -> void:
	var tex := _cut_hair_tex()
	var wdt := 0.3 + length * 0.15
	# в коллекторе волосы лежат на воде: декаль на прозрачную воду не ложится, а до дна не достаёт
	var gw: World = Game.world
	var floating := gw != null and gw.water_depth(pos - Vector3(0, 0.1, 0)) > 0.0
	if Settings.quality >= 1 and not floating:
		var dc := Decal.new()
		dc.size = Vector3(wdt, 0.25, length)
		dc.texture_albedo = tex
		dc.modulate = Color(0.3, 0.27, 0.24, 0.9)
		dc.albedo_mix = 1.0
		dc.normal_fade = 0.6
		dc.cull_mask = 1
		parent.add_child(dc)
		dc.global_position = pos + Vector3(0, 0.08, 0)
		dc.rotation.y = randf() * TAU
		return
	# карточка: без декали (низкое качество) или поверх воды
	if _cut_mat == null:
		_cut_mat = StandardMaterial3D.new()
		_cut_mat.albedo_texture = tex
		_cut_mat.albedo_color = Color(0.18, 0.165, 0.15)
		_cut_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		_cut_mat.alpha_scissor_threshold = 0.3
		_cut_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_cut_mat.roughness = 0.8
		_cut_mat.metallic_specular = 0.15
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(wdt, length)
	mi.mesh = qm
	mi.material_override = _cut_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos + Vector3(randf_range(-0.05, 0.05), 0.006, randf_range(-0.05, 0.05))
	mi.rotation = Vector3(-PI * 0.5, randf() * TAU, 0)


## Текстура срезанных волос: изогнутые пряди вразброс, гуще к середине, почти в одну сторону (как упали
## с ножниц), без узла; к краям прозрачнее, чтобы не было прямого среза. Рисуется один раз, своим генератором
## случайных чисел — общий (seed мира) не сдвигается.
static func _cut_hair_tex() -> Texture2D:
	if _cut_tex:
		return _cut_tex
	var S := 256
	var img := Image.create_empty(S, S, false, Image.FORMAT_RGBA8)
	# прозрачный фон цвета прядей: мип-уровни не темнеют каймой
	img.fill(Color(0.6, 0.55, 0.5, 0.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1961
	for _i in 170:
		var a := PI * 0.5 + rng.randf_range(-0.45, 0.45) + (PI if rng.randf() < 0.5 else 0.0)
		var steps := rng.randi_range(30, 110)
		var mid := Vector2(rng.randf() + rng.randf(), rng.randf() + rng.randf()) * (S * 0.5)
		var p := mid - Vector2(cos(a), sin(a)) * (steps * 0.5)
		var bend := rng.randf_range(-0.012, 0.012)
		var v := rng.randf_range(0.45, 0.8)
		var col := Color(v, v * 0.92, v * 0.85, 1.0)
		for _s in steps:
			var x := int(p.x)
			var y := int(p.y)
			if x >= 0 and x < S - 1 and y >= 0 and y < S:
				col.a = clampf(float(mini(mini(x, S - 2 - x), mini(y, S - 1 - y))) / 24.0, 0.0, 1.0)
				img.set_pixel(x, y, col)
				img.set_pixel(x + 1, y, col)
			p += Vector2(cos(a), sin(a))
			a += bend
	img.generate_mipmaps()
	_cut_tex = ImageTexture.create_from_image(img)
	return _cut_tex


## Надпись-подсказка рядом с предметом, читаемая записка на стене.
static func wall_note(parent: Node3D, id: String, pos: Vector3, normal: Vector3, size := Vector2(0.3, 0.4), label := "Прочитать") -> Usable:
	picture(parent, "res://tex/gen/note_%s.png" % id, pos, normal, size)
	var u := Usable.make(parent, pos + normal * 0.05, Vector3(size.x, size.y, 0.1), label, func():
		Game.add_note(id)
		if Game.main and Game.main.has_method("show_note"):
			Game.main.show_note(id))
	u.rotation.y = yaw_to(-normal)
	return u
