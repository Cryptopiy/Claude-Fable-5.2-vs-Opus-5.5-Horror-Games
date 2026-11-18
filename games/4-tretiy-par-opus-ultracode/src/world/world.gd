class_name World
extends Node3D
## Мир: строит баню, окружение, воду, пар, навигацию; создаёт игрока, Хозяйку, сценарий.
## Отвечает на вопросы «где я», «какой пол», «сколько воды», разносит шум.

signal noise_made(pos: Vector3, radius: float, kind: String)

static var nav_cache: NavigationMesh = null

var builder: Builder
var rooms := {}
var doors := {}
var env: Environment
var world_env: WorldEnvironment
var player: Player
var monster: Node = null
var director: Node = null
var scenario: Node = null
var nav: NavigationRegion3D
var waters := {}            # имя -> MeshInstance3D
var pool_level := -0.25
var drains: Array = []      # [{pos: Vector3, room: String}] — откуда она выходит
var taps: Array = []        # краны/души (узлы Tap)
var hides: Array = []       # шкафчики и полки
var dry_rects: Array = []   # [{rect: Rect2, y}] — сухие мостки в подвале
var steam := {}             # комната -> 0..1
var steam_vol := {}         # комната -> FogVolume
var steam_fx := {}          # комната -> GPUParticles3D
var fog_noise: NoiseTexture3D             # шум для шейдера пара/тумана (общий)
var noise_log: Array = []   # для отладки [{pos, r, t}]
var water_noise_tex: NoiseTexture2D
var water_mats: Array[ShaderMaterial] = []
var rings := PackedVector4Array()    # кольца на воде: x, z, время, радиус
var ring_i := 0
var drip_t := 1.0

## Тон отсвета воды по помещению: в котельной — янтарь топок, в бассейне — холод фонаря в потолке.
const WATER_SHEEN := {
	"boiler": Vector3(0.012, 0.007, 0.004), "meter": Vector3(0.005, 0.006, 0.007), "collector": Vector3(0.004, 0.005, 0.006),
	"pool": Vector3(0.005, 0.008, 0.01), "lobby_stairs": Vector3(0.012, 0.01, 0.008),
}
var moon: DirectionalLight3D
var sky_mat: ShaderMaterial
var amb_col := Color(0.32, 0.36, 0.45)   # фоновый свет зоны: плавно догоняет цель при смене помещения
var amb_e := 0.07
var amb_col_t := Color(0.32, 0.36, 0.45)
var amb_e_t := 0.07
var fog_v := 0.006                       # плотность объёмного тумана зоны (только среднее/высокое качество)
var fog_v_t := 0.006
var spawn_pos := Vector3(26, 0.05, 44)
var spawn_yaw := 0.0
var ready_done := false
var mist_done := false                    # стелющийся туман построен (его можно добавить, подняв качество в игре)
var time := 0.0


func _ready() -> void:
	Game.world = self
	build()


func build() -> void:
	var t0 := Time.get_ticks_msec()
	seed(1961)
	builder = Builder.new()
	builder.build(self)
	rooms = builder.rooms
	doors = builder.doors
	for id in rooms:
		(rooms[id]["node"] as Node3D).add_to_group("nav_src")
	var t1 := Time.get_ticks_msec()
	_environment()
	_waters()
	_ground_mist()
	Props.furnish(self)
	var t2 := Time.get_ticks_msec()
	_nav()
	var t3 := Time.get_ticks_msec()
	print("  здание %d мс, предметы %d мс, навигация %d мс" % [t1 - t0, t2 - t1, t3 - t2])
	scenario = Scenario.new()
	scenario.name = "Scenario"
	add_child(scenario)
	scenario.setup(self)
	_spawn_player()
	_spawn_monster()
	scenario.start()
	ready_done = true
	print("мир построен за %d мс" % (Time.get_ticks_msec() - t0))


# ---------------------------------------------------------------- окружение

## Фоновый свет по зонам: [цвет, энергия]. Тьма остаётся тьмой, но у неё есть форма и свой оттенок:
## вестибюль и служебные — жёлтый казённый, раздевальни и мыльни — зеленоватый кафель, бассейн — холодный
## свет фонаря в потолке, парилки и подвал — тёплый уголь и ржавчина, коллектор — холодная чернота.
const ZONES := {
	"outside": [Color(0.4, 0.5, 0.56), 0.1],
	"lobby": [Color(0.55, 0.47, 0.33), 0.13], "admin": [Color(0.55, 0.47, 0.33), 0.12],
	"office": [Color(0.55, 0.47, 0.33), 0.11], "linen": [Color(0.55, 0.47, 0.33), 0.11],
	"barber": [Color(0.5, 0.48, 0.4), 0.11], "buffet": [Color(0.55, 0.47, 0.33), 0.11],
	"m_wait": [Color(0.4, 0.46, 0.4), 0.12], "m_util": [Color(0.45, 0.43, 0.36), 0.1],
	"m_lock": [Color(0.4, 0.46, 0.4), 0.13], "f_lock": [Color(0.42, 0.44, 0.44), 0.13],
	"f_dry": [Color(0.42, 0.44, 0.44), 0.12], "f_attend": [Color(0.55, 0.45, 0.33), 0.12],
	"m_wash": [Color(0.32, 0.45, 0.42), 0.16], "f_wash": [Color(0.32, 0.45, 0.42), 0.16],
	"m_shower": [Color(0.32, 0.45, 0.42), 0.14], "f_shower": [Color(0.32, 0.45, 0.42), 0.14],
	"m_steam": [Color(0.55, 0.38, 0.25), 0.11], "f_steam": [Color(0.55, 0.38, 0.25), 0.11],
	"pool": [Color(0.33, 0.43, 0.55), 0.15, 0.012],
	"pump": [Color(0.4, 0.4, 0.42), 0.1], "stairwell": [Color(0.4, 0.4, 0.42), 0.1],
	"b_stairs": [Color(0.38, 0.38, 0.42), 0.09],
	"boiler": [Color(0.36, 0.38, 0.44), 0.1, 0.011], "coal": [Color(0.34, 0.36, 0.42), 0.09, 0.03],
	"meter": [Color(0.34, 0.38, 0.44), 0.09], "stoker": [Color(0.52, 0.4, 0.28), 0.1],
	"banya": [Color(0.42, 0.36, 0.32), 0.09, 0.012], "collector": [Color(0.24, 0.3, 0.38), 0.06, 0.01],
	"service": [Color(0.4, 0.4, 0.42), 0.1, 0.008],
}


func _environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.background_color = Color(0.008, 0.01, 0.016)
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = load("res://src/fx/sky.gdshader")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	env.sky = sky
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.36, 0.45)
	env.ambient_light_energy = 0.07
	# AgX: ядро огня уходит в жёлто-белое, а не в кислотный оранжевый клип; цвет — в посте (без двойной коррекции)
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	for i in 7:
		env.set_glow_level(i, [0.0, 0.0, 0.0, 1.0, 0.8, 0.5, 0.0][i])
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.055, 0.065)
	env.fog_density = 0.018
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.0
	env.adjustment_contrast = 1.0
	_apply_quality()
	world_env = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	moon = DirectionalLight3D.new()
	moon.light_color = Items.MOON
	moon.light_energy = 0.35
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 70.0
	moon.rotation = Vector3(deg_to_rad(-32), deg_to_rad(25), 0)
	moon.visible = false
	add_child(moon)
	Settings.changed.connect(_apply_quality)


func _apply_quality() -> void:
	if env == null:
		return
	var q := Settings.quality
	env.volumetric_fog_enabled = q >= 1
	env.volumetric_fog_density = fog_v
	env.volumetric_fog_albedo = Color(0.85, 0.85, 0.85)
	env.volumetric_fog_emission = Color(0, 0, 0)
	env.volumetric_fog_length = 28.0 if q >= 2 else 22.0
	env.volumetric_fog_detail_spread = 2.0
	env.volumetric_fog_gi_inject = 0.0
	env.volumetric_fog_ambient_inject = 0.05
	env.volumetric_fog_anisotropy = 0.45
	env.volumetric_fog_temporal_reprojection_enabled = true
	env.ssr_enabled = q >= 2
	env.ssr_max_steps = 48
	env.ssr_fade_in = 0.15
	env.ssr_fade_out = 2.0
	env.ssr_depth_tolerance = 0.3
	env.ssao_enabled = q >= 2
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	env.ssil_enabled = false
	env.sdfgi_enabled = false
	env.adjustment_brightness = Settings.brightness * (1.6 if Game.cheats.get("fullbright", false) else 1.0)
	_apply_ambient()
	RenderingServer.environment_set_volumetric_fog_volume_size(64 if q >= 2 else 48, 48 if q >= 2 else 32)
	var vp := get_viewport()
	if vp:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2 if q == 0 else Viewport.SCALING_3D_MODE_BILINEAR
		vp.scaling_3d_scale = 0.67 if q == 0 else (0.85 if q == 1 else 1.0)
		vp.msaa_3d = Viewport.MSAA_DISABLED
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if q >= 1 else Viewport.SCREEN_SPACE_AA_DISABLED
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW if q < 2 else RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
	RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW if q < 2 else RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
	# качество подняли из паузы — стелющийся туман над водой появляется сразу (при сборке его строит build)
	if ready_done and q >= 1:
		_ground_mist()


# ---------------------------------------------------------------- вода

func _apply_ambient() -> void:
	env.ambient_light_color = amb_col
	env.ambient_light_energy = amb_e * Settings.brightness * (12.0 if Game.cheats.get("fullbright", false) else 1.0)


## Цель фонового света для помещения; snap — сразу, без перехода (телепорт, загрузка).
func set_zone(room: String, snap := false) -> void:
	var z: Array = ZONES.get(room, [Color(0.32, 0.36, 0.45), 0.07])
	amb_col_t = z[0]
	amb_e_t = float(z[1])
	fog_v_t = float(z[2]) if z.size() > 2 else 0.006
	if snap:
		amb_col = amb_col_t
		amb_e = amb_e_t
		fog_v = fog_v_t
		env.volumetric_fog_density = fog_v
		_apply_ambient()


func _water_mat(murk: float, alpha := 0.55) -> ShaderMaterial:
	if water_noise_tex == null:
		water_noise_tex = NoiseTexture2D.new()
		water_noise_tex.seamless = true
		water_noise_tex.width = 256
		water_noise_tex.height = 256
		var fn := FastNoiseLite.new()
		fn.frequency = 0.02
		water_noise_tex.noise = fn
	var m := ShaderMaterial.new()
	m.shader = load("res://src/fx/water.gdshader")
	m.set_shader_parameter("murk", murk)
	m.set_shader_parameter("alpha_shallow", alpha)
	m.set_shader_parameter("noise_tex", water_noise_tex)
	if rings.is_empty():
		rings.resize(8)
	m.set_shader_parameter("rings", rings)
	_set_mirrors(m, [])
	water_mats.append(m)
	return m


## Излучатели, которые отражает эта вода: [[центр, полуось u, полуось v, цвет, яркость], …] (до 4).
func _set_mirrors(m: ShaderMaterial, list: Array) -> void:
	var c := PackedVector4Array()
	var u := PackedVector4Array()
	var v := PackedVector4Array()
	var col := PackedVector4Array()
	for i in 4:
		if i < list.size():
			var e: Array = list[i]
			var p: Vector3 = e[0]
			var a: Vector3 = e[1]
			var b: Vector3 = e[2]
			var k: Color = e[3]
			c.append(Vector4(p.x, p.y, p.z, float(e[4])))
			u.append(Vector4(a.x, a.y, a.z, float(e[5]) if e.size() > 5 else 0.0))
			v.append(Vector4(b.x, b.y, b.z, 0.0))
			col.append(Vector4(k.r, k.g, k.b, 1.0))
		else:
			c.append(Vector4.ZERO)
			u.append(Vector4(1, 0, 0, 0))
			v.append(Vector4(0, 0, 1, 0))
			col.append(Vector4.ZERO)
	m.set_shader_parameter("mir_c", c)
	m.set_shader_parameter("mir_u", u)
	m.set_shader_parameter("mir_v", v)
	m.set_shader_parameter("mir_col", col)


## Капли с потолка и труб в помещениях с водой: изредка кольцо в паре метров от игрока.
func _drips(delta: float) -> void:
	drip_t -= delta
	if drip_t > 0.0 or player == null:
		return
	drip_t = randf_range(0.6, 1.8)
	var room := player.current_room
	if not (rooms.has(room) and rooms[room]["def"].has("water")) and room != "pool":
		return
	var p := player.global_position + Vector3(randf_range(-5, 5), 0, randf_range(-5, 5))
	if water_depth(Vector3(p.x, player.global_position.y - 0.3, p.z), room_at(p + Vector3.UP * 0.5)) <= 0.0 and room != "pool":
		return
	ripple(p, 1.6)


## Кольцо на воде от звука в воде (шаг вброд, шайка, Хозяйка). radius — докуда кольцо доходит.
func ripple(pos: Vector3, radius := 4.0) -> void:
	if rings.is_empty():
		return
	rings[ring_i] = Vector4(pos.x, pos.z, time, radius)
	ring_i = (ring_i + 1) % rings.size()
	for m in water_mats:
		m.set_shader_parameter("rings", rings)


func _water_plane(name: String, rect: Rect2, y: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "water_" + name
	var pm := PlaneMesh.new()
	pm.size = rect.size
	mi.mesh = pm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = Vector3(rect.get_center().x, y, rect.get_center().y)
	waters[name] = mi
	return mi


func _waters() -> void:
	for id in rooms:
		var d: Dictionary = rooms[id]["def"]
		if d.has("water"):
			var r: Rect2 = rooms[id]["rect"]
			var wm := _water_mat(0.75, 0.8)
			wm.set_shader_parameter("sheen", WATER_SHEEN.get(id, Vector3(0.004, 0.005, 0.006)))
			if id == "boiler":
				# в чёрной воде котельной отражаются дверцы топок
				_set_mirrors(wm, [[Vector3(20, Layout.BASE_Y + 0.7, -11.43), Vector3(0.35, 0, 0), Vector3(0, 0.25, 0), Items.FIRE, 0.8],
					[Vector3(27, Layout.BASE_Y + 0.7, -11.43), Vector3(0.35, 0, 0), Vector3(0, 0.25, 0), Items.FIRE, 0.8]])
			# по всему прямоугольнику комнаты: края у стен и так под стеной (T = 0.12 внутрь), а в проёмах соседние
			# глади сходятся на линии порога (с отступом 0.1 поперёк проёма котельная↔коллектор была сухая полоса 20 см)
			_water_plane(id, r, float(d["y"]) + float(d["water"]) - water_drop(), wm)
	# вентиль закрыт — глади подвала опускаются вместе с глубиной (water_depth)
	if not Game.flag_changed.is_connected(_on_flag):
		Game.flag_changed.connect(_on_flag)
	pool_level = float(Game.getf("pool_level", -0.25))
	var pool_mat := _water_mat(1.0, 0.9)
	pool_mat.set_shader_parameter("sheen", WATER_SHEEN["pool"])
	# в бассейне отражается фонарь в потолке (по рамам его бьёт рябь)
	_set_mirrors(pool_mat, [[Vector3(26.0, 4.97, 11.5), Vector3(3.0, 0, 0), Vector3(0, 0, 1.5), Items.MOON, 0.55, 4.0]])
	_water_plane("pool", Layout.POOL_BASIN, pool_level, pool_mat)
	var stairs_mat := _water_mat(1.0, 0.95)
	stairs_mat.set_shader_parameter("sheen", WATER_SHEEN["lobby_stairs"])
	_water_plane("lobby_stairs", Layout.LOBBY_STAIRS, float(Game.getf("lobby_water", -0.9)), stairs_mat)
	# от тёплой чёрной воды на лестнице идёт пар
	_water_steam(Layout.LOBBY_STAIRS, float(Game.getf("lobby_water", -0.9)))


func _water_steam(rect: Rect2, y: float) -> void:
	var pr := GPUParticles3D.new()
	pr.amount = 14 if Settings.quality >= 1 else 6
	pr.lifetime = 6.0
	pr.preprocess = 5.0
	pr.visibility_aabb = AABB(Vector3(-rect.size.x, -0.5, -rect.size.y), Vector3(rect.size.x * 2, 4, rect.size.y * 2))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(rect.size.x * 0.4, 0.05, rect.size.y * 0.4)
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 20.0
	pm.initial_velocity_min = 0.12
	pm.initial_velocity_max = 0.3
	pm.gravity = Vector3(0, 0.02, 0)
	pm.scale_min = 1.2
	pm.scale_max = 2.2
	var ac := Curve.new()
	ac.add_point(Vector2(0, 0))
	ac.add_point(Vector2(0.3, 1))
	ac.add_point(Vector2(1, 0))
	var act := CurveTexture.new()
	act.curve = ac
	pm.alpha_curve = act
	pr.process_material = pm
	var qm := QuadMesh.new()
	qm.size = Vector2(1.2, 1.2)
	var sm := StandardMaterial3D.new()
	sm.albedo_texture = Mat.tex("res://tex/ui/steam_puff.png")
	sm.albedo_color = Color(0.8, 0.8, 0.8, 0.16)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.vertex_color_use_as_albedo = true
	sm.proximity_fade_enabled = true
	sm.proximity_fade_distance = 0.6
	qm.material = sm
	pr.draw_pass_1 = qm
	pr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pr)
	pr.global_position = Vector3(rect.get_center().x, y + 0.1, rect.get_center().y)


## На сколько вода в подвале ниже после закрытия вентиля.
func water_drop() -> float:
	return 0.06 if Game.flag("valve_closed") else 0.0


func _on_flag(flag: String, _value: Variant) -> void:
	if flag != "valve_closed" or not is_inside_tree():
		return
	for id in rooms:
		var d: Dictionary = rooms[id]["def"]
		if d.has("water") and waters.has(id):
			var mi: MeshInstance3D = waters[id]
			var to := float(d["y"]) + float(d["water"]) - water_drop()
			create_tween().tween_property(mi, "global_position:y", to, 3.0)


func set_pool_level(y: float) -> void:
	pool_level = y
	(waters["pool"] as MeshInstance3D).global_position.y = y
	(waters["pool"] as MeshInstance3D).visible = y > Layout.POOL_DEEP + 0.02


# ---------------------------------------------------------------- навигация

func _nav() -> void:
	nav = NavigationRegion3D.new()
	nav.name = "Nav"
	add_child(nav)
	var map := get_world_3d().navigation_map
	NavigationServer3D.map_set_cell_size(map, 0.1)
	NavigationServer3D.map_set_cell_height(map, 0.05)
	if nav_cache:
		nav.navigation_mesh = nav_cache
		return
	var nm := NavigationMesh.new()
	nm.cell_size = 0.1
	nm.cell_height = 0.05
	nm.agent_radius = 0.2
	nm.agent_height = 1.5
	nm.agent_max_climb = 0.35
	nm.agent_max_slope = 48.0
	nm.region_min_size = 4.0
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	nm.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nm.geometry_source_group_name = "nav_src"
	nm.filter_baking_aabb = AABB(Vector3(-1, -5, -19), Vector3(54, 11, 50))
	nav.navigation_mesh = nm
	nav.bake_navigation_mesh(false)
	nav_cache = nav.navigation_mesh
	print("  навмеш: полигонов ", nav_cache.get_polygon_count(), ", вершин ", nav_cache.get_vertices().size())


# ---------------------------------------------------------------- игрок и Хозяйка

func _spawn_player() -> void:
	player = Player.new()
	player.name = "Player"
	player.position = spawn_pos
	add_child(player)
	player.global_position = spawn_pos
	player.set_look(spawn_yaw)
	Game.player = player


func _spawn_monster() -> void:
	monster = Hozyayka.new()
	monster.name = "Hozyayka"
	add_child(monster)
	Game.monster = monster
	director = Director.new()
	director.name = "Director"
	add_child(director)
	director.setup(self)


# ---------------------------------------------------------------- запросы

func room_at(p: Vector3) -> String:
	for id in rooms:
		var r: Rect2 = rooms[id]["rect"]
		var y: float = rooms[id]["y"]
		var h: float = rooms[id]["h"]
		if p.x >= r.position.x and p.x <= r.end.x and p.z >= r.position.y and p.z <= r.end.y and p.y >= y - 2.6 and p.y <= y + h:
			# полоса проёма решётки над площадкой (z -0.1..0) — это коридор, а не «двор»
			if id == "b_stairs" and p.y > 0.2 and p.z > -0.1:
				return "service"
			return id
	return "outside"


func room_name(id: String) -> String:
	if rooms.has(id):
		return String(rooms[id]["def"]["name"])
	return "Двор"


func surface_at(p: Vector3, room := "") -> String:
	if room == "":
		room = room_at(p)
	if room == "outside":
		if p.x > 23.9 and p.x < 28.1 and p.z > 30.3 and p.z < 32.5:
			return "concrete"
		return "snow"
	var d: Dictionary = rooms[room]["def"]
	if room == "pool" and Layout.POOL_BASIN.has_point(Vector2(p.x, p.z)):
		return "tile"
	for dr in dry_rects:
		if (dr["rect"] as Rect2).has_point(Vector2(p.x, p.z)) and p.y >= float(dr["y"]) - 0.05:
			return "wood"
	var f: String = d["floor"]
	if f.begins_with("tile") or f == "terracotta":
		return "tile"
	if f.begins_with("planks") or f == "logs":
		return "wood"
	if f == "linoleum":
		return "lino"
	if f == "coal":
		return "coal"
	if f == "snow":
		return "snow"
	return "concrete"


func is_wet(p: Vector3, room := "") -> bool:
	if room == "":
		room = room_at(p)
	if not rooms.has(room):
		return false
	var d: Dictionary = rooms[room]["def"]
	if room == "lobby" and Game.flag("lobby_flooded"):
		return true
	if d.has("water"):
		return water_depth(p, room) > 0.0
	return bool(d.get("wet", false))


func water_depth(p: Vector3, room := "") -> float:
	if room == "":
		room = room_at(p)
	if room == "pool" and Layout.POOL_BASIN.has_point(Vector2(p.x, p.z)):
		return maxf(0.0, pool_level - p.y)
	for dr in dry_rects:
		if (dr["rect"] as Rect2).has_point(Vector2(p.x, p.z)) and p.y >= float(dr["y"]) - 0.05:
			return 0.0
	if rooms.has(room):
		var d: Dictionary = rooms[room]["def"]
		if d.has("water"):
			var lvl := float(d["y"]) + float(d["water"]) - water_drop()
			return maxf(0.0, lvl - p.y)
	if room == "lobby" and Game.flag("lobby_flooded"):
		return 0.04
	return 0.0


func is_safe(p: Vector3) -> bool:
	var room := room_at(p)
	if not rooms.has(room):
		return false
	if not rooms[room]["def"].get("safe", false):
		return false
	if Game.flag("salt_gone_" + room):
		return false
	return true


func room_rect(id: String) -> Rect2:
	return rooms[id]["rect"]


func room_center(id: String) -> Vector3:
	var r: Rect2 = rooms[id]["rect"]
	return Vector3(r.get_center().x, float(rooms[id]["y"]) + 0.05, r.get_center().y)


# ---------------------------------------------------------------- шум

## Любой звук, который может услышать Хозяйка.
func noise(pos: Vector3, radius: float, kind := "", in_water := false) -> void:
	if Game.cheats.get("deaf", false):
		return
	noise_log.append({"pos": pos, "r": radius, "t": time})
	if noise_log.size() > 30:
		noise_log.pop_front()
	noise_made.emit(pos, radius, kind)
	if monster and monster.has_method("hear"):
		monster.hear(pos, radius, kind, in_water)
	if director:
		director.on_noise(pos, radius, kind)


# ---------------------------------------------------------------- пар

func add_steam(room: String, amount: float) -> void:
	steam[room] = clampf(float(steam.get(room, 0.0)) + amount, 0.0, 1.0)


func steam_at(room: String) -> float:
	return float(steam.get(room, 0.0))


func _make_steam(room: String) -> void:
	if steam_vol.has(room) or not rooms.has(room):
		return
	var r: Rect2 = rooms[room]["rect"]
	var y: float = rooms[room]["y"]
	var h: float = rooms[room]["h"]
	var fv := FogVolume.new()
	fv.size = Vector3(r.size.x - 0.2, h, r.size.y - 0.2)
	fv.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	fv.material = _fog_mat(1.0, Color(0.9, 0.9, 0.88))
	add_child(fv)
	fv.global_position = Vector3(r.get_center().x, y + h * 0.5, r.get_center().y)
	steam_vol[room] = fv
	var pr := GPUParticles3D.new()
	pr.amount = 70
	pr.lifetime = 7.0
	pr.preprocess = 4.0
	pr.visibility_aabb = AABB(Vector3(-r.size.x * 0.5, -1, -r.size.y * 0.5), Vector3(r.size.x, h + 2, r.size.y))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(r.size.x * 0.45, 0.5, r.size.y * 0.45)
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 60.0
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.25
	pm.gravity = Vector3(0, 0.03, 0)
	pm.scale_min = 2.0
	pm.scale_max = 4.0
	var curve := CurveTexture.new()
	var c := Curve.new()
	c.add_point(Vector2(0, 0))
	c.add_point(Vector2(0.3, 1))
	c.add_point(Vector2(1, 0))
	curve.curve = c
	pm.alpha_curve = curve
	pr.process_material = pm
	var qm := QuadMesh.new()
	qm.size = Vector2(1.6, 1.6)
	var sm := StandardMaterial3D.new()
	sm.albedo_texture = Mat.tex("res://tex/ui/steam_puff.png")
	sm.albedo_color = Color(0.85, 0.85, 0.85, 0.0)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.vertex_color_use_as_albedo = true
	sm.proximity_fade_enabled = true
	sm.proximity_fade_distance = 1.0
	sm.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	sm.distance_fade_min_distance = 0.2
	sm.distance_fade_max_distance = 1.4
	qm.material = sm
	pr.draw_pass_1 = qm
	add_child(pr)
	pr.global_position = Vector3(r.get_center().x, y + 0.6, r.get_center().y)
	pr.emitting = false
	steam_fx[room] = pr


## Материал пара/тумана: layer > 0 — копится под потолком, < 0 — стелется по полу.
func _fog_mat(layer: float, albedo: Color) -> ShaderMaterial:
	if fog_noise == null:
		fog_noise = NoiseTexture3D.new()
		var sz := 64 if Settings.quality >= 2 else 32
		fog_noise.width = sz
		fog_noise.height = sz
		fog_noise.depth = sz
		fog_noise.seamless = true
		var fn := FastNoiseLite.new()
		fn.frequency = 0.08
		fog_noise.noise = fn
	var m := ShaderMaterial.new()
	m.shader = load("res://src/fx/steam_fog.gdshader")
	m.set_shader_parameter("density", 0.0)
	m.set_shader_parameter("layer", layer)
	m.set_shader_parameter("albedo", albedo)
	m.set_shader_parameter("noise3d", fog_noise)
	return m


## Стелющийся туман над чёрной водой и мокрым полом (только где есть объёмный туман).
func _ground_mist() -> void:
	if Settings.quality < 1 or mist_done:
		return
	mist_done = true
	for id in ["boiler", "collector", "meter", "pool", "m_wash", "f_wash"]:
		if not rooms.has(id):
			continue
		var r: Rect2 = rooms[id]["rect"]
		var y: float = rooms[id]["y"]
		var fv := FogVolume.new()
		fv.size = Vector3(r.size.x - 0.2, 0.9, r.size.y - 0.2)
		fv.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
		var m := _fog_mat(-0.7, Color(0.78, 0.82, 0.82))
		m.set_shader_parameter("density", 0.05 if id in ["boiler", "collector", "meter"] else 0.03)
		fv.material = m
		add_child(fv)
		fv.global_position = Vector3(r.get_center().x, y + 0.4, r.get_center().y)
		if id == "pool":
			# над полным бассейном (-0.25) и полом зала; за сливом не идёт — и после загрузки слитого так же
			fv.global_position.y = -0.25 + 0.4


func _update_steam(delta: float) -> void:
	for room in steam.keys():
		var v: float = steam[room]
		if Game.cheats.get("steam_off", false):
			v = 0.0
		if v > 0.01 and not steam_vol.has(room):
			_make_steam(room)
		if steam_vol.has(room):
			var fv: FogVolume = steam_vol[room]
			(fv.material as ShaderMaterial).set_shader_parameter("density", v * 0.14)
			var pr: GPUParticles3D = steam_fx[room]
			pr.emitting = v > 0.08
			var sm := (pr.draw_pass_1 as QuadMesh).material as StandardMaterial3D
			sm.albedo_color.a = clampf(v * 0.3, 0.0, 0.3)
		# пар оседает, если его не подпитывают
		steam[room] = maxf(0.0, v - delta * 0.012)


# ---------------------------------------------------------------- кадр

func _process(delta: float) -> void:
	time += delta
	_update_steam(delta)
	for m in water_mats:
		m.set_shader_parameter("ring_now", time)
	_drips(delta)
	if not amb_col.is_equal_approx(amb_col_t) or absf(amb_e - amb_e_t) > 0.0005:
		var k := clampf(delta * 2.5, 0.0, 1.0)
		amb_col = amb_col.lerp(amb_col_t, k)
		amb_e = lerpf(amb_e, amb_e_t, k)
		_apply_ambient()
	if absf(fog_v - fog_v_t) > 0.0001:
		fog_v = lerpf(fog_v, fog_v_t, clampf(delta * 1.5, 0.0, 1.0))
		env.volumetric_fog_density = fog_v
	if player:
		_player_fog()


## Туман гуще, когда игрок в пару (на низком качестве объёмного тумана нет).
func _player_fog() -> void:
	var s := steam_at(player.current_room)
	env.fog_density = lerpf(env.fog_density, 0.018 + s * 0.07, 0.05)
	env.fog_light_color = Color(0.05, 0.055, 0.065).lerp(Color(0.12, 0.115, 0.11), s)


func player_room_changed(room: String) -> void:
	if moon:
		moon.visible = room == "outside"
	if builder and builder.ext_details:
		builder.ext_details.visible = room == "outside" or room == "lobby"
	set_zone(room, not ready_done or (Game.main != null and bool(Game.main.get("prewarming"))))
	# реверб — и во время прогрева: смену на комнату спавна ловят именно тогда, после неё вызова уже не будет
	if rooms.has(room):
		var rv: Array = rooms[room]["def"].get("reverb", [0.5, 0.2])
		Snd.set_room(float(rv[0]), float(rv[1]))
	else:
		Snd.set_room(0.1, 0.02)
	if Game.main and Game.main.get("prewarming"):
		return
	if scenario and scenario.has_method("on_room"):
		scenario.on_room(room)


func free_world() -> void:
	Game.world = null
	Game.player = null
	Game.monster = null
	queue_free()
