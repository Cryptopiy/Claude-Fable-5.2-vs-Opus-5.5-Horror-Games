extends SceneTree
## Детектор «висит в воздухе»: каждый поставленный предмет (модель Kit.put/place, примитив Kit.*_node) должен стоять
## на чём-то, быть прикреплён к стене или висеть на чём-то сверху. Без окна (видеокарта не нужна):
##   godot --headless --path . --script tools/dev/support.gd -- --place=main --test --nocold --god --nogust [--all]
## Все видимые сетки получают точную коллизию по треугольникам (слой 8); из каждого предмета идут лучи вниз (5 точек),
## в 4 стороны и вверх. Печатает FLOAT <путь> <модель> низ=<y> зазор_вниз=<м> бок=<м> верх=<м> aabb=…  — ни опоры, ни стены,
## ни подвеса; SINK — предмет заметно утоплен в то, на чём стоит; PEN — выпуклая оболочка предмета вошла в чужую геометрию
## глубже 4 см (кандидат: оболочка шире формы). В конце SUPPORT units=N float=K sink=M pen=P.
## --all — печатать и нормальные (OK …), для отладки.

const L := 1 << 7
const SUP := 0.035       # зазор до опоры, который ещё считается «стоит»
const SIDE := 0.045      # зазор до стены, который ещё считается «прикреплён»
const PEN := 0.04        # глубже — «протыкает» (кандидат)

var g: Node
var t := 0.0
var started := false
var body_owner := {}     # RID тела → id предмета (−1 — постройка)


func _initialize() -> void:
	change_scene_to_file("res://src/main.tscn")


func _process(dt: float) -> bool:
	t += dt
	if started:
		return false
	if g == null:
		g = root.get_node_or_null("G")
		return false
	var w = g.get("world")
	var p = g.get("player")
	if w == null or p == null or not is_instance_valid(p) or not p.is_inside_tree() or t < 2.5:
		if t > 60.0:
			print("SUPPORT FAIL no world")
			quit(2)
		return false
	started = true
	p.teleport(Vector3(0, 0, 400), 0.0)
	_run.call_deferred(w)
	return false


func _skip(n: Node) -> bool:
	# погода, частицы, игрок, фигуры, ореолы и глаза — не «предметы»
	var cur := n
	while cur != null:
		if cur is GPUParticles3D or _scr(cur) in ["figure.gd", "player.gd", "weather.gd", "prints.gd", "entity.gd"]:
			return true
		var nm := String(cur.name)
		if nm in ["Ground", "GroundRelief", "Weather"] or nm.begins_with("Line_"):
			return true
		cur = cur.get_parent()
	if n is MeshInstance3D:
		var mi: MeshInstance3D = n
		var m := mi.material_override
		if m is ShaderMaterial and (m as ShaderMaterial).shader != null:
			var sp := (m as ShaderMaterial).shader.resource_path
			if sp.contains("halo") or sp.contains("eyes") or sp.contains("flake") or sp.contains("veil") or sp.contains("dust"):
				return true
	return false


func _unit_of(mi: Node) -> Node:
	# ближайший предок с меткой kit (модель), иначе сам примитив; постройки (batch) — null
	var cur := mi
	while cur != null and _scr(cur) != "world.gd":
		if cur.has_meta("kit"):
			return cur
		cur = cur.get_parent()
	if mi.has_meta("prim"):
		return mi
	return null


func _run(w: Node3D) -> void:
	await physics_frame
	var units := {}          # Node → {id, meshes: []}
	var order: Array = []
	var structs := 0
	for mi in _all_meshes(w):
		var m3: MeshInstance3D = mi
		if _skip(m3) or not m3.is_visible_in_tree():
			continue
		var u := _unit_of(m3)
		var owner := -1
		if u != null:
			if not units.has(u):
				units[u] = {"id": order.size(), "meshes": []}
				order.append(u)
			(units[u].meshes as Array).append(m3)
			owner = int(units[u].id)
		else:
			structs += 1
		var before := m3.get_child_count()
		m3.create_trimesh_collision()
		for i in range(before, m3.get_child_count()):
			var c := m3.get_child(i)
			if c is StaticBody3D:
				var sb: StaticBody3D = c
				sb.collision_layer = L
				sb.collision_mask = 0
				body_owner[sb.get_rid()] = owner
	# ещё и настоящие стены/полы-коллизии построек (у них есть сетки, но на всякий случай — двери, полки без сеток)
	for _i in 3:
		await physics_frame
	var space := w.get_world_3d().direct_space_state
	var floats := 0
	var sinks := 0
	var pens := 0
	for u in order:
		var info: Dictionary = units[u]
		var meshes: Array = info.meshes
		var bb := AABB()
		var first := true
		for mi in meshes:
			var m3: MeshInstance3D = mi
			var a := m3.global_transform * m3.mesh.get_aabb()
			bb = a if first else bb.merge(a)
			first = false
		if bb.size.length() < 0.01:
			continue
		var own: Array[RID] = []
		for mi in meshes:
			for c in (mi as Node).get_children():
				if c is StaticBody3D:
					own.append((c as StaticBody3D).get_rid())
		var floor_y := 0.03 if absf(bb.get_center().z) < 200.0 else -300.0
		var cellar := bb.get_center().z < -200.0
		var ground := 0.0 if not cellar else 0.03
		var bot := bb.position.y
		var top := bb.end.y
		var c := bb.get_center()
		var ex := bb.size * 0.5
		# лучи вниз из 5 точек низа
		var down := 99.0
		for o in [Vector2.ZERO, Vector2(0.6, 0.6), Vector2(-0.6, 0.6), Vector2(0.6, -0.6), Vector2(-0.6, -0.6)]:
			var from := Vector3(c.x + o.x * ex.x, bot + 0.02, c.z + o.y * ex.z)
			var h := _ray(space, from, from + Vector3(0, -4.0, 0), own)
			if not h.is_empty():
				down = minf(down, from.y - 0.02 - (h.position as Vector3).y)
		var on_ground := bot <= ground + 0.06
		# стены: 4 стороны на половине высоты и у низа
		var side := 99.0
		for dvec in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
			var d3: Vector3 = dvec
			var reach := absf(d3.x) * ex.x + absf(d3.z) * ex.z
			for hy in [0.5, 0.15, 0.85]:
				var from := Vector3(c.x, bot + bb.size.y * hy, c.z)
				var h := _ray(space, from, from + d3 * (reach + 0.3), own)
				if not h.is_empty():
					side = minf(side, from.distance_to(h.position) - reach)
		# подвес сверху
		var up := 99.0
		var hu := _ray(space, Vector3(c.x, top - 0.02, c.z), Vector3(c.x, top + 3.0, c.z), own)
		if not hu.is_empty():
			up = (hu.position as Vector3).y - top
		var ok := on_ground or down <= SUP or side <= SIDE or up <= SIDE
		var name := String(u.get_meta("kit", "prim"))
		var path := _short_path(u, w)
		var line := "%s %s низ=%.3f зазор_вниз=%s бок=%s верх=%s центр=(%.2f, %.2f, %.2f) размер=(%.2f, %.2f, %.2f)" % [
			path, name, bot, _f(down), _f(side), _f(up), c.x, c.y, c.z, bb.size.x, bb.size.y, bb.size.z]
		if not ok:
			floats += 1
			print("FLOAT ", line)
		elif down < -0.04 and not on_ground and side > SIDE:
			# низ ниже поверхности, на которую опирается: утоплен (луч из низа+2 см сразу упёрся внутрь опоры)
			sinks += 1
			print("SINK ", line)
		elif "--all" in OS.get_cmdline_user_args():
			print("OK ", line)
		# протыкание: выпуклые оболочки сеток предмета против точных треугольников всего остального
		var pen := _penetration(space, meshes, own)
		if pen.depth > PEN:
			pens += 1
			print("PEN %s %s глубина=%.3f во_что=%s центр=(%.2f, %.2f, %.2f) размер=(%.2f, %.2f, %.2f)" % [
				path, name, pen.depth, pen.what, c.x, c.y, c.z, bb.size.x, bb.size.y, bb.size.z])
	print("SUPPORT units=%d structs=%d float=%d sink=%d pen=%d" % [order.size(), structs, floats, sinks, pens])
	quit(0)


## Насколько глубоко предмет вошёл в чужую геометрию (по точкам контакта выпуклой оболочки с треугольниками).
## Выпуклая оболочка шире настоящей формы (ножки стула, полки), поэтому это кандидаты — их надо смотреть.
func _penetration(space: PhysicsDirectSpaceState3D, meshes: Array, own: Array[RID]) -> Dictionary:
	var best := 0.0
	var what := ""
	for mi in meshes:
		var m3: MeshInstance3D = mi
		var shp := m3.mesh.create_convex_shape(true, true)
		if shp == null:
			continue
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = shp
		q.transform = m3.global_transform
		q.collision_mask = L
		q.exclude = own
		q.margin = 0.0
		var pts := space.collide_shape(q, 32)
		for i in range(0, pts.size() - 1, 2):
			var d := (pts[i] as Vector3).distance_to(pts[i + 1])
			if d > best:
				best = d
				var hits := space.intersect_shape(q, 4)
				what = ""
				for h in hits:
					var rid: RID = h.rid
					var ow := int(body_owner.get(rid, -1))
					what += ("постройка" if ow < 0 else "предмет#%d" % ow) + ";"
	return {"depth": best, "what": what}


## Имя файла скрипта узла (классы проекта в --script напрямую не видны: автозагрузки компилируются позже).
func _scr(n: Node) -> String:
	var sc: Script = n.get_script()
	return "" if sc == null else sc.resource_path.get_file()


func _ray(space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3, own: Array[RID]) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(a, b, L)
	q.exclude = own
	q.hit_back_faces = true
	return space.intersect_ray(q)


func _f(v: float) -> String:
	return "—" if v > 50.0 else "%.3f" % v


func _short_path(n: Node, w: Node) -> String:
	var parts: Array = []
	var cur := n
	while cur != null and cur != w:
		var nm := String(cur.name)
		if not nm.begins_with("@"):
			parts.push_front(nm)
		cur = cur.get_parent()
	return "/".join(parts)


func _all_meshes(n: Node) -> Array:
	var res: Array = []
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		res.append(n)
	for c in n.get_children():
		res.append_array(_all_meshes(c))
	return res
