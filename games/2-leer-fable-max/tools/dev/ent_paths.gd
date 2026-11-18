extends SceneTree
## Проверка: скриптовые маршруты существа (Nights.N4_*, CELLAR_RUN) и его позы в сценах не проходят сквозь мебель и стены.
## Запуск (из папки проекта):
##   godot --headless --path . --script tools/dev/ent_paths.gd -- --place=main --test --nocold --god --nogust
## Тело существа — вертикальный цилиндр радиусом R от колен до плеч; двери на маршруте открыты (их открывает Nights._ent_opens_doors).
## Печатает PATH OK <имя> или PATH HIT <имя> at (x, z) <что задето>; в конце PATHS OK / PATHS FAIL n.
## --old: проверить и старый маршрут ночи 4 (через стол) — тест должен упасть.

const R := 0.2
const STEP := 0.05

var g: Node
var t := 0.0
var done := false


func _initialize() -> void:
	change_scene_to_file("res://src/main.tscn")


func _process(dt: float) -> bool:
	t += dt
	if done:
		return false
	if g == null:
		g = root.get_node_or_null("G")
		return false
	var w = g.get("world")
	var p = g.get("player")
	if w == null or p == null or not is_instance_valid(p) or not p.is_inside_tree() or t < 2.0:
		if t > 60.0:
			print("PATHS FAIL no world")
			quit(2)
		return false
	done = true
	for k in ["house", "vest", "bunk", "radio", "store"]:
		w.doors[k].set_open(true, true, true)
	# игрок не должен мешать проверке
	p.teleport(Vector3(0, 0, 40), 0.0)
	_run.call_deferred(w)
	return false


func _run(w: Node3D) -> void:
	await physics_frame
	await physics_frame
	# классы проекта берём через load(): при запуске --script автозагрузки компилируются позже
	var N: Dictionary = (load("res://src/nights.gd") as GDScript).get_script_constant_map()
	var B: Dictionary = (load("res://src/world/build_sites.gd") as GDScript).get_script_constant_map()
	var fy: float = N.FY
	var cel: Vector3 = B.CELLAR
	var routes := [
		["n4_in", [N.N4_IN_FROM] + N.N4_IN],
		["n4_to_bed", [(N.N4_IN as Array).back()] + N.N4_TO_BED],
		["n4_side", [(N.N4_TO_BED as Array).back()] + N.N4_SIDE],
		["n4_back", [(N.N4_SIDE as Array).back()] + N.N4_BACK],
		["n4_out", [(N.N4_BACK as Array).back()] + N.N4_OUT],
	]
	var cr: Array = [cel + N.CELLAR_FROM]
	for q in N.CELLAR_RUN:
		cr.append(cel + q)
	routes.append(["cellar_run", cr])
	# позы в сценах: точки, где оно стоит
	routes.append(["n4_window_face", [Vector3(0.0, -0.42, -3.62)]])
	routes.append(["hideview", [Vector3(3.5, fy, -1.25)]])
	routes.append(["n3_porch", [Vector3(6.25, 0, 1.6)]])
	if "--old" in OS.get_cmdline_user_args():
		routes.append(["old_n4_in", [Vector3(6.4, 0, 1.6), Vector3(3.6, fy, 1.6), Vector3(2.3, fy, 1.6), Vector3(0.9, fy, 1.4), Vector3(0.7, fy, -1.3), Vector3(1.6, fy, -1.6)]])
		routes.append(["old_cellar", [cel + Vector3(1.75, fy, 15.6), cel + Vector3(1.75, fy, 8.2), cel + Vector3(0.25, fy, 6.8)]])
	var space := w.get_world_3d().direct_space_state
	var cyl := CylinderShape3D.new()
	cyl.radius = R
	cyl.height = 1.2
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cyl
	q.collision_mask = 1
	var fails := 0
	for r in routes:
		var name: String = r[0]
		var pts: Array = r[1]
		var hits := {}
		var first := ""
		var samples: Array = []
		if pts.size() == 1:
			samples.append(pts[0])
		for i in pts.size() - 1:
			var a: Vector3 = pts[i]
			var b: Vector3 = pts[i + 1]
			var n := maxi(1, int(ceil(a.distance_to(b) / STEP)))
			for k in n + 1:
				samples.append(a.lerp(b, float(k) / float(n)))
		for s in samples:
			var sp: Vector3 = s
			q.transform = Transform3D(Basis.IDENTITY, Vector3(sp.x, sp.y + 0.45 + 0.6, sp.z))
			for h in space.intersect_shape(q, 8):
				var c: Object = h.collider
				var label := _label(c)
				if not hits.has(label):
					hits[label] = Vector2(sp.x, sp.z)
					if first == "":
						first = "(%.2f, %.2f) %s" % [sp.x, sp.z, label]
		if hits.is_empty():
			print("PATH OK ", name, " (", samples.size(), " samples)")
		else:
			fails += 1
			print("PATH HIT ", name, " at ", first, "  all: ", hits.keys())
	print("PATHS OK" if fails == 0 else "PATHS FAIL %d" % fails)
	quit(0 if fails == 0 else 1)


func _label(c: Object) -> String:
	if c is Node:
		var n: Node = c
		var s := String(n.name)
		var par := n.get_parent()
		for i in 3:
			if par == null:
				break
			s = String(par.name) + "/" + s
			par = par.get_parent()
		if n is Node3D:
			var p3 := (n as Node3D).global_position
			s += " @(%.2f, %.2f)" % [p3.x, p3.z]
		return s
	return str(c)
