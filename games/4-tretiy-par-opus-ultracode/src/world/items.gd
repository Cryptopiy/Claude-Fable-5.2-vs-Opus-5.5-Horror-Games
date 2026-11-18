class_name Items
## Подбираемые и бросаемые вещи, вентили, зеркала, свет огня.

## Палитра света «Сырой свет»: огонь и свечи — янтарь, натриевые фонари двора, холодная луна сквозь иней.
const FIRE := Color(1.0, 0.52, 0.2)
const CANDLE := Color(1.0, 0.64, 0.32)
const SODIUM := Color(1.0, 0.6, 0.22)
const MOON := Color(0.58, 0.74, 0.8)


## Шайка (жестяной таз): взять E, бросить ЛКМ — громкий звон уводит Хозяйку.
class Basin:
	extends RigidBody3D
	var flying := false
	var cool := 0.0

	func _ready() -> void:
		mass = 0.6
		collision_layer = 1 << 5
		collision_mask = 1 | 4
		contact_monitor = true
		max_contacts_reported = 2
		continuous_cd = true
		body_entered.connect(_hit)
		# открытая жестяная шайка: без верхней крышки (изнутри видны стенки и дно — двусторонний материал),
		# закатанный край; тусклая луженая жесть, а не зеркальная «шайба»
		var mat := Mat.flat(Color(0.55, 0.56, 0.55), 0.55, 0.45, {"cull_off": true})
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.2
		cm.bottom_radius = 0.15
		cm.height = 0.12
		cm.radial_segments = 16
		cm.cap_top = false
		mi.mesh = cm
		mi.material_override = mat
		add_child(mi)
		var rim := MeshInstance3D.new()
		var tor := TorusMesh.new()
		tor.inner_radius = 0.192
		tor.outer_radius = 0.212
		tor.rings = 16
		tor.ring_segments = 6
		rim.mesh = tor
		rim.material_override = mat
		rim.position = Vector3(0, 0.06, 0)
		add_child(rim)
		for s in [-1.0, 1.0]:
			Geo.mesh_box(self, Vector3(0.06, 0.02, 0.03), mat, Vector3(s * 0.21, 0.04, 0))
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = 0.19
		sh.height = 0.12
		cs.shape = sh
		# коллизия чуть ниже меша: дно шайки на 1.5 см над тем, на чём стоит (не мерцает с плиткой лавки)
		cs.position = Vector3(0, -0.015, 0)
		add_child(cs)
		var u := StaticBody3D.new()
		u.collision_layer = 8
		add_child(u)
		var cs2 := CollisionShape3D.new()
		var sh2 := BoxShape3D.new()
		sh2.size = Vector3(0.45, 0.2, 0.45)
		cs2.shape = sh2
		u.add_child(cs2)
		u.set_meta("usable", self)

	func get_prompt(_p: Node) -> String:
		if Game.player and Game.player.held_item == self:
			return ""
		return "Взять шайку"

	func use(p: Node) -> void:
		(p as Player).pick_item(self)

	func thrown() -> void:
		flying = true

	func _process(delta: float) -> void:
		cool = maxf(0.0, cool - delta)

	func _hit(_b: Node) -> void:
		if cool > 0.0:
			return
		var v := linear_velocity.length()
		if v < 1.0:
			return
		cool = 0.25
		Snd.at("basin_clang", global_position, clampf(-14.0 + v * 2.0, -12.0, 4.0), randf_range(0.9, 1.1), 30.0)
		if flying and Game.world:
			Game.world.noise(global_position, 22.0, "throw")
		if Game.world and Game.world.water_depth(global_position) > 0.0:
			Game.world.ripple(global_position, 6.0)
		flying = false


## Предмет на полу/столе: E — забрать. kind: item / note / battery / photo
static func pickup(parent: Node3D, pos: Vector3, kind: String, id: String, label: String, visual: Node3D = null, after: Callable = Callable()) -> Usable:
	var u := Usable.make(parent, pos, Vector3(0.4, 0.3, 0.4), label, Callable())
	u.once = true
	if visual:
		u.add_child(visual)
	u.on_use = func():
		match kind:
			"item":
				Game.give(id)
			"note":
				Game.add_note(id)
				if Game.main and Game.main.has_method("show_note"):
					Game.main.show_note(id)
			"battery":
				if Game.player:
					Game.player.add_battery(55.0)
				Snd.play("battery", -4.0)
				Game.think("Батарейки. Фонарь ещё поживёт.", 2.5)
		Game.set_flag("took:" + id)
		if after.is_valid():
			after.call()
		u.queue_free()
	if Game.flag("took:" + id):
		u.queue_free()
	return u


## Бумага/записка, лежащая плоско.
static func paper_visual(tex_path: String, size := Vector2(0.21, 0.28)) -> Node3D:
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = size
	mi.mesh = qm
	mi.material_override = Mat.picture(tex_path, {"rough": 0.9})
	mi.rotation.x = -PI * 0.5
	mi.position.y = -0.14
	return mi


static func battery_visual() -> Node3D:
	var n := Node3D.new()
	var m := Mat.flat(Color(0.15, 0.3, 0.6), 0.5, 0.2)
	var m2 := Mat.flat(Color(0.7, 0.7, 0.68), 0.3, 0.9)
	for i in 2:
		var c := Geo.mesh_cyl(n, 0.017, 0.06, m, Vector3(i * 0.04 - 0.02, -0.12, 0))
		c.rotation.z = PI * 0.5
		var cap := Geo.mesh_cyl(n, 0.008, 0.008, m2, Vector3(i * 0.04 - 0.02 + 0.033, -0.12, 0))
		cap.rotation.z = PI * 0.5
	return n


static func key_visual() -> Node3D:
	var n := Node3D.new()
	var m := Mat.flat(Color(0.55, 0.48, 0.3), 0.35, 0.9)
	Geo.mesh_box(n, Vector3(0.06, 0.004, 0.025), m, Vector3(0, -0.14, 0))
	Geo.mesh_cyl(n, 0.018, 0.005, m, Vector3(-0.045, -0.14, 0))
	var tag := Geo.mesh_box(n, Vector3(0.05, 0.003, 0.03), Mat.flat(Color(0.7, 0.2, 0.15), 0.8), Vector3(-0.09, -0.142, 0.01))
	tag.rotation.y = 0.4
	return n


## Вентиль: держать E, колесо крутится, скрип; done — по завершении.
static func valve(parent: Node3D, pos: Vector3, normal_yaw: float, radius: float, label: String, hold: float, done: Callable, cond := Callable(), noise_r := 10.0) -> Usable:
	var u := Usable.make(parent, pos, Vector3(radius * 2.2, radius * 2.2, 0.3), label, done, hold)
	u.rotation.y = normal_yaw
	u.cond = cond
	u.hold_sound = "loop_valve"
	u.hold_noise = noise_r
	var wheel := Node3D.new()
	u.add_child(wheel)
	# красная краска — единственный насыщенный не-янтарный цвет в игре: «это можно повернуть»
	var m := Mat.flat(Color(0.45, 0.06, 0.04), 0.35, 0.3)
	var tor := TorusMesh.new()
	tor.inner_radius = radius - 0.025
	tor.outer_radius = radius
	tor.rings = 24
	tor.ring_segments = 8
	var tm := MeshInstance3D.new()
	tm.mesh = tor
	tm.material_override = m
	tm.rotation.x = PI * 0.5
	wheel.add_child(tm)
	for a in 3:
		var sp := Geo.mesh_box(wheel, Vector3(radius * 2.0, 0.025, 0.02), m, Vector3.ZERO)
		sp.rotation.z = a * PI / 3.0
	Geo.mesh_cyl(wheel, 0.03, 0.12, Mat.flat(Color(0.3, 0.3, 0.3), 0.5, 0.8), Vector3(0, 0, 0.06)).rotation.x = PI * 0.5
	u.spin = wheel
	return u


## Огонь в топке: оранжевый мерцающий свет.
class Fire:
	extends OmniLight3D
	var base := 2.0
	var t := 0.0
	var dip := 0.0

	# значения по умолчанию — в конструкторе: дальность и цвет, заданные до add_child, больше не затираются
	# в _ready (свеча светила на 6 м вместо 3.5, печь парилки — на 6 вместо 5: сквозь стены в соседние комнаты)
	func _init() -> void:
		light_color = Items.FIRE
		omni_range = 6.0
		omni_attenuation = 1.4
		shadow_enabled = false

	func _ready() -> void:
		light_energy = base

	func _process(delta: float) -> void:
		t += delta
		var m: Node3D = Game.monster as Node3D
		if m and m.visible and m.global_position.distance_squared_to(global_position) < 9.0:
			dip = minf(1.0, dip + delta * 3.0)
		else:
			dip = maxf(0.0, dip - delta * 0.7)
		var f := 0.75 + 0.15 * sin(t * 9.0) + 0.1 * sin(t * 23.0 + 1.3) + randf() * 0.08
		light_energy = base * f * (1.0 - dip * (0.5 + randf() * 0.15))


## Пасть топки: за решёткой дверцы — жар (текстура углей с эмиссией), перед ней на полу полосатый янтарный клин
## (прожектор без тени с маской решётки) и мягкий отражённый свет. pos — центр дверцы, normal — наружу.
static func fire_mouth(parent: Node3D, pos: Vector3, normal: Vector3, size: Vector2, energy := 3.0) -> void:
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = size
	mi.mesh = qm
	var m := StandardMaterial3D.new()
	var t: Texture2D = Mat.tex("res://tex/gen/firebox.png")
	m.albedo_texture = t
	m.albedo_color = Color(0.2, 0.08, 0.04)
	m.emission_enabled = true
	m.emission_texture = t
	# светит только сама текстура углей: при операторе «сложение» цвет emission добавлялся и к чёрным прутьям
	# решётки в firebox.png — пасть горела ровной оранжевой плитой
	m.emission = Color(0, 0, 0)
	m.emission_energy_multiplier = 3.2
	m.roughness = 0.9
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos + normal * 0.012
	mi.rotation.y = Props.yaw_to(-normal)
	# чугунная решётка дверцы: прутья поверх жара (свечение их не съедает)
	var g := Node3D.new()
	parent.add_child(g)
	g.global_position = pos + normal * 0.03
	g.rotation.y = Props.yaw_to(-normal)
	var gb := Geo.Batch.new()
	var iron := Mat.flat(Color(0.05, 0.045, 0.04), 0.7, 0.6)
	# прутья — по тёмным промежуткам firebox.png (между четырьмя полосами углей), а не по середине полос:
	# иначе каждая полоса делилась на две щели и пасть читалась табличкой с «текстом»
	for k in range(1, 4):
		var yy := -size.y * 0.5 + size.y * float(k) / 4.0
		gb.box(iron, Vector3(0, yy, 0), Vector3(size.x, size.y * 0.07, 0.025))
	gb.box(iron, Vector3(0, size.y * 0.5, 0), Vector3(size.x + 0.04, 0.03, 0.03))
	gb.box(iron, Vector3(0, -size.y * 0.5, 0), Vector3(size.x + 0.04, 0.03, 0.03))
	gb.box(iron, Vector3(size.x * 0.5, 0, 0), Vector3(0.03, size.y, 0.03))
	gb.box(iron, Vector3(-size.x * 0.5, 0, 0), Vector3(0.03, size.y, 0.03))
	gb.commit(g, "grate", false)
	var sp := SpotLight3D.new()
	sp.light_color = FIRE
	sp.light_energy = energy
	sp.spot_range = 6.0
	sp.spot_angle = 60.0
	sp.spot_attenuation = 2.0
	sp.shadow_enabled = false
	sp.light_specular = 0.5
	sp.light_volumetric_fog_energy = 2.0
	var ck: Texture2D = Mat.tex("res://tex/gen/cookie_grate.png")
	if ck:
		sp.light_projector = ck
	parent.add_child(sp)
	sp.global_position = pos + normal * 0.06
	sp.look_at(sp.global_position + normal + Vector3.DOWN * 0.47)
	var fl := Node.new()
	fl.set_script(load("res://src/world/flicker.gd"))
	fl.set("light", sp)
	fl.set("base", energy)
	fl.set("fire", true)
	parent.add_child(fl)


## Мягкий отражённый свет (без бликов: не рисует на мокром полу отблеск от несуществующего источника).
static func bounce(parent: Node3D, pos: Vector3, col: Color, energy: float, rng: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.omni_attenuation = 1.5
	l.light_specular = 0.0
	l.shadow_enabled = false
	parent.add_child(l)
	l.global_position = pos
	return l


## Свеча: маленький огонёк и тёплый свет.
static func candle(parent: Node3D, pos: Vector3, lit := true) -> Node3D:
	var n := Node3D.new()
	parent.add_child(n)
	n.global_position = pos
	var wax := Mat.flat(Color(0.85, 0.8, 0.68), 0.6)
	Geo.mesh_cyl(n, 0.018, 0.12 + randf() * 0.06, wax, Vector3(0, 0.07, 0), 8)
	if lit:
		var fl := Mat.flat(Color(1, 0.7, 0.3), 0.5, 0.0, {"emission": Color(1.0, 0.6, 0.2), "emission_energy": 6.0, "unshaded": true})
		var f := Geo.mesh_cyl(n, 0.006, 0.03, fl, Vector3(0, 0.17, 0), 6, 0.0)
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var l := Fire.new()
		l.base = 0.45
		l.omni_range = 3.5
		l.light_color = Items.CANDLE
		l.position = Vector3(0, 0.25, 0)
		n.add_child(l)
	return n
