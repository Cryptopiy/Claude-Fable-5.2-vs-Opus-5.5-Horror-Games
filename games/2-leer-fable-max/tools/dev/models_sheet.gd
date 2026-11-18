extends SceneTree
## Кадр каждой модели mdl/*/m.gltf при ровном свете — искать битые и растянутые текстуры, чужие надписи.
## Запуск (окно нужно для отрисовки):
##   godot --path . --windowed --max-fps 30 --audio-driver Dummy --resolution 640x480 --script tools/dev/models_sheet.gd -- --out=<папка> [--only=a,b]
## Пишет <папка>/<имя>.png (3/4 спереди сверху) и <имя>_b.png (сзади).

var out := ""
var names: PackedStringArray
var cam: Camera3D
var holder: Node3D
var i := 0
var side := 0
var wait := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	names = DirAccess.get_directories_at("res://mdl")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			names = PackedStringArray(a.substr(7).split(","))
	DirAccess.make_dir_recursive_absolute(out)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.22, 0.22, 0.24)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1, 1, 1)
	e.ambient_light_energy = 0.45
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 35, 0)
	sun.light_energy = 1.4
	root.add_child(sun)
	cam = Camera3D.new()
	cam.fov = 40.0
	root.add_child(cam)
	cam.make_current()
	holder = Node3D.new()
	root.add_child(holder)


func _process(_dt: float) -> bool:
	if wait > 0:
		wait -= 1
		return false
	# снять то, что стоит сейчас
	if holder.get_child_count() > 0:
		var img := root.get_viewport().get_texture().get_image()
		img.save_png("%s/%s%s.png" % [out, names[i], "" if side == 0 else "_b"])
		if side == 0:
			side = 1
			_aim()
			wait = 3
			return false
		for c in holder.get_children():
			c.free()
		side = 0
		i += 1
	if i >= names.size():
		print("MODELS done ", names.size())
		quit()
		return true
	var p := "res://mdl/%s/m.gltf" % names[i]
	if not ResourceLoader.exists(p):
		print("MODELS missing ", names[i])
		i += 1
		return false
	var ps: PackedScene = load(p)
	holder.add_child(ps.instantiate())
	_aim()
	wait = 4
	return false


func _aim() -> void:
	var bb := AABB()
	var first := true
	for mi in _meshes(holder):
		var m: MeshInstance3D = mi
		var a := m.global_transform * m.mesh.get_aabb()
		bb = a if first else bb.merge(a)
		first = false
	var c := bb.get_center()
	var r := maxf(bb.size.length() * 0.5, 0.05)
	var dir := Vector3(0.75, 0.55, 1.0).normalized()
	if side == 1:
		dir = Vector3(-0.75, 0.45, -1.0).normalized()
	cam.global_position = c + dir * r / tan(deg_to_rad(20.0)) * 1.05
	cam.look_at(c)
	cam.near = r * 0.02
	cam.far = r * 20.0


func _meshes(n: Node) -> Array:
	var res: Array = []
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		res.append(n)
	for c in n.get_children():
		res.append_array(_meshes(c))
	return res
