extends SceneTree
## Проверка: капсула игрока проходит пешком от койки через кают-компанию и тамбур на улицу.
## Запуск (из папки проекта):
##   godot --headless --path . --script tools/dev/walk_exit.gd -- --place=bed --test --nocold --god --nogust
## Печатает WALK OK outside или WALK FAIL stuck at (x, z) going to waypoint N.
## --oldchair: поставить коробку размером со стул на старое место (1.56, 1.3) — тест должен упереться.
## Образец для других проверок проходимости: меняй WP (маршрут) и стартовую точку.

const WP := [Vector3(2.5, 0, -1.6), Vector3(1.55, 0, -1.6), Vector3(1.55, 0, 1.6), Vector3(2.6, 0, 1.6),
	Vector3(4.4, 0, 1.6), Vector3(6.6, 0, 1.6)]

var g: Node
var t := 0.0
var started := false
var wi := 0
var stuck_t := 0.0
var last := Vector3.ZERO


func _initialize() -> void:
	change_scene_to_file("res://src/main.tscn")


func _process(dt: float) -> bool:
	t += dt
	if g == null:
		g = root.get_node_or_null("G")
		return false
	var p = g.get("player")
	if p == null or not is_instance_valid(p) or not p.is_inside_tree():
		if t > 60.0:
			print("WALK FAIL no player")
			quit(2)
		return false
	if not started:
		if t < 3.0:
			return false
		started = true
		var w = g.get("world")
		for k in ["vest", "house"]:
			var d = w.doors[k]
			d.barred = false
			d.locked = false
			d.set_open(true, true, true)
		if "--oldchair" in OS.get_cmdline_user_args():
			var b := StaticBody3D.new()
			var cs := CollisionShape3D.new()
			var sh := BoxShape3D.new()
			sh.size = Vector3(0.54, 0.96, 0.43)
			cs.shape = sh
			cs.position.y = 0.48
			b.add_child(cs)
			w.add_child(b)
			b.global_position = Vector3(1.56, 0.03, 1.3)
		p.teleport(Vector3(3.5, 0.03, -1.2), 90.0)
		last = p.global_position
		print("WALK start ", p.global_position)
		return false
	var target: Vector3 = WP[wi]
	var to: Vector3 = target - p.global_position
	to.y = 0.0
	if to.length() < 0.25:
		print("WALK reached %d (%.2f, %.2f) at t=%.1f" % [wi, p.global_position.x, p.global_position.z, t])
		wi += 1
		stuck_t = 0.0
		if wi >= WP.size():
			Input.action_release("move_f")
			print("WALK OK outside")
			quit(0)
		return false
	p.yaw = atan2(-to.x, -to.z)
	p.pitch = 0.0
	Input.action_press("move_f")
	if p.global_position.distance_to(last) < 0.004:
		stuck_t += dt
	else:
		stuck_t = 0.0
	last = p.global_position
	if stuck_t > 2.0 or t > 120.0:
		Input.action_release("move_f")
		print("WALK FAIL stuck at (%.2f, %.2f) going to waypoint %d %s" % [p.global_position.x, p.global_position.z, wi, str(target)])
		quit(1)
	return false
