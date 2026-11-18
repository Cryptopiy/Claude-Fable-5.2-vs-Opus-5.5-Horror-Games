class_name World
extends Node3D
## Станция «Тихая»: земля, пурга, леера, постройки, зоны тепла и состояние (дизель, печь, свет).

signal power_changed(on: bool)

var weather: Weather
var ropes: Ropes
var prints: Prints
var player: Player
var zones: Array = []          # {id, box: AABB, surface, shelter, cold_air}
var places := {}               # имя -> [Vector3, yaw°]
var doors := {}                # id -> Door
var things := {}               # id -> узел или словарь (приборы, дизель, печь…) — заполняют строители
var power_lights: Array = []   # [Light3D, энергия] — электрический свет, гаснет вместе с дизелем
var power_halos: Array = []    # ореолы электрических ламп
var power_glow: Array = []     # [StandardMaterial3D, энергия] — светящиеся плафоны и окна
var window_mats: Array = []    # внутренние стёкла дома (иней растёт по ночам)
var dips := 0.0                # перебои напряжения: сколько «просадок» света в минуту (по ночам больше)
var _dip_t := 0.0

# состояние станции
var gen_on := true             # дизель работает
var gen_fuel := 70.0           # топливо, проценты бака
var stove_t := 600.0           # печь в доме: сколько секунд ещё горит
var balok_stove_t := 0.0       # печь в балке

var lantern_on := false         # керосиновая лампа на столе
var beacon_on := true          # маяк мачты (сценарий может «сломать»)
var _t := 0.0
var _outside := {"id": "", "surface": "snow", "shelter": 0.0, "cold_air": 1.0}
var _power_k := 1.0
var _flick_t := 0.0
const RELIEF_R := 22.0             # полуширина ближнего лоскута земли с рельефом, м
const RELIEF_STEP := 0.55          # шаг сетки лоскута, м (лоскут едет за камерой этим же шагом)
var _relief: MeshInstance3D
var _relief_mat: ShaderMaterial
var _ground_mat: ShaderMaterial


func _ready() -> void:
	weather = Weather.new()
	weather.name = "Weather"
	add_child(weather)
	_build_ground()
	ropes = Ropes.new()
	ropes.name = "Ropes"
	add_child(ropes)
	for id in Map.LINES:
		var old := String(id) == "F"
		var col := Ropes.FADED if old else (Ropes.GREY if String(id) == "X" else Ropes.RED)
		ropes.add_line(String(id), Map.LINES[id], String(Map.TITLES[id]), col, old)
	ropes.lines["X"].hidden = true
	(ropes.lines["F"].gaps as Array).append([30.0, 41.0])
	prints = Prints.new()
	prints.name = "Prints"
	add_child(prints)
	Build.all(self)
	Cfg.changed.connect(_apply_fx)
	_apply_fx()
	ropes.build()
	# снег не идёт внутри помещений: коробки зон (весь дом — одной коробкой)
	var boxes: Array = []
	var house := AABB()
	for z in zones:
		var bb: AABB = z.box
		if String(z.id) in ["house", "radio", "bunk", "store", "vest"]:
			house = bb if house.size == Vector3.ZERO else house.merge(bb)
		else:
			boxes.append(bb.grow(0.05))
	if house.size != Vector3.ZERO:
		boxes.push_front(house.grow(0.05))
	weather.set_hide_boxes(boxes)
	set_power(gen_on, true)


func _build_ground() -> void:
	_build_snow_mask()
	var sm := ShaderMaterial.new()
	sm.shader = load("res://src/shaders/snow.gdshader")
	sm.set_shader_parameter("albedo_tex", Kit.tex("res://tex/snow_d"))
	sm.set_shader_parameter("normal_tex", Kit.tex("res://tex/snow_n"))
	sm.set_shader_parameter("noise_tex", Kit.tex("res://tex/noise"))
	# дальняя плоскость чуть ниже нуля: поверх неё лежит ближний лоскут с рельефом
	var g := MeshInstance3D.new()
	g.name = "Ground"
	var pm := PlaneMesh.new()
	pm.size = Vector2(3000, 3000)
	g.mesh = pm
	g.material_override = sm
	g.position.y = -0.004
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(g)
	# ближний лоскут: сетка 0,5 м вокруг камеры, вершины поднимает шейдер (заструги, волны, сугробы у лееров)
	_relief = MeshInstance3D.new()
	_relief.name = "GroundRelief"
	var rp := PlaneMesh.new()
	rp.size = Vector2(RELIEF_R * 2.0, RELIEF_R * 2.0)
	rp.subdivide_width = int(round(RELIEF_R * 2.0 / RELIEF_STEP)) - 1
	rp.subdivide_depth = int(round(RELIEF_R * 2.0 / RELIEF_STEP)) - 1
	_relief.mesh = rp
	_relief_mat = sm.duplicate()
	_relief_mat.set_shader_parameter("relief", 1.0)
	_relief_mat.set_shader_parameter("patch_r", RELIEF_R)
	_relief.material_override = _relief_mat
	_relief.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_relief.extra_cull_margin = 1.0
	add_child(_relief)
	_ground_mat = sm
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	cs.shape = WorldBoundaryShape3D.new()
	body.add_child(cs)
	add_child(body)


## Маска снега станции (512×512 на 200×200 м): R — утоптано вдоль лееров и у построек, G — пол построек.
## Её читает snowfield.gdshaderinc (рельеф земли и следов).
func _build_snow_mask() -> void:
	var n := 512
	var org := Vector2(-100.0, -100.0)
	var k := float(n) / 200.0
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 1))
	var px := func(x: float, z: float) -> Vector2i:
		return Vector2i(int((x - org.x) * k), int((z - org.y) * k))
	# вдоль лееров натоптано (кроме ложной ветки пятой ночи — по ней никто не ходил)
	for id in Map.LINES:
		if String(id) == "X":
			continue
		var pts: Array = Map.LINES[id]
		var c := Color(0.55, 0, 0, 1) if String(id) == "F" else Color(1, 0, 0, 1)
		for i in pts.size() - 1:
			var a: Vector3 = pts[i]
			var b: Vector3 = pts[i + 1]
			var steps := maxi(1, int(a.distance_to(b) / 0.4))
			for j in steps + 1:
				var p := a.lerp(b, float(j) / float(steps))
				var q: Vector2i = px.call(p.x, p.z)
				img.fill_rect(Rect2i(q.x - 2, q.y - 2, 5, 5), c)
	# вокруг построек натоптано, под ними — ровно
	var sites := [[Map.HOUSE_MIN, Map.HOUSE_MAX], [Map.SHED_MIN, Map.SHED_MAX], [Map.HUT_MIN, Map.HUT_MAX],
		[Vector3(-50.5, 0, -91.0), Vector3(-45.5, 2.2, -88.0)]]
	for e in sites:
		var mn: Vector3 = e[0]
		var mx: Vector3 = e[1]
		var a0: Vector2i = px.call(mn.x - 2.2, mn.z - 2.2)
		var a1: Vector2i = px.call(mx.x + 2.2, mx.z + 2.2)
		img.fill_rect(Rect2i(a0, a1 - a0), Color(1, 0, 0, 1))
	for e in sites:
		var mn: Vector3 = e[0]
		var mx: Vector3 = e[1]
		var a0: Vector2i = px.call(mn.x - 0.9, mn.z - 0.9)
		var a1: Vector2i = px.call(mx.x + 0.9, mx.z + 0.9)
		img.fill_rect(Rect2i(a0, a1 - a0), Color(1, 1, 0, 1))
	# площадки у мест работы
	for c in [Map.METEO, Map.DEPOT, Map.PAD, Map.MAST, Map.WOODPILE + Vector3(0.6, 0, 0)]:
		var cc: Vector3 = c
		var r := 4.0 if cc == Map.WOODPILE + Vector3(0.6, 0, 0) else 7.0
		var a0: Vector2i = px.call(cc.x - r, cc.z - r)
		img.fill_rect(Rect2i(a0, Vector2i(int(r * 2.0 * k), int(r * 2.0 * k))), Color(0.7, 0, 0, 1))
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	RenderingServer.global_shader_parameter_set("g_snow_mask", tex)
	RenderingServer.global_shader_parameter_set("g_snow_rect", Vector4(org.x, org.y, 200.0, 200.0))


# ------------------------------------------------------------------ игрок

func spawn_player(place := "hub") -> Player:
	player = Player.new()
	player.name = "Player"
	player.world = self
	add_child(player)
	weather.cam = player.cam
	player.stepped.connect(_on_step)
	goto(place)
	return player


func goto(place: String) -> void:
	if not places.has(place):
		push_warning("нет места: " + place)
		return
	var p: Array = places[place]
	player.teleport(p[0], float(p[1]))


func _on_step(pos: Vector3, yaw: float, left: bool, _run: bool) -> void:
	if String(player.zone.get("surface", "snow")) == "snow":
		prints.add(pos, yaw, left, 0)


# ------------------------------------------------------------------ зоны

func add_zone(id: String, a: Vector3, b: Vector3, surface: String, shelter := 1.0, cold_air := 0.0) -> void:
	var mn := Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z))
	var mx := Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z))
	zones.append({"id": id, "box": AABB(mn, mx - mn), "surface": surface, "shelter": shelter, "cold_air": cold_air})


func zone_at(pos: Vector3) -> Dictionary:
	var p := pos + Vector3(0, 0.5, 0)
	for z in zones:
		if (z.box as AABB).has_point(p):
			return z
	return _outside


func is_indoors(pos: Vector3) -> bool:
	return float(zone_at(pos).get("shelter", 0.0)) > 0.5


## Скорость изменения тепла игрока, единиц в секунду (всего 100).
func heat_rate(p: Player) -> float:
	var z := p.zone
	var id := String(z.get("id", ""))
	var r := 0.0
	match id:
		"":
			r = -(0.42 + 0.42 * weather.gust + 0.3 * maxf(weather.base - 0.5, 0.0))
			r *= 1.0 - weather.clear * 0.8
		"house", "radio", "bunk", "store":
			if stove_t > 0.0:
				r = 4.2
			elif gen_on:
				r = 1.4
			else:
				r = -0.1
		"vest":
			r = 1.2 if stove_t > 0.0 else -0.16
		"shed":
			r = 2.4 if gen_on else -0.16
		"balok":
			r = 3.6 if balok_stove_t > 0.0 else -0.14
		"cellar":
			r = -0.24
		_:
			r = -0.15
	if p.flare_t > 0.0:
		r += 0.3
	# у горящей бочки тепло
	if fire_dist(p.global_position) < 4.5:
		r = maxf(r, 0.0) + 2.0
	return r


# ------------------------------------------------------------------ электричество

func reg_light(l: Light3D) -> void:
	power_lights.append([l, l.light_energy])


func reg_halo(h: MeshInstance3D) -> void:
	power_halos.append([h, float((h.material_override as ShaderMaterial).get_shader_parameter("power"))])


func reg_glow(m: StandardMaterial3D) -> void:
	power_glow.append([m, m.emission_energy_multiplier])


## Полные или упрощённые эффекты (настройка «Полные эффекты пурги»).
func _apply_fx() -> void:
	var q := 1.0 if Cfg.fx else 0.0
	if _ground_mat != null:
		_ground_mat.set_shader_parameter("quality", q)
		_relief_mat.set_shader_parameter("quality", q)
	for n in things.get("dust", []):
		(n as Node3D).visible = Cfg.fx
	var ml: OmniLight3D = things.get("main_lamp")
	if ml != null:
		ml.shadow_enabled = Cfg.fx


## Иней на окнах дома 0..1.
func set_frost(v: float) -> void:
	for m in window_mats:
		(m as ShaderMaterial).set_shader_parameter("frost", v)


func set_power(on: bool, instant := false) -> void:
	var was := gen_on
	gen_on = on
	if instant:
		_power_k = 1.0 if on else 0.0
		_apply_power(_power_k)
	if was != on:
		_flick_t = 0.0 if instant else 1.2
		power_changed.emit(on)


func _apply_power(k: float) -> void:
	for e in power_lights:
		var l: Light3D = e[0]
		if is_instance_valid(l):
			l.light_energy = float(e[1]) * k
			l.visible = k > 0.01
	for e in power_halos:
		var h: MeshInstance3D = e[0]
		if is_instance_valid(h):
			h.visible = k > 0.02
			(h.material_override as ShaderMaterial).set_shader_parameter("power", float(e[1]) * k)
	for e in power_glow:
		var m: StandardMaterial3D = e[0]
		m.emission_energy_multiplier = float(e[1]) * k


func _process(dt: float) -> void:
	# лоскут рельефа едет за камерой шагом сетки (иначе вершины «плывут»); в леднике его нет — там свой пол
	var cam_node: Node3D = weather.cam
	if cam_node != null and is_instance_valid(cam_node) and _relief != null:
		var cp := cam_node.global_position
		var c := Vector2(snappedf(cp.x, RELIEF_STEP), snappedf(cp.z, RELIEF_STEP))
		_relief.position = Vector3(c.x, 0.0, c.y)
		_relief_mat.set_shader_parameter("patch_c", c)
		# в закрытых помещениях (и в леднике) рельеф снаружи не нужен; в тамбуре дверь наружу — оставляем
		var inside := player != null and float(player.zone.get("shelter", 0.0)) >= 0.99
		_relief.visible = Cfg.fx and not inside
	if player != null:
		var sh := float(player.zone.get("shelter", 0.0))
		weather.indoor = move_toward(weather.indoor, sh, dt * 2.5)
		weather.lamp_on = player.lamp_shining()
		weather.fire_light = move_toward(weather.fire_light, 1.0 if player.flare_t > 0.0 else 0.0, dt * 2.0)
		Snd.set_indoor(sh)
	# печи прогорают
	stove_t = maxf(0.0, stove_t - dt)
	balok_stove_t = maxf(0.0, balok_stove_t - dt)
	_t += dt
	_fires(dt)
	# плавное включение и выключение света: лампы мигают, когда дизель глохнет или схватывает
	var tgt := 1.0 if gen_on else 0.0
	# дизель «садится»: свет на миг проседает (чем дальше ночь, тем чаще)
	if gen_on and is_equal_approx(_power_k, 1.0) and _flick_t <= 0.0:
		if _dip_t > 0.0:
			_dip_t -= dt
			_apply_power(0.62 + 0.2 * sin(_t * 41.0) if _dip_t > 0.0 else 1.0)
		elif dips > 0.0 and randf() < dt * dips / 60.0:
			_dip_t = randf_range(0.07, 0.22)
	if not is_equal_approx(_power_k, tgt) or _flick_t > 0.0:
		_flick_t = maxf(0.0, _flick_t - dt)
		_power_k = move_toward(_power_k, tgt, dt * 1.3)
		var k := _power_k
		if _flick_t > 0.0:
			k *= 0.35 + 0.65 * float(randf() > 0.4)
		_apply_power(k)


func _fire_light(key: String, on: bool, base: float) -> void:
	var l: OmniLight3D = things.get(key)
	if l == null:
		return
	l.visible = on
	if on:
		l.light_energy = base * (0.85 + 0.12 * sin(_t * 9.0) + 0.14 * randf())


func _loop_snd(key: String, on: bool, vol_db: float) -> void:
	var p: AudioStreamPlayer3D = things.get(key)
	if p == null or p.stream == null:
		return
	if on:
		p.volume_db = vol_db
		if not p.playing:
			p.play()
	elif p.playing:
		p.stop()


## Всё, что горит, крутится и мигает.
func _fires(dt: float) -> void:
	_fire_light("stove_light", stove_t > 0.0, 1.25)
	_loop_snd("stove_snd", stove_t > 0.0, -9.0)
	_fire_light("balok_stove_light", balok_stove_t > 0.0, 1.3)
	_loop_snd("balok_stove_snd", balok_stove_t > 0.0, -8.0)
	_fire_light("lantern_light", lantern_on, 1.0)
	_loop_snd("gen_snd", gen_on, -2.0)
	_loop_snd("clock_snd", true, -15.0)
	_loop_snd("anemo_snd", true, -8.0 + 6.0 * weather.gust)
	var rotor: Node3D = things.get("anemo_rotor")
	if rotor != null:
		rotor.rotate_y(dt * (5.0 + 16.0 * weather.intensity()))
	# красный маяк мачты: две секунды горит, две — нет
	var bh: MeshInstance3D = things.get("beacon_halo")
	if bh != null:
		var on := beacon_on and gen_on and fmod(_t, 4.0) < 2.0
		bh.visible = on
		var bm: StandardMaterial3D = things.get("beacon_mat")
		if bm != null:
			bm.emission_energy_multiplier = 4.0 if on else 0.0
	# сигнальные бочки
	var barrels: Array = things.get("barrels", [])
	for e in barrels:
		var bd: Dictionary = e
		var lit: bool = bd.lit
		var l: OmniLight3D = bd.light
		var h: MeshInstance3D = bd.halo
		var sp: AudioStreamPlayer3D = bd.snd
		l.visible = lit
		h.visible = lit
		if lit:
			l.light_energy = 3.2 * (0.8 + 0.15 * sin(_t * 8.0 + float(barrels.find(e))) + 0.15 * randf()) * (1.0 - 0.35 * weather.gust)
			if sp.stream != null and not sp.playing:
				sp.play()
		elif sp.playing:
			sp.stop()


func barrels_lit() -> int:
	var n := 0
	for e in things.get("barrels", []):
		if bool((e as Dictionary).lit):
			n += 1
	return n


## Ближайшая горящая бочка: расстояние от точки (огонь отгоняет существо).
func fire_dist(pos: Vector3) -> float:
	var best := 999.0
	for e in things.get("barrels", []):
		var bd: Dictionary = e
		if bool(bd.lit):
			best = minf(best, (bd.pos as Vector3).distance_to(pos))
	return best
