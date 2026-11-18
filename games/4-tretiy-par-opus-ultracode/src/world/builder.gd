class_name Builder
extends RefCounted
## Строит здание по Layout: полы, стены с проёмами, потолки, окна, двери, бассейн, лестницы, улица.

const T := 0.12   # толщина стены со стороны одной комнаты
const PIPES_X := [0.3, 14.0, 23.6, 38.0, 51.7]   # водостоки на южном фасаде
## Снег: тёмные «каракули» наста уже сглажены в самой текстуре (fetch_assets.py, FIX soften_snow — и альбедо, и
## нормаль), здесь рельеф ослаблен лишь слегка: при 0.35 поверх той правки снег под фонарём выходил плоским, пластиковым
const SNOW_OPTS := {"tint": Color(0.75, 0.8, 0.9), "rough": 0.9, "normal": 0.7}
## Фасадная штукатурка; age_h — до верха парапета (H + 0.85): иначе парапет брал нижний край карты «возраста» —
## сырую полосу «у пола»
const FACADE_OPTS := {"tint": Color(0.8, 0.72, 0.6), "age": "wall", "age_y": 0.0, "age_h": 6.45}

var w: Node3D
var batch := Geo.Batch.new()
var rooms := {}   # id -> {def, rect: Rect2, y, h, node: Node3D, body: StaticBody3D}
var doors := {}   # id -> Door
var window_lights: Array = []
var ext_details: Node3D   # детали фасада и двора: видны только снаружи и из вестибюля (World.player_room_changed)


func build(world: Node3D) -> void:
	w = world
	var t := Time.get_ticks_msec()
	for id in Layout.ROOMS:
		_room(id)
	var t1 := Time.get_ticks_msec()
	for d in Layout.DOORS:
		_door(d)
	var t2 := Time.get_ticks_msec()
	for wd in Layout.WINDOWS:
		_window(wd)
	_pool()
	_lobby_stairs()
	var t3 := Time.get_ticks_msec()
	_exterior()
	print("    комнаты %d, двери %d, окна+бассейн %d, улица %d" % [t1 - t, t2 - t1, t3 - t2, Time.get_ticks_msec() - t3])


# ---------------------------------------------------------------- комнаты

func _room(id: String) -> void:
	var d: Dictionary = Layout.ROOMS[id]
	var r: Array = d["r"]
	var rect := Rect2(r[0], r[1], r[2] - r[0], r[3] - r[1])
	var y := float(d["y"])
	var h := float(d["h"])
	var node := Node3D.new()
	node.name = id
	w.add_child(node)
	var body := Geo.static_body(node, "col")
	var info := {"id": id, "def": d, "rect": rect, "y": y, "h": h, "node": node, "body": body}
	rooms[id] = info
	var lift := float(d.get("floor_lift", 0.0))
	var floor_mat := Mat.m(d["floor"], {"wet": 0.85 if d.get("wet", false) or d.has("water") else 0.0, "age": "floor"})
	# пол
	if d.get("stairs", false):
		_stairs_room(info)
	else:
		var holes: Array = []
		if id == "pool":
			# дыра шире чаши на толщину её стенок: пол зала кончается за стенками, торцы плиты не совпадают
			# с плиткой чаши у воды (полосу 0.3 м сверху закрывают стенки и бортик)
			holes.append(Layout.POOL_BASIN.grow(0.3))
		if id == "lobby":
			holes.append(Layout.LOBBY_STAIRS)
		for fr in _rect_minus(rect, holes):
			var c := Vector3(fr.position.x + fr.size.x * 0.5, y + lift - 0.15, fr.position.y + fr.size.y * 0.5)
			var s := Vector3(fr.size.x, 0.3, fr.size.y)
			batch.box(floor_mat, c, s)
			Geo.col_box(body, c, s)
		if lift > 0.0:
			# порожек-пандус у дверей не нужен: поднимаем пол только внутри, у проёмов делаем скат
			pass
	# потолок
	var ceil_mat := _ceil_mat(d)
	var cc := Vector3(rect.get_center().x, y + h + 0.15, rect.get_center().y)
	var cb := Geo.Batch.new()
	cb.box(ceil_mat, cc, Vector3(rect.size.x, 0.3, rect.size.y))
	cb.commit(node, "ceil", false)
	Geo.col_box(body, cc, Vector3(rect.size.x, 0.3, rect.size.y))
	# стены
	for side in ["n", "s", "w", "e"]:
		_wall_side(info, side)
	# плинтус-бордюр по низу мокрых помещений
	batch.commit(node, "shell")


## Материал потолка — тот же, что у стен комнаты, со слоем протечек «ceil» (повтор 11 м, Mat.AGE_W). Стык плит,
## ложившийся на потолке «балкой» каждые 3 м, вырезан из самой текстуры штукатурки (fetch_assets.py, FIX
## unband_plaster) — подменять её фасадной не нужно, стены и потолок одной фактуры.
## Деревянным потолкам (парилки, сруб) кольца протечек не рисуем: на тёмных досках они читались верёвками.
func _ceil_mat(d: Dictionary) -> StandardMaterial3D:
	var cn: String = d.get("ceil", "plaster")
	if cn.begins_with("planks") or cn == "logs":
		return Mat.m(cn)
	return Mat.m(cn, {"age": "ceil"})


func _rect_minus(r: Rect2, holes: Array) -> Array:
	var out := [r]
	for hole: Rect2 in holes:
		var nxt := []
		for a: Rect2 in out:
			if not a.intersects(hole):
				nxt.append(a)
				continue
			var i := a.intersection(hole)
			if i.position.y > a.position.y:
				nxt.append(Rect2(a.position.x, a.position.y, a.size.x, i.position.y - a.position.y))
			if i.end.y < a.end.y:
				nxt.append(Rect2(a.position.x, i.end.y, a.size.x, a.end.y - i.end.y))
			if i.position.x > a.position.x:
				nxt.append(Rect2(a.position.x, i.position.y, i.position.x - a.position.x, i.size.y))
			if i.end.x < a.end.x:
				nxt.append(Rect2(i.end.x, i.position.y, a.end.x - i.end.x, i.size.y))
		out = nxt
	return out


## Проёмы (двери, окна) на стороне комнаты: [центр вдоль стены, ширина, низ, верх, тип двери ("window" — окно), соседняя комната]
func _openings(info: Dictionary, side: String) -> Array:
	var rect: Rect2 = info["rect"]
	var id: String = info["id"]
	var y: float = info["y"]
	var out := []
	for d in Layout.DOORS:
		if d[0] != id and d[1] != id:
			continue
		var p: Vector2 = d[2]
		var t := _on_side(rect, side, p)
		if is_nan(t):
			continue
		var other: String = d[1] if d[0] == id else d[0]
		var bottom := y
		if Layout.ROOMS.has(other):
			bottom = maxf(y, float(Layout.ROOMS[other]["y"]))
		if id == "b_stairs" and other == "service":
			bottom = 0.0
		out.append([t, float(d[3]), bottom, bottom + float(d[4]), String(d[5]), other])
	for wd in Layout.WINDOWS:
		if wd[0] == id and wd[1] == side:
			out.append([float(wd[2]), float(wd[4]), y + float(wd[3]), y + float(wd[3]) + float(wd[5]), "window", ""])
	out.sort_custom(func(a, b): return a[0] < b[0])
	return out


func _on_side(rect: Rect2, side: String, p: Vector2) -> float:
	match side:
		"n":
			if absf(p.y - rect.position.y) < 0.01 and p.x > rect.position.x and p.x < rect.end.x:
				return p.x
		"s":
			if absf(p.y - rect.end.y) < 0.01 and p.x > rect.position.x and p.x < rect.end.x:
				return p.x
		"w":
			if absf(p.x - rect.position.x) < 0.01 and p.y > rect.position.y and p.y < rect.end.y:
				return p.y
		"e":
			if absf(p.x - rect.end.x) < 0.01 and p.y > rect.position.y and p.y < rect.end.y:
				return p.y
	return NAN


func _wall_side(info: Dictionary, side: String) -> void:
	var d: Dictionary = info["def"]
	var rect: Rect2 = info["rect"]
	var y: float = info["y"]
	var h: float = info["h"]
	var body: StaticBody3D = info["body"]
	var along_x := side == "n" or side == "s"
	var t0 := rect.position.x if along_x else rect.position.y
	var t1 := rect.end.x if along_x else rect.end.y
	var ops := _openings(info, side)
	var cursor := t0
	for o in ops:
		var oc: float = o[0]
		var ow: float = o[1]
		var a := oc - ow * 0.5
		var b := oc + ow * 0.5
		if a > cursor:
			_wall_piece(info, side, cursor, a, y, y + h)
		# над и под проёмом
		if o[3] < y + h - 0.01:
			_wall_piece(info, side, a, b, o[3], y + h)
		if o[2] > y + 0.01:
			_wall_piece(info, side, a, b, y, o[2])
		if o[4] == "" and _reveal_owner(d, info["id"], o[5]):
			_reveal(info, side, a, b, o[2], o[3])
		cursor = maxf(cursor, b)
	if cursor < t1:
		_wall_piece(info, side, cursor, t1, y, y + h)


func _wall_piece(info: Dictionary, side: String, ta: float, tb: float, ya: float, yb: float) -> void:
	if tb - ta < 0.005 or yb - ya < 0.005:
		return
	var d: Dictionary = info["def"]
	var rect: Rect2 = info["rect"]
	var y: float = info["y"]
	var body: StaticBody3D = info["body"]
	var low := float(d.get("low", 0.0))
	var age := {"age": "wall", "age_y": y, "age_h": float(info["h"])}
	# противоположные стены пары (W/E, N/S) видят одно место трипланара зеркально — сдвинуть одну из них
	if side == "e" or side == "s":
		age["uv_ox"] = 0.37
		age["age_ox"] = 0.5
	var mat_hi := Mat.m(d["wall"], age)
	var mat_lo := _low_mat(d, age)
	var split := y + low
	var parts := []
	if d.has("wall_low") and split > ya and split < yb:
		parts = [[ya, split, mat_lo], [split, yb, mat_hi]]
	elif d.has("wall_low") and yb <= split:
		parts = [[ya, yb, mat_lo]]
	else:
		parts = [[ya, yb, mat_hi]]
	for p in parts:
		var c := Vector3.ZERO
		var s := Vector3.ZERO
		var my: float = (p[0] + p[1]) * 0.5
		var sy: float = p[1] - p[0]
		match side:
			"n":
				c = Vector3((ta + tb) * 0.5, my, rect.position.y + T * 0.5)
				s = Vector3(tb - ta, sy, T)
			"s":
				c = Vector3((ta + tb) * 0.5, my, rect.end.y - T * 0.5)
				s = Vector3(tb - ta, sy, T)
			"w":
				c = Vector3(rect.position.x + T * 0.5, my, (ta + tb) * 0.5)
				s = Vector3(T, sy, tb - ta)
			"e":
				c = Vector3(rect.end.x - T * 0.5, my, (ta + tb) * 0.5)
				s = Vector3(T, sy, tb - ta)
		batch.box(p[2], c, s)
	var cc := Vector3.ZERO
	var ss := Vector3.ZERO
	match side:
		"n":
			cc = Vector3((ta + tb) * 0.5, (ya + yb) * 0.5, rect.position.y + T * 0.5)
			ss = Vector3(tb - ta, yb - ya, T)
		"s":
			cc = Vector3((ta + tb) * 0.5, (ya + yb) * 0.5, rect.end.y - T * 0.5)
			ss = Vector3(tb - ta, yb - ya, T)
		"w":
			cc = Vector3(rect.position.x + T * 0.5, (ya + yb) * 0.5, (ta + tb) * 0.5)
			ss = Vector3(T, yb - ya, tb - ta)
		"e":
			cc = Vector3(rect.end.x - T * 0.5, (ya + yb) * 0.5, (ta + tb) * 0.5)
			ss = Vector3(T, yb - ya, tb - ta)
	Geo.col_box(body, cc, ss)


## Материал нижней панели стены. low_shift (Layout) — сдвиг текстуры по высоте в долях повтора: свой экземпляр
## материала (ключ кэша с "shift"), остальные пользователи текстуры не задеты. Сейчас ни у одной комнаты не задан
## (см. "service" в Layout): без него — общий Mat.m(wall_low, age).
func _low_mat(d: Dictionary, age: Dictionary) -> StandardMaterial3D:
	if not d.has("low_shift"):
		return Mat.m(d.get("wall_low", d["wall"]), age)
	var o := age.duplicate()
	o["shift"] = d["low_shift"]
	var m := Mat.m(d["wall_low"], o)
	m.uv1_offset = Vector3(0, float(d["low_shift"]), 0)
	return m


## Проём без двери: каждая комната строит свою половину стены своей отделкой, и в откосе шов вдоль
## (кирпич | розовая панель, кафель | штукатурка над 2.4 м). Откос облицовывает одна комната — со сплошной
## стеной без нижней панели; при одинаковой отделке с обеих сторон облицовка не нужна.
func _reveal_owner(d: Dictionary, id: String, other: String) -> bool:
	if not Layout.ROOMS.has(other):
		return false
	var od: Dictionary = Layout.ROOMS[other]
	if d["wall"] == od["wall"] and d.get("wall_low", "") == od.get("wall_low", "") and float(d.get("low", 0.0)) == float(od.get("low", 0.0)):
		return false
	if d.has("wall_low"):
		return false
	return od.has("wall_low") or id < other


## Облицовка откоса: две стойки и перемычка на всю толщину стены (обе половины + 3 мм наружу), на 1.5 см
## внутрь проёма — торцы обеих половин спрятаны. Материал — стена этой комнаты (тот же, что у её стен: без нового меша).
func _reveal(info: Dictionary, side: String, ta: float, tb: float, ya: float, yb: float) -> void:
	var d: Dictionary = info["def"]
	var rect: Rect2 = info["rect"]
	var ropts := {"age": "wall", "age_y": float(info["y"]), "age_h": float(info["h"])}
	if side == "e" or side == "s":
		ropts["uv_ox"] = 0.37
		ropts["age_ox"] = 0.5
	var mat := Mat.m(d["wall"], ropts)
	var line := 0.0
	match side:
		"n":
			line = rect.position.y
		"s":
			line = rect.end.y
		"w":
			line = rect.position.x
		"e":
			line = rect.end.x
	var dep := 2.0 * T + 0.006
	# [центр вдоль стены, ширина вдоль стены, центр по высоте, высота]
	var parts := [[ta + 0.005, 0.02, (ya + yb) * 0.5, yb - ya], [tb - 0.005, 0.02, (ya + yb) * 0.5, yb - ya]]
	if yb < float(info["y"]) + float(info["h"]) - 0.02:
		parts.append([(ta + tb) * 0.5, tb - ta, yb - 0.005, 0.02])
	for p in parts:
		var tc: float = p[0]
		var tw: float = p[1]
		var yc: float = p[2]
		var hh: float = p[3]
		if side == "n" or side == "s":
			batch.box(mat, Vector3(tc, yc, line), Vector3(tw, hh, dep))
		else:
			batch.box(mat, Vector3(line, yc, tc), Vector3(dep, hh, tw))


## Лестница в подвал: ступени от z=0 (y=0) вниз на север до z=-7 (y=-4.5)
func _stairs_room(info: Dictionary) -> void:
	var rect: Rect2 = info["rect"]
	var body: StaticBody3D = info["body"]
	# бетон с фактурой (у "concrete" текстура почти однотонная — ступени читались гладкими коробками), тон как прежде
	var mat := Mat.m("concrete_dirty", {"tint": Color(0.63, 0.65, 0.7)})
	var n := 18
	var top_z := rect.end.y - 0.6      # верхняя площадка 0.6 м
	var bot_z := rect.position.y + 1.2 # нижняя площадка 1.2 м
	var run := (top_z - bot_z) / n
	var rise := 4.5 / n
	# верхняя площадка
	batch.box(mat, Vector3(rect.get_center().x, -0.15, (top_z + rect.end.y) * 0.5), Vector3(rect.size.x, 0.3, rect.end.y - top_z))
	Geo.col_box(body, Vector3(rect.get_center().x, -0.15, (top_z + rect.end.y) * 0.5), Vector3(rect.size.x, 0.3, rect.end.y - top_z))
	for i in n:
		var ztop := top_z - run * i
		var ytop := -rise * (i + 1)
		var c := Vector3(rect.get_center().x, (ytop + Layout.BASE_Y) * 0.5 - 0.0, ztop - run * 0.5)
		batch.box(mat, c, Vector3(rect.size.x, ytop - Layout.BASE_Y + 0.001, run))
	# нижняя площадка
	var lc := Vector3(rect.get_center().x, Layout.BASE_Y - 0.15, (rect.position.y + bot_z) * 0.5)
	batch.box(mat, lc, Vector3(rect.size.x, 0.3, bot_z - rect.position.y))
	Geo.col_box(body, lc, Vector3(rect.size.x, 0.3, bot_z - rect.position.y))
	# коллизия — одна выпуклая форма: верхняя площадка + пролёт (без стыка, чтобы навигация была сплошной)
	var cs := CollisionShape3D.new()
	var sh := ConvexPolygonShape3D.new()
	var pts := PackedVector3Array()
	for x in [rect.position.x, rect.end.x]:
		pts.append(Vector3(x, 0.0, rect.end.y))
		pts.append(Vector3(x, 0.0, top_z))
		pts.append(Vector3(x, Layout.BASE_Y, bot_z))
		pts.append(Vector3(x, Layout.BASE_Y - 0.3, bot_z))
		pts.append(Vector3(x, Layout.BASE_Y - 0.3, rect.end.y))
	sh.points = pts
	cs.shape = sh
	body.add_child(cs)
	# перила: поручень на кронштейнах в кирпич, на концах — горизонтальный участок над площадкой и загиб в стену
	var rail := Mat.m("rust", {"metal": 0.6})
	for x in [rect.position.x + 0.2, rect.end.x - 0.2]:
		var wx: float = rect.position.x + T - 0.01 if x < rect.get_center().x else rect.end.x - T + 0.01
		var hi := Vector3(x, 0.9, top_z)
		var lo := Vector3(x, Layout.BASE_Y + 0.9, bot_z)
		batch.cyl(rail, hi, lo, 0.025, 6)
		for k in 4:
			var p := hi.lerp(lo, (k + 0.5) / 4.0)
			batch.cyl(rail, p, Vector3(wx, p.y, p.z), 0.012, 6)
		for e in [[hi, Vector3(0, 0, 0.3)], [lo, Vector3(0, 0, -0.3)]]:
			var a: Vector3 = e[0]
			var b: Vector3 = a + e[1]
			batch.cyl(rail, a, b, 0.025, 6)
			batch.cyl(rail, b, Vector3(wx, b.y, b.z), 0.025, 6)


# ---------------------------------------------------------------- бассейн

func _pool() -> void:
	var info: Dictionary = rooms["pool"]
	var node: Node3D = info["node"]
	var body: StaticBody3D = info["body"]
	var b := Layout.POOL_BASIN
	# плитка чаши вдвое крупнее (12 штук на метр издали сливались в рябь) и со слоем «возраста»: дно — грязь
	# и сырость, стенки — потёки от бортика вниз и сырая полоса у дна; стенки суше дна
	var tile := Mat.m("tile_pool", {"wet": 0.6, "scale": 2.0, "age": "floor"})
	var tile_w := Mat.m("tile_pool", {"wet": 0.3, "scale": 2.0, "age": "wall", "age_y": Layout.POOL_DEEP, "age_h": -Layout.POOL_DEEP})
	var edge := Mat.m("tile_wall", {"tint": Color(0.85, 0.85, 0.8)})
	var x0 := b.position.x
	var x1 := b.end.x
	var z0 := b.position.y
	var z1 := b.end.y
	var sh := Layout.POOL_SHALLOW
	var dp := Layout.POOL_DEEP
	var s0 := Layout.POOL_SLOPE.x
	var s1 := Layout.POOL_SLOPE.y
	# дно: мелкая часть, скат, глубокая
	_floor_piece(body, tile, Rect2(x0, z0, s0 - x0, b.size.y), sh)
	_floor_piece(body, tile, Rect2(s1, z0, x1 - s1, b.size.y), dp)
	var sl := Vector3(s1 - s0, dp - sh, 0)
	var ang := atan2(-(dp - sh), s1 - s0)
	var slen := sqrt(sl.x * sl.x + sl.y * sl.y)
	# плиту ската сдвигаем вниз по её собственной нормали: верх точно от края мелкой части (s0, sh) до глубокой
	# (s1, dp), без щели у x=25 и ступеньки у x=27
	var rb := Basis(Vector3.BACK, -ang)
	var sc := Vector3((s0 + s1) * 0.5, (sh + dp) * 0.5, (z0 + z1) * 0.5) - rb.y * 0.15
	batch.box(tile, sc, Vector3(slen, 0.3, b.size.y), rb)
	Geo.col_box(body, sc, Vector3(slen, 0.3, b.size.y), rb)
	# стенки чаши (внутренние грани, от дна до пола зала); северная и южная закрывают углы (пол зала вырезан
	# шире чаши на 0.3 м)
	var walls := [
		[Vector3((x0 + x1) * 0.5, 0, z0 - 0.15), Vector3(b.size.x + 0.6, 0, 0.3)],
		[Vector3((x0 + x1) * 0.5, 0, z1 + 0.15), Vector3(b.size.x + 0.6, 0, 0.3)],
		[Vector3(x0 - 0.15, 0, (z0 + z1) * 0.5), Vector3(0.3, 0, b.size.y)],
		[Vector3(x1 + 0.15, 0, (z0 + z1) * 0.5), Vector3(0.3, 0, b.size.y)],
	]
	for wl in walls:
		var c: Vector3 = wl[0]
		var s: Vector3 = wl[1]
		var top := 0.0
		var bot := dp - 0.3
		c.y = (top + bot) * 0.5
		s.y = top - bot
		batch.box(tile_w, c, s)
		Geo.col_box(body, c, s)
	# бортик
	for e in [[Vector3((x0 + x1) * 0.5, 0.05, z0 - 0.25), Vector3(b.size.x + 1.0, 0.1, 0.5)],
			[Vector3((x0 + x1) * 0.5, 0.05, z1 + 0.25), Vector3(b.size.x + 1.0, 0.1, 0.5)],
			[Vector3(x0 - 0.25, 0.05, (z0 + z1) * 0.5), Vector3(0.5, 0.1, b.size.y)],
			[Vector3(x1 + 0.25, 0.05, (z0 + z1) * 0.5), Vector3(0.5, 0.1, b.size.y)]]:
		batch.box(edge, e[0], e[1])
	# ступени в мелкую часть (западный край, у северной стенки)
	var steps := 5
	for i in steps:
		var yy := -(i + 1) * (-sh) / steps
		var c := Vector3(x0 + 0.35 + i * 0.35, (yy + sh) * 0.5, z0 + 0.7)
		batch.box(tile, c, Vector3(0.35, yy - sh, 1.4))
	var sang := atan2(-sh, steps * 0.35)
	var sc2 := Vector3(x0 + steps * 0.35 * 0.5 + 0.2, sh * 0.5 - 0.1, z0 + 0.7)
	Geo.col_box(body, sc2, Vector3(sqrt(pow(steps * 0.35, 2) + sh * sh), 0.2, 1.4), Basis(Vector3.BACK, -sang))
	# поручни лесенки
	var rail := Mat.m("rust", {"metal": 0.8, "tint": Color(1.2, 1.2, 1.2)})
	for zz in [z0 + 0.05, z0 + 1.35]:
		batch.cyl(rail, Vector3(x0 - 0.3, 0.9, zz), Vector3(x0 + 0.1, 0.9, zz), 0.022, 6)
		batch.cyl(rail, Vector3(x0 + 0.1, 0.9, zz), Vector3(x0 + 0.6, -0.4, zz), 0.022, 6)
		batch.cyl(rail, Vector3(x0 - 0.3, 0.0, zz), Vector3(x0 - 0.3, 0.9, zz), 0.022, 6)
	batch.commit(node, "basin")


func _floor_piece(body: StaticBody3D, mat: Material, r: Rect2, y: float) -> void:
	var c := Vector3(r.get_center().x, y - 0.15, r.get_center().y)
	var s := Vector3(r.size.x, 0.3, r.size.y)
	batch.box(mat, c, s)
	Geo.col_box(body, c, s)


# ---------------------------------------------------------------- затопленная лестница в вестибюле

func _lobby_stairs() -> void:
	var info: Dictionary = rooms["lobby"]
	var node: Node3D = info["node"]
	var body: StaticBody3D = info["body"]
	var r := Layout.LOBBY_STAIRS
	var mat := Mat.m("terracotta", {"wet": 0.7})
	var wall := Mat.m("tile_dark", {"wet": 0.5})
	# ступени уходят вниз на север
	var n := 10
	for i in n:
		var ztop := r.end.y - i * 0.3
		var ytop := -(i + 1) * 0.22
		batch.box(mat, Vector3(r.get_center().x, (ytop - 3.0) * 0.5, ztop - 0.15), Vector3(r.size.x, ytop + 3.0, 0.3))
	# стенки колодца — под плитой пола (y −3…−0.3): верхние 30 см края даёт торец плиты, грани не совпадают
	for wl in [[Vector3(r.position.x - 0.1, -1.65, r.get_center().y), Vector3(0.2, 2.7, r.size.y)],
			[Vector3(r.end.x + 0.1, -1.65, r.get_center().y), Vector3(0.2, 2.7, r.size.y)],
			[Vector3(r.get_center().x, -1.65, r.position.y - 0.1), Vector3(r.size.x + 0.4, 2.7, 0.2)]]:
		batch.box(wall, wl[0], wl[1])
	# перила с трёх сторон
	var rail := Mat.m("rust", {"metal": 0.6})
	var y := 0.95
	batch.cyl(rail, Vector3(r.position.x, y, r.end.y), Vector3(r.position.x, y, r.position.y), 0.025, 6)
	batch.cyl(rail, Vector3(r.end.x, y, r.end.y), Vector3(r.end.x, y, r.position.y), 0.025, 6)
	batch.cyl(rail, Vector3(r.position.x, y, r.position.y), Vector3(r.end.x, y, r.position.y), 0.025, 6)
	for zz in [r.position.y, r.get_center().y, r.end.y]:
		for xx in [r.position.x, r.end.x]:
			batch.cyl(rail, Vector3(xx, 0.0, zz), Vector3(xx, y, zz), 0.02, 6)
	batch.commit(node, "stairs")
	# коллизия: ограждение и невидимая стена у воды
	Geo.col_box(body, Vector3(r.position.x, 0.5, r.get_center().y), Vector3(0.1, 1.0, r.size.y))
	Geo.col_box(body, Vector3(r.end.x, 0.5, r.get_center().y), Vector3(0.1, 1.0, r.size.y))
	Geo.col_box(body, Vector3(r.get_center().x, 0.5, r.position.y), Vector3(r.size.x, 1.0, 0.1))
	Geo.col_box(body, Vector3(r.get_center().x, 0.5, r.end.y - 0.2), Vector3(r.size.x, 1.0, 0.1))


# ---------------------------------------------------------------- окна

func _window(wd: Array) -> void:
	var id: String = wd[0]
	var side: String = wd[1]
	var info: Dictionary = rooms[id]
	var rect: Rect2 = info["rect"]
	var y: float = info["y"]
	var t: float = wd[2]
	var bottom: float = y + float(wd[3])
	var ww: float = wd[4]
	var wh: float = wd[5]
	var node: Node3D = info["node"]
	var south := side == "s"
	# юг смотрит во двор на натриевый фонарь, остальные окна — холодная луна сквозь иней
	var col := Color(1.0, 0.66, 0.38) if south else Items.MOON
	var glass := glass_mat(col, 0.42 if south else 0.36)
	# рама и подоконник крашеные, как наличники дверей (та же эмаль, тот же материал): у досок planks_weather стыки
	# через 18 см резали тонкие бруски «кирпичиками». В парилках — гладкое тёмное дерево без стыков, под стать доскам
	var frame: StandardMaterial3D = Mat.m("facade", {"tint": Color(1.26, 1.37, 1.82), "rough": 0.6, "scale": 1.2})
	if id.ends_with("steam"):
		frame = Mat.flat(Color(0.3, 0.22, 0.15), 0.8)
	var pos := Vector3.ZERO
	var size := Vector3.ZERO
	var inward := Vector3.ZERO
	match side:
		"n":
			pos = Vector3(t, bottom + wh * 0.5, rect.position.y + 0.05)
			size = Vector3(ww, wh, 0.04)
			inward = Vector3(0, 0, 1)
		"s":
			pos = Vector3(t, bottom + wh * 0.5, rect.end.y - 0.05)
			size = Vector3(ww, wh, 0.04)
			inward = Vector3(0, 0, -1)
		"w":
			pos = Vector3(rect.position.x + 0.05, bottom + wh * 0.5, t)
			size = Vector3(0.04, wh, ww)
			inward = Vector3(1, 0, 0)
		"e":
			pos = Vector3(rect.end.x - 0.05, bottom + wh * 0.5, t)
			size = Vector3(0.04, wh, ww)
			inward = Vector3(-1, 0, 0)
	# иней по краям каждой из четырёх створок, а не одним пятном на всё окно
	glass.uv1_scale = Vector3(2, 2, 1)
	batch.box(glass, pos, size, Basis.IDENTITY, true)
	# переплёт
	var cross_a := Vector3(size.x if size.x > 0.1 else 0.06, 0.05, size.z if size.z > 0.1 else 0.06)
	batch.box(frame, pos + inward * 0.02, cross_a)
	var cross_b := Vector3(0.05 if size.x > 0.1 else 0.06, wh, 0.05 if size.z > 0.1 else 0.06)
	batch.box(frame, pos + inward * 0.02, cross_b)
	# коробка рамы по периметру: стекло не упирается прямо в штукатурку откоса
	var fw := 0.06
	var along: Vector3 = Vector3(1, 0, 0) if size.x > 0.1 else Vector3(0, 0, 1)
	var thick: Vector3 = Vector3(0, 0, 0.07) if size.x > 0.1 else Vector3(0.07, 0, 0)
	var fp := pos + inward * 0.02
	batch.box(frame, fp + Vector3.UP * (wh * 0.5 - fw * 0.5), along * ww + Vector3.UP * fw + thick)
	batch.box(frame, fp - Vector3.UP * (wh * 0.5 - fw * 0.5), along * ww + Vector3.UP * fw + thick)
	batch.box(frame, fp + along * (ww * 0.5 - fw * 0.5), along * fw + Vector3.UP * wh + thick)
	batch.box(frame, fp - along * (ww * 0.5 - fw * 0.5), along * fw + Vector3.UP * wh + thick)
	# подоконник
	var sill := Vector3(size.x + (0.1 if size.x > 0.1 else 0.25), 0.05, size.z + (0.1 if size.z > 0.1 else 0.25))
	batch.box(frame, Vector3(pos.x, bottom - 0.03, pos.z) + inward * 0.12, sill)
	batch.commit(node, "window")
	# лунный свет из окна
	var sl := SpotLight3D.new()
	sl.light_color = col
	sl.light_energy = 0.9 if south else 0.7
	sl.spot_range = 9.0
	sl.spot_angle = 55.0
	sl.spot_attenuation = 1.2
	sl.shadow_enabled = false
	sl.light_specular = 0.3
	sl.light_volumetric_fog_energy = 2.6
	var ck: Texture2D = Mat.tex("res://tex/gen/cookie_window.png")
	if ck:
		# на мокром полу — холодное пятно с крестом переплёта; конус чуть шире, маска сама даёт форму
		sl.light_projector = ck
		sl.spot_angle = 60.0
		sl.light_energy *= 1.5
	node.add_child(sl)
	sl.global_position = pos + inward * 0.3 + Vector3.UP * 0.2
	sl.look_at(sl.global_position + inward + Vector3.DOWN * 0.7)
	window_lights.append(sl)


## Матовое заиндевевшее стекло: светится неровно (иней по краям ярче, середина темнее), а не плоской заливкой.
static var _glass := {}


static func glass_mat(col: Color, energy: float, rough := 0.35) -> StandardMaterial3D:
	var key := str(col) + str(energy) + str(rough)
	if _glass.has(key):
		return _glass[key]
	var m := StandardMaterial3D.new()
	var t: Texture2D = Mat.tex("res://tex/gen/window_frost.png")
	m.albedo_texture = t
	m.albedo_color = col.darkened(0.6)
	m.roughness = rough
	m.emission_enabled = true
	m.emission_texture = t
	m.emission = col
	m.emission_energy_multiplier = energy
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_glass[key] = m
	return m


# ---------------------------------------------------------------- двери

func _door(d: Array) -> void:
	var kind: String = d[5]
	if kind == "":
		return
	var p: Vector2 = d[2]
	var width: float = d[3]
	var height: float = d[4]
	var a: String = d[0]
	var bottom := 0.0
	if Layout.ROOMS.has(a):
		bottom = float(Layout.ROOMS[a]["y"])
	if Layout.ROOMS.has(d[1]):
		bottom = maxf(bottom, float(Layout.ROOMS[d[1]]["y"]))
	if a == "service" and d[1] == "b_stairs":
		bottom = 0.0
	# ось стены: проём на линии z (север/юг) — дверь вдоль x
	var ra: Array = Layout.ROOMS[a]["r"]
	var along_x := absf(p.y - float(ra[1])) < 0.01 or absf(p.y - float(ra[3])) < 0.01
	var door := Door.new()
	door.name = d[6]
	door.id = d[6]
	door.kind = kind
	door.room_a = a
	door.room_b = d[1]
	w.add_child(door)
	door.setup(Vector3(p.x, bottom, p.y), along_x, width, height)
	doors[door.id] = door
	# наличники: светлая эмаль — проём читается светлой рамкой при любом свете, а не чёрной дырой. Основа —
	# гладкая штукатурка, высветленная в «слоновую кость» (тёмные доски planks_weather тинтом светлее не стать).
	# Двери парилок и сруба — в дереве, как их створки.
	var b_id: String = d[1]
	var trim := Mat.m("facade", {"tint": Color(1.26, 1.37, 1.82), "rough": 0.6, "scale": 1.2})
	if a.ends_with("steam") or b_id.ends_with("steam") or b_id == "banya":
		trim = Mat.m("planks_weather", {"tint": Color(1.25, 1.22, 1.12), "rough": 0.55})
	if kind == "steel" or kind == "grate":
		trim = Mat.m("rust", {"metal": 0.4})
	var node: Node3D = rooms[a]["node"]
	# обкладка откоса на всю толщину стены (стойки и перемычка): в щелях у створки и в открытом проёме
	# не видно, что каждая комната красила свою половину стены своим цветом. Обкладка входит в проём на 1.5 см —
	# под это подогнана створка (door.gd): 5 мм от петли и 6 мм сверху — там она заходит за обкладку и щели на
	# просвет нет; у притвора одностворчатой 17 мм — до обкладки 2 мм, кромка её не задевает. Менять вместе с door.gd
	var c0 := Vector3(p.x, bottom, p.y)
	var dep := 2.0 * T + 0.01
	for sgn in [-1.0, 1.0]:
		var jt: float = sgn * (width * 0.5 - 0.005)
		if along_x:
			batch.box(trim, c0 + Vector3(jt, height * 0.5, 0), Vector3(0.02, height, dep))
		else:
			batch.box(trim, c0 + Vector3(0, height * 0.5, jt), Vector3(dep, height, 0.02))
	if along_x:
		batch.box(trim, c0 + Vector3(0, height - 0.005, 0), Vector3(width, 0.02, dep))
	else:
		batch.box(trim, c0 + Vector3(0, height - 0.005, 0), Vector3(dep, 0.02, width))
	for sgn in [-1.0, 1.0]:
		var off := Vector3(0, 0, sgn * (T + 0.015)) if along_x else Vector3(sgn * (T + 0.015), 0, 0)
		var c := Vector3(p.x, bottom, p.y) + off
		var hw := width * 0.5 + 0.04
		if along_x:
			batch.box(trim, c + Vector3(-hw, height * 0.5, 0), Vector3(0.08, height, 0.03))
			batch.box(trim, c + Vector3(hw, height * 0.5, 0), Vector3(0.08, height, 0.03))
			batch.box(trim, c + Vector3(0, height + 0.04, 0), Vector3(width + 0.16, 0.08, 0.03))
		else:
			batch.box(trim, c + Vector3(0, height * 0.5, -hw), Vector3(0.03, height, 0.08))
			batch.box(trim, c + Vector3(0, height * 0.5, hw), Vector3(0.03, height, 0.08))
			batch.box(trim, c + Vector3(0, height + 0.04, 0), Vector3(0.03, 0.08, width + 0.16))
	batch.commit(node, "trim")


# ---------------------------------------------------------------- улица

func _exterior() -> void:
	var ext := Node3D.new()
	ext.name = "exterior"
	w.add_child(ext)
	var body := Geo.static_body(ext, "col")
	var facade := Mat.m("facade", FACADE_OPTS)
	var plinth := Mat.m("brick_red", {"tint": Color(0.7, 0.6, 0.55)})
	var roofm := Mat.m("concrete_dirty", {"tint": Color(0.5, 0.5, 0.5)})
	var snow := Mat.m("snow", SNOW_OPTS)
	var X0 := -0.35
	var X1 := 52.35
	var Z0 := -0.35
	var Z1 := 30.35
	var H := 5.6
	# стены корпуса (снаружи)
	var walls := [
		# северная — разомкнута над всей лестницей в котельную (x 24..26.5, до её потолка 3.3): шахту закрывают
		# её собственные стены, иначе фасад торчал внутрь шахты рамкой вокруг решётки
		[Vector3((X0 + 24.0) * 0.5, H * 0.5, Z0 + 0.175), Vector3(24.0 - X0, H, 0.35)],
		[Vector3((26.5 + X1) * 0.5, H * 0.5, Z0 + 0.175), Vector3(X1 - 26.5, H, 0.35)],
		[Vector3(25.25, (3.3 + H) * 0.5, Z0 + 0.175), Vector3(2.5, H - 3.3, 0.35)],
		[Vector3(X0 + 0.175, H * 0.5, (Z0 + Z1) * 0.5), Vector3(0.35, H, Z1 - Z0)],
		[Vector3(X1 - 0.175, H * 0.5, (Z0 + Z1) * 0.5), Vector3(0.35, H, Z1 - Z0)],
	]
	# южная — с проёмом входа
	walls.append([Vector3((X0 + 25.1) * 0.5, H * 0.5, Z1 - 0.175), Vector3(25.1 - X0, H, 0.35)])
	walls.append([Vector3((26.9 + X1) * 0.5, H * 0.5, Z1 - 0.175), Vector3(X1 - 26.9, H, 0.35)])
	walls.append([Vector3(26, (2.4 + H) * 0.5, Z1 - 0.175), Vector3(1.8, H - 2.4, 0.35)])
	for wl in walls:
		batch.box(facade, wl[0], wl[1])
		Geo.col_box(body, wl[0], wl[1])
	# цоколь: по фасаду и за угол по боковым стенам (боковые закрывают углы южной полосы). Боковые начинаются на 1 см
	# севернее корпуса: их торец не в одной плоскости с северной стеной (не мерцает)
	batch.box(plinth, Vector3((X0 + 25.1) * 0.5, 0.3, Z1 + 0.05), Vector3(25.1 - X0, 0.6, 0.12))
	batch.box(plinth, Vector3((26.9 + X1) * 0.5, 0.3, Z1 + 0.05), Vector3(X1 - 26.9, 0.6, 0.12))
	batch.box(plinth, Vector3(X0 - 0.05, 0.3, (Z0 - 0.01 + Z1 + 0.11) * 0.5), Vector3(0.12, 0.6, Z1 + 0.12 - Z0))
	batch.box(plinth, Vector3(X1 + 0.05, 0.3, (Z0 - 0.01 + Z1 + 0.11) * 0.5), Vector3(0.12, 0.6, Z1 + 0.12 - Z0))
	# крыша и парапет
	batch.box(roofm, Vector3((X0 + X1) * 0.5, H + 0.15, (Z0 + Z1) * 0.5), Vector3(X1 - X0 + 0.4, 0.3, Z1 - Z0 + 0.4))
	batch.box(snow, Vector3((X0 + X1) * 0.5, H + 0.33, (Z0 + Z1) * 0.5), Vector3(X1 - X0, 0.06, Z1 - Z0))
	batch.box(facade, Vector3((X0 + X1) * 0.5, H + 0.5, Z1 + 0.1), Vector3(X1 - X0 + 0.4, 0.7, 0.3))
	# карниз-фриз над входом и козырёк
	batch.box(facade, Vector3(26, 2.75, Z1 + 1.2), Vector3(4.0, 0.2, 2.4))
	batch.box(snow, Vector3(26, 2.88, Z1 + 1.2), Vector3(3.9, 0.06, 2.3))
	for xx in [24.3, 27.7]:
		batch.cyl(facade, Vector3(xx, 0, Z1 + 2.2), Vector3(xx, 2.65, Z1 + 2.2), 0.12, 10)
		Geo.col_box(body, Vector3(xx, 1.3, Z1 + 2.2), Vector3(0.25, 2.6, 0.25))
	# крыльцо и порог: бетон с фактурой (у "concrete" текстура почти однотонная), тон приглушён до прежней яркости.
	# Порог закрывает щель 35 см между полом вестибюля и крыльцом, верх вровень с полом — без ступеньки в проёме
	var porch := Mat.m("concrete_dirty", {"tint": Color(0.63, 0.65, 0.7)})
	batch.box(porch, Vector3(26, 0.075, Z1 + 1.2), Vector3(4.0, 0.15, 2.4))
	var thr_c := Vector3(26, -0.15, Z1 - 0.175)
	var thr_s := Vector3(1.9, 0.3, 0.35)
	batch.box(porch, thr_c, thr_s)
	Geo.col_box(body, thr_c, thr_s)
	# труба котельной: начинается в крыше пристройки (раньше с y −1 — кольцом свисала с потолка котельной)
	var chim := Mat.m("brick_dark", {"tint": Color(0.8, 0.7, 0.65)})
	batch.cyl(chim, Vector3(24, 3.2, -14), Vector3(24, 24, -14), 1.1, 14)
	batch.cyl(chim, Vector3(24, 24, -14), Vector3(24, 24.6, -14), 1.25, 14, true)
	# пристройка котельной (над подвалом) — тремя блоками в обход шахты лестницы (x 24..26.5, z −7..0): сплошной
	# блок заполнял шахту выше y 0, его грани закрывали решётку, верх пролёта и потолок шахты
	for ab in [[Vector3(19.75, 1.6, -9.175), Vector3(8.5, 3.2, 17.65)], [Vector3(29.5, 1.6, -9.175), Vector3(6.0, 3.2, 17.65)],
			[Vector3(25.25, 1.6, -12.5), Vector3(2.5, 3.2, 11.0)]]:
		batch.box(facade, ab[0], ab[1])
	batch.box(roofm, Vector3(24, 3.3, -9), Vector3(17.4, 0.2, 18.4))
	# земля: снег перед баней и по бокам — до 200 м, чтобы край растворялся в тумане, а не обрывался в чёрное небо
	var grounds := [
		Rect2(-200, Z1, 452, 200), Rect2(-200, -200, 199.65, 230.35), Rect2(X1, -200, 200, 230.35),
	]
	for g: Rect2 in grounds:
		var c := Vector3(g.get_center().x, -0.25, g.get_center().y)
		batch.box(snow, c, Vector3(g.size.x, 0.5, g.size.y))
		Geo.col_box(body, c, Vector3(g.size.x, 0.5, g.size.y))
	# сугробы вдоль фасада: сплошной вал с гребнем у стены (вход расчищен); у водостоков снег протаял до земли
	for seg in [[X0, 22.6], [29.4, X1]]:
		var sa: float = seg[0]
		var sb: float = seg[1]
		var dips := []
		for px in PIPES_X:
			if px > sa and px < sb:
				dips.append(float(px) - sa)
		batch.drift(snow, Vector3(sa, 0, Z1), Vector3(sb, 0, Z1), Vector3(0, 0, 1), 1.1, 0.4, sa, dips)
	batch.commit(ext, "ext")
	# невидимые границы двора
	for b in [[Vector3(26, 2, 52), Vector3(80, 4, 1)], [Vector3(-8, 2, 40), Vector3(1, 4, 25)],
			[Vector3(60, 2, 40), Vector3(1, 4, 25)]]:
		Geo.col_box(body, b[0], b[1])
	# окна фасада и детали двора — отдельный узел без теней: изнутри здания его не видно, а один меш на всё
	# здание иначе попадал бы в кадр и в тени фонаря почти из любой комнаты
	ext_details = Node3D.new()
	ext_details.name = "ext_details"
	ext.add_child(ext_details)
	# окна фасада: рамы, переплёты, иней; мыльни и парильни светятся изнутри оранжевым (топят), остальные тёмные
	for wd in Layout.WINDOWS:
		_facade_window(wd)
	batch.commit(ext_details, "ext_win", false)
	_exterior_details(ext_details)


## Окно на фасаде по окну комнаты из Layout.WINDOWS: ниша, рама с переплётом и форточкой, заиндевевшее стекло,
## жестяной отлив со снегом. Мыльни и парильни светятся изнутри (там топят), остальные окна тёмные.
func _facade_window(wd: Array) -> void:
	var id: String = wd[0]
	var side: String = wd[1]
	var r: Rect2 = rooms[id]["rect"]
	var y: float = rooms[id]["y"]
	var t: float = wd[2]
	var bottom: float = y + float(wd[3])
	var ww: float = wd[4]
	var wh: float = wd[5]
	var nrm := Vector3.ZERO
	var face := Vector3.ZERO
	match side:
		"s":
			if r.end.y < 29.9:
				return
			nrm = Vector3(0, 0, 1)
			face = Vector3(t, 0, 30.35)
		"w":
			if r.position.x > 0.1:
				return
			nrm = Vector3(-1, 0, 0)
			face = Vector3(-0.35, 0, t)
		"e":
			if r.end.x < 51.9:
				return
			nrm = Vector3(1, 0, 0)
			face = Vector3(52.35, 0, t)
		_:
			return
	var warm := id in ["m_wash", "f_wash", "m_steam", "f_steam"]
	var along := Vector3(absf(nrm.z), 0, absf(nrm.x))
	var deep := Vector3(absf(nrm.x), 0, absf(nrm.z))
	var c := face + Vector3.UP * (bottom + wh * 0.5)
	# рама крашеная, однотонная: у досок planks_weather стыки через 18 см резали тонкие бруски «кирпичиками»
	var frame := Mat.flat(Color(0.17, 0.14, 0.11), 0.8)
	var dark := Mat.flat(Color(0.04, 0.04, 0.045), 0.9)
	var tin := Mat.flat(Color(0.32, 0.33, 0.34), 0.45, 0.7)
	var snow := Mat.m("snow", SNOW_OPTS)
	var glass: StandardMaterial3D
	if warm:
		glass = glass_mat(Color(1.0, 0.5, 0.2), 1.6, 0.4)
	else:
		glass = glass_mat(Color(0.45, 0.52, 0.65), 0.05, 0.12)
	# ниша (тёмные откосы) и стекло
	batch.box(dark, c + nrm * 0.005, along * (ww + 0.1) + Vector3.UP * (wh + 0.1) + deep * 0.02)
	batch.box(glass, c + nrm * 0.02, along * ww + Vector3.UP * wh + deep * 0.02, Basis.IDENTITY, true)
	# коробка рамы
	var fr := 0.07
	var fc := c + nrm * 0.05
	batch.box(frame, fc + Vector3.UP * (wh * 0.5 - fr * 0.5), along * ww + Vector3.UP * fr + deep * 0.06)
	batch.box(frame, fc - Vector3.UP * (wh * 0.5 - fr * 0.5), along * ww + Vector3.UP * fr + deep * 0.06)
	batch.box(frame, fc + along * (ww * 0.5 - fr * 0.5), along * fr + Vector3.UP * wh + deep * 0.06)
	batch.box(frame, fc - along * (ww * 0.5 - fr * 0.5), along * fr + Vector3.UP * wh + deep * 0.06)
	# переплёт: стойка по центру и поперечина (форточка сверху)
	batch.box(frame, fc, along * 0.05 + Vector3.UP * wh + deep * 0.05)
	batch.box(frame, fc + Vector3.UP * (wh * 0.22), along * ww + Vector3.UP * 0.045 + deep * 0.05)
	# штукатурное обрамление (сандрик и откосы) выступает на 14 см: рама оказывается в глубине, а не наклеена
	# на стену; его внутренние грани — откос проёма
	var fac := Mat.m("facade", FACADE_OPTS)
	var sw := clampf(ww * 0.08, 0.07, 0.12)
	var sd := 0.14
	var jh := wh + sw + 0.015
	var jc := c + nrm * (sd * 0.5) + Vector3.UP * ((sw - 0.015) * 0.5)
	batch.box(fac, jc + along * (ww * 0.5 + sw * 0.5), along * sw + Vector3.UP * jh + deep * sd)
	batch.box(fac, jc - along * (ww * 0.5 + sw * 0.5), along * sw + Vector3.UP * jh + deep * sd)
	batch.box(fac, c + nrm * (sd * 0.5) + Vector3.UP * (wh * 0.5 + sw * 0.5), along * ww + Vector3.UP * sw + deep * sd)
	# отлив шире обрамления и выносом дальше него, снег на нём
	var sill := c - Vector3.UP * (wh * 0.5 + 0.03) + nrm * 0.11
	batch.box(tin, sill, along * (ww + sw * 2.0 + 0.12) + Vector3.UP * 0.03 + deep * 0.22)
	var hs := 0.05 + randf() * 0.03
	batch.box(snow, sill + Vector3.UP * (0.01 + hs * 0.5) + nrm * 0.01, along * (ww + sw * 2.0 + 0.06) + Vector3.UP * hs + deep * 0.18)
	# снег в нижних углах стёкол: клинья лежат на нижнем бруске рамы, у стоек выше, к середине сходят на нет
	var rail_y := c - Vector3.UP * (wh * 0.5 - fr)
	var pane := ww * 0.5 - fr - 0.025
	for sgn in [-1.0, 1.0]:
		var outer: Vector3 = rail_y + along * (sgn * (ww * 0.5 - fr))
		var inner: Vector3 = rail_y + along * (sgn * 0.025)
		_snow_wedge(snow, outer, along * -sgn, nrm, pane * randf_range(0.3, 0.55), randf_range(0.035, 0.07))
		_snow_wedge(snow, inner, along * sgn, nrm, pane * randf_range(0.12, 0.3), randf_range(0.02, 0.04))


## Снежный клин в углу стекла: от угла (на бруске рамы, у стойки) высотой h вдоль dir сходит на нет за l.
## Видны только лицевой треугольник и скат; низ лежит на бруске, зад — у стекла, торец — у стойки.
func _snow_wedge(snow: Material, corner: Vector3, dir: Vector3, nrm: Vector3, l: float, h: float) -> void:
	var b0 := corner + nrm * 0.032
	var b1 := corner + nrm * 0.058
	var t0 := b0 + Vector3.UP * h
	var t1 := b1 + Vector3.UP * h
	var e0 := b0 + dir * l
	var e1 := b1 + dir * l
	batch.tri(snow, b1, t1, e1, nrm, Vector2.ZERO, Vector2.UP, Vector2.RIGHT)
	batch.quad(snow, t0, t1, e1, e0, (Vector3.UP * l + dir * h).normalized())


## Детали двора: водостоки с наледью, сосульки с карниза и козырька, провода от столба, лампа над входом,
## сугробы у боковых стен, вентиляция на крыше с паром и дым из трубы котельной.
func _exterior_details(ext: Node3D) -> void:
	var Z1 := 30.35
	var H := 5.6
	var tin := Mat.flat(Color(0.3, 0.31, 0.32), 0.5, 0.75)
	var ice := Mat.flat(Color(0.7, 0.78, 0.85), 0.08, 0.0, {"emission": Color(0.3, 0.4, 0.55), "emission_energy": 0.15})
	var snow := Mat.m("snow", SNOW_OPTS)
	var wire := Mat.flat(Color(0.02, 0.02, 0.02), 0.6)
	# водостоки: воронка под карнизом, труба с хомутами, колено-выпуск, наледь внизу
	for x in PIPES_X:
		var p := Vector3(x, 0, Z1 + 0.14)
		batch.cyl(tin, p + Vector3(0, 0.35, 0), p + Vector3(0, H - 0.25, 0), 0.06, 8)
		batch.cyl(tin, p + Vector3(0, H - 0.3, 0), p + Vector3(0, H - 0.05, 0.02), 0.14, 8, true)
		batch.cyl(tin, p + Vector3(0, 0.4, 0), p + Vector3(0, 0.18, 0.22), 0.06, 8)
		for k in 4:
			var ip := p + Vector3(randf_range(-0.05, 0.05), 0.13, 0.24)
			batch.cone(ice, ip, ip - Vector3(0, randf_range(0.08, 0.2), 0), 0.03, 5)
		batch.box(ice, p + Vector3(0, 0.03, 0.35), Vector3(0.5, 0.06, 0.45), Basis(Vector3.UP, randf_range(-0.3, 0.3)))
		for k in 2:
			batch.box(tin, p + Vector3(0, 1.5 + k * 2.4, -0.07), Vector3(0.16, 0.04, 0.06))
	# сосульки с парапета
	for i in 46:
		var x := randf_range(0.0, 52.0)
		if absf(x - 26.0) < 2.2:
			continue
		var len := randf_range(0.08, 0.5) * (1.0 if randf() < 0.8 else 2.0)
		var top := Vector3(x, H + 0.15, Z1 + 0.27)
		batch.cone(ice, top, top + Vector3(randf_range(-0.02, 0.02), -len, 0), randf_range(0.015, 0.04), 5)
	# сосульки с козырька
	for i in 12:
		var top := Vector3(24.2 + i * 0.32 + randf_range(-0.08, 0.08), 2.65, Z1 + 2.4)
		batch.cone(ice, top, top - Vector3(0, randf_range(0.05, 0.3), 0), 0.02, 5)
	# провода от столба: к фасаду (провисают) и прочь со двора
	var pole_top := Vector3(16.0, 5.85, 37.0)
	for wdef in [[pole_top, Vector3(13.0, 4.6, Z1 + 0.08)], [pole_top + Vector3(0, 0.15, 0), Vector3(-9.0, 6.2, 42.0)],
			[pole_top - Vector3(0, 0.15, 0), Vector3(36.0, 4.9, Z1 + 0.08)]]:
		var a: Vector3 = wdef[0]
		var b: Vector3 = wdef[1]
		var prev := a
		var segs := 8
		var sag := a.distance_to(b) * 0.04
		for k in range(1, segs + 1):
			var tt := float(k) / segs
			var p := a.lerp(b, tt) - Vector3.UP * sag * 4.0 * tt * (1.0 - tt)
			batch.cyl(wire, prev, p, 0.008, 4)
			prev = p
	batch.box(tin, Vector3(13.0, 4.6, Z1 + 0.08), Vector3(0.06, 0.06, 0.16))
	batch.box(tin, Vector3(36.0, 4.9, Z1 + 0.08), Vector3(0.06, 0.06, 0.16))
	# лампа над входом: жестяной абажур, тёплая лампочка; свет слабый и подрагивает
	var lamp_pos := Vector3(26.0, 2.5, Z1 + 0.32)
	batch.box(tin, Vector3(26.0, 2.62, Z1 + 0.16), Vector3(0.05, 0.05, 0.32))
	batch.cone(tin, lamp_pos + Vector3(0, 0.1, 0), lamp_pos + Vector3(0, 0.2, 0), 0.16, 10)
	batch.cone(tin, lamp_pos + Vector3(0, 0.1, 0), lamp_pos + Vector3(0, 0.03, 0), 0.16, 10)
	var bulb := Mat.flat(Color(1.0, 0.8, 0.5), 0.3, 0.0, {"emission": Color(1.0, 0.7, 0.4), "emission_energy": 5.0})
	batch.box(bulb, lamp_pos + Vector3(0, 0.03, 0), Vector3(0.07, 0.07, 0.07))
	var el := OmniLight3D.new()
	el.light_color = Items.SODIUM
	el.omni_range = 7.0
	el.omni_attenuation = 1.3
	el.light_energy = 1.2
	el.shadow_enabled = false
	ext.add_child(el)
	el.global_position = lamp_pos + Vector3(0, -0.05, 0.08)
	var flick := Node.new()
	flick.set_script(load("res://src/world/flicker.gd"))
	flick.set("light", el)
	flick.set("base", 1.2)
	ext.add_child(flick)
	# сугробы у боковых стен: сплошной вал с гребнем у стены, к углам сходит на нет
	for side_x in [-0.35, 52.35]:
		var out := -1.0 if side_x < 0 else 1.0
		batch.drift(snow, Vector3(side_x, 0, -0.35), Vector3(side_x, 0, Z1), Vector3(out, 0, 0), 1.0, 0.32, side_x * 0.1)
	# вентиляционные шахты на крыше над мыльнями — из них идёт пар; дым из трубы котельной
	var brick := Mat.m("brick_dark", {"tint": Color(0.7, 0.62, 0.58)})
	for vx in [7.0, 45.0]:
		var vp := Vector3(vx, H + 0.3, 14.5)
		batch.box(brick, vp + Vector3(0, 0.6, 0), Vector3(1.0, 1.2, 1.0))
		batch.box(tin, vp + Vector3(0, 1.28, 0), Vector3(1.25, 0.06, 1.25))
		batch.box(snow, vp + Vector3(0, 1.33, 0), Vector3(1.15, 0.05, 1.15))
		_vent_steam(ext, vp + Vector3(0, 1.1, 0), false)
	_vent_steam(ext, Vector3(24, 24.8, -14), true)
	batch.commit(ext, "ext_details", false)


## Пар из вентиляции / дым из трубы: редкие крупные клубы, их сносит ветром. На низком качестве — вдвое реже.
func _vent_steam(parent: Node3D, pos: Vector3, smoke: bool) -> void:
	var pr := GPUParticles3D.new()
	pr.amount = 26 if Settings.quality >= 1 else 12
	pr.lifetime = 7.0 if smoke else 5.0
	pr.preprocess = 6.0
	pr.visibility_aabb = AABB(Vector3(-6, -1, -6), Vector3(26, 22, 12))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.6 if smoke else 0.35
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 12.0
	pm.initial_velocity_min = 0.8
	pm.initial_velocity_max = 1.5
	pm.gravity = Vector3(0.45, 0.15, 0.1)
	pm.scale_min = 1.5 if smoke else 1.0
	pm.scale_max = 3.2 if smoke else 2.2
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.4))
	sc.add_point(Vector2(1, 1.0))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	var ac := Curve.new()
	ac.add_point(Vector2(0, 0))
	ac.add_point(Vector2(0.15, 1))
	ac.add_point(Vector2(1, 0))
	var act := CurveTexture.new()
	act.curve = ac
	pm.alpha_curve = act
	pr.process_material = pm
	var qm := QuadMesh.new()
	qm.size = Vector2(1.6, 1.6)
	var sm := StandardMaterial3D.new()
	sm.albedo_texture = Mat.tex("res://tex/ui/steam_puff.png")
	sm.albedo_color = Color(0.16, 0.15, 0.15, 0.55) if smoke else Color(0.6, 0.62, 0.68, 0.32)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.vertex_color_use_as_albedo = true
	qm.material = sm
	pr.draw_pass_1 = qm
	pr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(pr)
	pr.global_position = pos
