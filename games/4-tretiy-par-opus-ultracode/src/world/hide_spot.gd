class_name HideSpot
extends StaticBody3D
## Где спрятаться: служебный шкафчик (видно в щели) или под нижним полком парилки.
## Если Хозяйка слышала, как ты прятался, — она вскроет именно это место.

var kind := "locker"
var door_pivot: Node3D
var inside := false
var face_yaw := 0.0
var slats: MeshInstance3D
var busy := false     # дверца ещё ходит — повторное нажатие не рассинхронизирует «внутри/снаружи»


static func make_locker(parent: Node3D, pos: Vector3, yaw: float) -> HideSpot:
	var h := HideSpot.new()
	h.kind = "locker"
	h.collision_layer = 1 | 8
	h.collision_mask = 0
	parent.add_child(h)
	h.global_position = pos
	h.rotation.y = yaw
	h.face_yaw = yaw
	h._build_locker()
	return h


static func make_bench(parent: Node3D, pos: Vector3, yaw: float) -> HideSpot:
	var h := HideSpot.new()
	h.kind = "bench"
	h.collision_layer = 8
	h.collision_mask = 0
	parent.add_child(h)
	h.global_position = pos
	h.rotation.y = yaw
	h.face_yaw = yaw
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(1.6, 0.35, 0.6)
	cs.shape = sh
	cs.position = Vector3(0, 0.2, 0)
	h.add_child(cs)
	return h


func _build_locker() -> void:
	# краска по металлу почти не отражает: металличность 0.4 без отражений в окружении съедала цвет
	var mat := Mat.m("metal_green", {"metal": 0.1, "tint": Color(0.75, 0.82, 0.78), "scale": 1.2, "local": true})
	var dark := Mat.flat(Color(0.03, 0.03, 0.03), 0.9)
	var b := Geo.Batch.new()
	var W := 0.62
	var D := 0.55
	var H := 1.95
	# корпус (открыт спереди: перед — -Z)
	b.box(mat, Vector3(0, H * 0.5, D * 0.5 - 0.01), Vector3(W, H, 0.02))
	b.box(mat, Vector3(-W * 0.5, H * 0.5, 0), Vector3(0.02, H, D))
	b.box(mat, Vector3(W * 0.5, H * 0.5, 0), Vector3(0.02, H, D))
	b.box(mat, Vector3(0, H, 0), Vector3(W, 0.02, D))
	b.box(mat, Vector3(0, 0.05, 0), Vector3(W, 0.1, D))
	b.box(dark, Vector3(0, H * 0.5, D * 0.5 - 0.03), Vector3(W - 0.05, H - 0.1, 0.01))
	b.commit(self, "locker")
	for cs_def in [[Vector3(0, H * 0.5, D * 0.5 - 0.01), Vector3(W, H, 0.04)], [Vector3(-W * 0.5, H * 0.5, 0), Vector3(0.04, H, D)],
			[Vector3(W * 0.5, H * 0.5, 0), Vector3(0.04, H, D)]]:
		Geo.col_box(self, cs_def[0], cs_def[1])
	# дверца на петлях слева, с прорезями
	door_pivot = Node3D.new()
	door_pivot.position = Vector3(-W * 0.5, 0, -D * 0.5)
	add_child(door_pivot)
	var db := Geo.Batch.new()
	db.box(mat, Vector3(W * 0.5, H * 0.5 + 0.05, 0), Vector3(W - 0.02, H - 0.1, 0.02))
	for i in 5:
		db.box(dark, Vector3(W * 0.5, 1.45 + i * 0.045, -0.011), Vector3(W * 0.6, 0.018, 0.005))
	db.box(Mat.flat(Color(0.5, 0.5, 0.45), 0.4, 0.9), Vector3(W - 0.08, 1.05, -0.02), Vector3(0.03, 0.12, 0.02))
	db.commit(door_pivot, "door")
	var body := StaticBody3D.new()
	body.collision_layer = 8
	door_pivot.add_child(body)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(W, H, 0.05)
	cs.shape = sh
	cs.position = Vector3(W * 0.5, H * 0.5, 0)
	body.add_child(cs)
	body.set_meta("usable", self)


func get_prompt(_p: Node) -> String:
	if inside:
		return "Вылезти" if kind == "bench" else "Выйти из шкафчика"
	return "Залезть под полок" if kind == "bench" else "Спрятаться в шкафчик"


func eye_height() -> float:
	return 0.17 if kind == "bench" else 1.55


## Оси укрытия: локальный -Z — «внутрь» (дверца шкафчика / под полок). Шкафчик: прячешься спиной к задней
## стенке и смотришь в щели дверцы (-Z). Полок: залезаешь под доски к стене и смотришь наружу (+Z).
func _look_yaw() -> float:
	return face_yaw if kind == "locker" else face_yaw + PI


func _inside_pos() -> Vector3:
	if kind == "bench":
		return global_position + global_transform.basis * Vector3(0, 0.05, -0.65)
	return global_position + global_transform.basis * Vector3(0, 0.05, 0.02)


func _out_pos() -> Vector3:
	return global_position + global_transform.basis * (Vector3(0, 0.05, -0.75) if kind == "locker" else Vector3(0, 0.05, 0.6))


func use(p: Node) -> void:
	var pl := p as Player
	if busy:
		return
	busy = true
	if inside:
		inside = false
		_door(true)
		pl.unhide(_out_pos())
		pl.set_look(_look_yaw(), 0.0)
		_keep_behind()
		await get_tree().create_timer(0.35, false).timeout
		_door(false)
		busy = false
		return
	inside = true
	_door(true)
	await get_tree().create_timer(0.25, false).timeout
	if not is_instance_valid(pl) or pl.dead:
		inside = false
		busy = false
		return
	pl.hide_in(self, _inside_pos(), _look_yaw())
	pl.set_look(_look_yaw(), 0.0)
	_keep_behind()
	_door(false)
	busy = false
	if Game.main and Game.main.has_method("set_slats"):
		Game.main.set_slats(kind)


## Разворот камеры при входе/выходе делает игра: если Хозяйка «за спиной» — она остаётся за спиной,
## а не оказывается перед глазами (иначе мгновенная смерть «посмотрел на неё»).
func _keep_behind() -> void:
	if Game.world == null:
		return
	var m: Hozyayka = Game.world.monster
	if m:
		m.snap_behind()


func _door(open: bool) -> void:
	if door_pivot == null:
		return
	var t := create_tween()
	t.tween_property(door_pivot, "rotation:y", deg_to_rad(-100) if open else 0.0, 0.25)
	Snd.at("locker_open" if open else "locker_close", global_position + Vector3.UP, -4.0, randf_range(0.9, 1.1))


## Хозяйка вскрывает укрытие.
func monster_open(m: Node) -> void:
	_door(true)
	Snd.at("locker_rip", global_position + Vector3.UP, 4.0)
	if inside and Game.player and Game.player.hidden_in == self:
		await get_tree().create_timer(0.3, false).timeout
		if m.has_method("kill"):
			inside = false
			Game.player.unhide(_out_pos())
			m.kill()
	else:
		await get_tree().create_timer(1.2, false).timeout
		_door(false)
