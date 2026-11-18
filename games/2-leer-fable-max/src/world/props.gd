class_name Props
extends RefCounted
## Мелкие общие предметы: бумаги-записки, лампы, постель, сугробы, поленницы, висящая парка.

const FACE_UP := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))   # плоскость лицом вверх


## Бумага с записью. flat — лежит на столе (иначе висит на стене лицом по rot).
static func paper(root: Node3D, pos: Vector3, yaw_deg: float, note_id: String, flat := true, size := Vector2(0.2, 0.28), grid := false) -> Interactable:
	var m := Kit.img("res://tex/paper_grid" if grid else "res://tex/paper")
	var rot := Kit.yaw(yaw_deg)
	if flat:
		rot = rot * FACE_UP
	var q := Kit.quad_node(root, pos, size, m, rot)
	# несколько тёмных «строчек», чтобы лист не был пустым
	var ink := Kit.flat(Color(0.1, 0.1, 0.16), 0.9)
	for i in 6:
		var ln := Kit.quad_node(q, Vector3(-size.x * 0.05 + (i % 2) * 0.006, size.y * (0.34 - 0.115 * i), 0.0008), Vector2(size.x * (0.72 - 0.07 * float(i % 3)), 0.006), ink)
		ln.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var it := Interactable.make(root, pos, Vector3(maxf(size.x, 0.24), 0.16, maxf(size.y, 0.24)) if flat else Vector3(0.3, 0.36, 0.3), "Прочитать", func() -> void: G.read(note_id))
	it.pick_priority = 1
	it.need_light = false
	it.set_meta("mesh", q)
	return it


## Лампочка под потолком: патрон, колба, свет. Гаснет вместе с дизелем.
static func ceil_lamp(w: World, root: Node3D, pos: Vector3, energy := 1.25, rng := 5.5, color := Color(1.0, 0.8, 0.55), shadow := false) -> OmniLight3D:
	Kit.place(root, "socket", pos, 0.0, 1.0, false, false)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(1.0, 0.9, 0.7)
	gm.emission_enabled = true
	gm.emission = color
	gm.emission_energy_multiplier = 3.5
	# колба ввёрнута в патрон (низ патрона на 5 см под потолком); 5,4 см — цепочка ложится на стекло, а не сквозь
	var bulb := Kit.sphere_node(root, pos + Vector3(0, -0.082, 0), 0.027, gm, Vector3(1, 1.5, 1), 8)
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.reg_glow(gm)
	# маленький тёплый ореол у колбы, чуть ниже её середины: потолок не срезает яркую часть (гаснет с дизелем)
	var hl := Kit.halo(root, pos + Vector3(0, -0.1, 0), color, 0.55, 0.45)
	(hl.material_override as ShaderMaterial).set_shader_parameter("near_fade", 0.6)
	w.reg_halo(hl)
	var l := Kit.omni(root, pos + Vector3(0, -0.28, 0), color, energy, rng, shadow, 40.0)
	# свет круче спадает к углам: под лампой светло, по углам — темно
	l.omni_attenuation = 1.5
	w.reg_light(l)
	return l


## Постель на железной койке: матрас, одеяло, подушка. length вдоль локальной оси Z.
static func bedding(root: Node3D, pos: Vector3, yaw_deg: float, made := true, top := 0.36) -> Node3D:
	var n := Node3D.new()
	n.transform = Transform3D(Kit.yaw(yaw_deg), pos)
	root.add_child(n)
	var b := Batch.new()
	b.box(Vector3(0, top + 0.06, 0), Vector3(0.8, 0.12, 1.86), Kit.img("res://tex/mattress", false, false, 0.5), false)
	if made:
		b.box(Vector3(0, top + 0.135, 0.22), Vector3(0.82, 0.04, 1.36), Kit.img("res://tex/blanket", false, false, 0.6), false)
	else:
		# сбитое одеяло - в пределах матраса (±0,4 x ±0,93): раньше угол торчал на 0,29 м за край -
		# у моей койки висел в воздухе, у койки Громова уходил в северную стену
		b.box(Vector3(0.07, top + 0.16, 0.47), Vector3(0.5, 0.1, 0.8), Kit.img("res://tex/blanket", false, false, 0.6), false, Kit.yaw(12))
	b.commit(n, "Bedding", false)
	var pil := Kit.sphere_node(n, Vector3(0, top + 0.17, -0.72), 0.2, Kit.flat(Color(0.74, 0.72, 0.66), 0.95), Vector3(1.5, 0.42, 1.0), 10)
	pil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n


## Сугроб: приплюснутая полусфера из снега.
static func drift(root: Node3D, pos: Vector3, size: Vector3, yaw_deg := 0.0) -> MeshInstance3D:
	var m := Kit.snow()
	var mi := Kit.sphere_node(root, pos, 1.0, m, size, 16)
	mi.rotation.y = deg_to_rad(yaw_deg)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Сугроб, наметённый к стене: половина купола. base — точка у подножия стены, out — направление от стены,
## size — (вдоль стены, высота, вынос от стены). Внутрь помещения не заходит.
static func drift_wall(root: Node3D, base: Vector3, out: Vector3, size: Vector3) -> MeshInstance3D:
	var prof := PackedVector2Array()
	for i in 7:
		var a := float(i) / 6.0 * PI * 0.5
		prof.append(Vector2(cos(a), sin(a)))
	var mesh := Kit.lathe(prof, 12, PI)
	var o := out.normalized()
	var along := Vector3.UP.cross(o).normalized()
	var m := Kit.snow()
	var mi := Kit.mesh_node(root, mesh, base, m, Basis(along * size.x * 0.5, Vector3.UP * size.y, o * size.z))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Поленница: брёвнышки рядами. along — направление длины полена.
static func logs(b: Batch, base: Vector3, along_x: bool, cols: int, rows: int, ln := 0.45, seed_v := 1) -> void:
	var bark := Kit.flat(Color(0.2, 0.15, 0.11), 0.95)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var rot := Basis(Vector3.FORWARD, deg_to_rad(90)) if along_x else Basis(Vector3.RIGHT, deg_to_rad(90))
	var r := 0.065
	# полено - шестигранник (Batch.cyl, 6 сторон): каждое ложится гранями на основание или на нижние поленья.
	# Раньше ряды шли с шагом по среднему радиусу - тонкие поленья висели до 5 см над опорой
	var below: Array = []   # нижний ряд: [высота центра, сечение]
	for j in rows:
		var row: Array = []
		for i in cols:
			var jx := rng.randf_range(-0.02, 0.02)
			var jz := rng.randf_range(-0.02, 0.02)
			var ri := r * rng.randf_range(0.8, 1.05)
			var li := ln * rng.randf_range(0.9, 1.05)
			var off := (float(i) + (0.5 if j % 2 == 1 else 0.0)) * r * 2.05 + (jz if along_x else jx)
			var sec := _log_section(along_x, off, ri)
			var y := 0.0
			for v in sec:
				y = maxf(y, -v.y)
			for s in below:
				y = maxf(y, float(s[0]) + _rest_on(sec, s[1]))
			row.append([y, sec])
			b.cyl(base + (Vector3(jx, y, off) if along_x else Vector3(off, y, jz)), ri, li, bark, 6, false, rot)
		below = row


## Сечение полена поперёк длины (поперёк, высота от центра) - как кольцо Batch.cyl после поворота в logs.
static func _log_section(along_x: bool, cx: float, ri: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in 6:
		var a := TAU * float(k) / 6.0
		out.append(Vector2(cx + sin(a) * ri, -cos(a) * ri) if along_x else Vector2(cx + cos(a) * ri, -sin(a) * ri))
	return out


## На сколько центр сечения up должен быть выше центра dn, чтобы лечь на него (-1e9 - не над ним).
static func _rest_on(up: PackedVector2Array, dn: PackedVector2Array) -> float:
	var su := _span(up)
	var sd := _span(dn)
	var x0 := maxf(su.x, sd.x)
	var x1 := minf(su.y, sd.y)
	var need := -1e9
	if x1 <= x0:
		return need
	var xs := PackedFloat64Array([x0, x1])
	for v in up:
		xs.append(v.x)
	for v in dn:
		xs.append(v.x)
	for x in xs:
		if x >= x0 and x <= x1:
			need = maxf(need, _edge_y(dn, x, false) - _edge_y(up, x, true))
	return need


static func _span(p: PackedVector2Array) -> Vector2:
	var s := Vector2(1e9, -1e9)
	for v in p:
		s = Vector2(minf(s.x, v.x), maxf(s.y, v.x))
	return s


## Низ (lower) или верх выпуклого сечения на вертикали x.
static func _edge_y(p: PackedVector2Array, x: float, lower: bool) -> float:
	var best := 1e9 if lower else -1e9
	for i in p.size():
		var a := p[i]
		var c := p[(i + 1) % p.size()]
		if (a.x - x) * (c.x - x) > 0.0 or absf(a.x - c.x) < 1e-9:
			continue
		var y := lerpf(a.y, c.y, (x - a.x) / (c.x - a.x))
		best = minf(best, y) if lower else maxf(best, y)
	return best


## Парка на крючке: тёмный силуэт куртки с капюшоном.
static func parka(root: Node3D, pos: Vector3, yaw_deg: float, col: Color) -> Node3D:
	var n := Node3D.new()
	n.transform = Transform3D(Kit.yaw(yaw_deg), pos)
	root.add_child(n)
	var cloth := Kit.mat("caban", 0.5, col, 1.0)
	var fur := Kit.mat("fur", 0.3, Color(0.5, 0.48, 0.44), 1.0)
	Kit.sphere_node(n, Vector3(0, -0.55, 0.08), 1.0, cloth, Vector3(0.27, 0.56, 0.11), 12)
	Kit.sphere_node(n, Vector3(0, -0.06, 0.09), 1.0, cloth, Vector3(0.15, 0.17, 0.1), 10)
	Kit.sphere_node(n, Vector3(0, -0.02, 0.15), 1.0, fur, Vector3(0.13, 0.15, 0.04), 8)
	Kit.sphere_node(n, Vector3(-0.27, -0.55, 0.07), 1.0, cloth, Vector3(0.075, 0.45, 0.075), 8)
	Kit.sphere_node(n, Vector3(0.27, -0.55, 0.07), 1.0, cloth, Vector3(0.075, 0.45, 0.075), 8)
	return n


## Табличка на стене или на столбике.
static func sign_board(root: Node3D, pos: Vector3, yaw_deg: float, text: String, size := 0.07, col := Color(0.76, 0.74, 0.66)) -> Node3D:
	var n := Node3D.new()
	n.transform = Transform3D(Kit.yaw(yaw_deg), pos)
	root.add_child(n)
	var w := maxf(0.4, size * 0.72 * text.length() + 0.14)
	Kit.box_node(n, Vector3.ZERO, Vector3(w, size * 2.4, 0.02), Kit.flat(col, 0.85), false)
	Kit.label(n, Vector3(0, 0, 0.012), text, size, Color(0.07, 0.06, 0.05), "head")
	return n
