extends Node3D
## Метель: экранные слои (часть snow.gd) (договор тот же, что у snow.gd):
## setup(w) — построить; set_hide_boxes(mn, mx, n) — коробки помещений (снег внутри не рисуется);
## tick(w, cam_pos, dt) — каждый кадр: плотность и скорость от силы пурги, порыва, помещения, админки, Cfg.fx.
##
## Основной снег рисует один квад во весь кадр (shaders/snow_screen.gdshader): хлопья в трёх решётках мира
## по полосам глубины — ближние диски расфокуса, средние мягкие штрихи, дальняя пыль; завесы и позёмка — шумом.
## Он закрыт глубиной сцены и освещён настоящими лампами игрока, посчитанными так же, как их считает движок:
## налобный фонарь (конус, пятно, затухание; энергию и направление берём у самой лампы — снег мигает вместе с ней),
## подсветка у лица и фальшфейер в руке.
## Огни построек (окна, лампы, бочки, маяк) так не посчитать — у них светятся настоящие частицы
## (shaders/snow_screen_lit.gdshader), которые свет ламп у камеры пропускают.

const WIND_DIR := Vector3(0.7071, 0.0, 0.7071)
const CELLS := Vector3(0.4, 0.45, 0.7)   # ячейки решёток хлопьев, м: ближняя, средняя, дальняя
const LATTICE := 256.0                    # узор решётки повторяется через 256 ячеек — по нему оборачиваем снос
const VEIL_WRAP := 25.0                   # период шума завес вдоль ветра, м
const DRIFT_WRAP := 100.0                 # период шума позёмки вдоль ветра, м
const LAMP_E := 13.0                      # полная энергия налобного фонаря (player.gd LAMP_E)
const LIT_LIFE := 1.3
const LIT_V := 9.0                        # средняя начальная скорость частиц, м/с (speed_scale подгоняет под ветер)

var screen: MeshInstance3D
var lit: GPUParticles3D
var _smat: ShaderMaterial
var _lmat: ShaderMaterial
# повороты решёток мир → решётка — те же, что ROT_N/M/F в шейдере (столбцы mat3 = оси Basis)
var _rot: Array[Basis] = [
	Basis(Vector3(0.95534, 0.14168, 0.25934), Vector3(0.0, 0.87758, -0.47943), Vector3(-0.29552, 0.45801, 0.83839)),
	Basis(Vector3(0.16997, 0.77193, 0.61257), Vector3(0.0, 0.62161, -0.78333), Vector3(-0.98545, 0.13314, 0.10565)),
	Basis(Vector3(-0.58850, 0.77903, 0.21627), Vector3(0.0, 0.26750, -0.96356), Vector3(-0.80850, -0.56706, -0.15742)),
]
# снос снега ветром, м — в осях каждой решётки: обёртка на 256 ячеек по её же осям узор не меняет
# (обёртка в осях мира сдвигала бы повёрнутую решётку на дробное число ячеек — все хлопья разом прыгали бы)
var _offs: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
var _veil_u := 0.0
var _drift_u := 0.0
var _band := Vector2.ZERO       # фазы волн порыва: копим здесь, а не TIME · скорость в шейдере (иначе при смене силы
                                # порыва фаза скачет на TIME · Δ и хлопья мерцают каждый кадр)
var _cam_prev := Vector3.ZERO
var _cam_vel := Vector3.ZERO
var _has_prev := false
var _own_id := 0
var _cam_id := 0
var _prio := 0


func setup(_w: Node3D) -> void:
	_build_screen()
	_build_lit()


func set_hide_boxes(mn: PackedVector3Array, mx: PackedVector3Array, n: int) -> void:
	for sm in [_smat, _lmat]:
		var m: ShaderMaterial = sm
		m.set_shader_parameter("box_n", n)
		m.set_shader_parameter("box_min", mn)
		m.set_shader_parameter("box_max", mx)


func tick(w: Node3D, cp: Vector3, dt: float) -> void:
	dt = clampf(dt, 0.0, 0.1)
	var I: float = w.intensity()
	var gust: float = w.gust
	var clear: float = w.clear
	var indoor: float = w.indoor
	var storm := clampf(I, 0.0, 1.0)
	# в помещении снег за окнами и дверью всё равно идёт (внутри построек его прячет шейдер)
	var out_s := maxf(1.0 - indoor, 0.5)
	var dens := clampf(lerpf(0.25, 1.0, I), 0.0, 1.0) * out_s * (1.0 - clear * 0.92)
	# ветер: с северо-запада на юго-восток, сильнее в порыв; снег при этом медленно оседает
	var wind := (3.5 + 8.5 * clampf(I, 0.0, 1.3)) * (1.0 - 0.6 * clear)
	var vel := WIND_DIR * wind + Vector3(0.0, -1.1, 0.0)
	for i in 3:
		var per: float = LATTICE * CELLS[i]
		var o: Vector3 = _offs[i] + (_rot[i] * vel) * dt
		_offs[i] = Vector3(fposmod(o.x, per), fposmod(o.y, per), fposmod(o.z, per))
	_veil_u = fposmod(_veil_u + wind * dt, VEIL_WRAP)
	_drift_u = fposmod(_drift_u + wind * 1.15 * dt, DRIFT_WRAP)
	_band = Vector2(fposmod(_band.x + (6.0 + 5.0 * gust) * dt, TAU), fposmod(_band.y + 0.27 * dt, TAU))
	# скорость камеры — для смаза; телепорт и рывок движением не считаем
	if _has_prev and dt > 0.0001:
		var dv := (cp - _cam_prev) / dt
		if dv.length() > 12.0:
			dv = Vector3.ZERO
		_cam_vel = _cam_vel.lerp(dv, clampf(dt * 8.0, 0.0, 1.0))
	_cam_prev = cp
	_has_prev = true

	# лампы игрока: налобный фонарь (мигание, холод, существо), подсветка у лица, фальшфейер — берём у них самих
	var cam: Node3D = w.cam
	var own := _get_owner(cam)
	var lamp: SpotLight3D = null
	var fill: OmniLight3D = null
	var flare: OmniLight3D = null
	if own != null:
		lamp = own.get("lamp") as SpotLight3D
		fill = own.get("fill") as OmniLight3D
		flare = own.get("flare_light") as OmniLight3D
	var sm := _smat
	var le := 0.0
	var ldir := Vector3.FORWARD
	if lamp != null:
		if lamp.is_visible_in_tree():
			le = lamp.light_energy
		ldir = -lamp.global_transform.basis.z
		var lc := lamp.light_color.srgb_to_linear()
		sm.set_shader_parameter("lamp_col", Vector3(lc.r, lc.g, lc.b))
		sm.set_shader_parameter("lamp_att", Vector2(1.0 / maxf(lamp.spot_range, 0.1), lamp.spot_attenuation))
	elif cam != null:
		ldir = -cam.global_transform.basis.z
		if bool(w.lamp_on):
			le = LAMP_E
	var fe := 0.0
	if fill != null and fill.is_visible_in_tree():
		fe = fill.light_energy
		sm.set_shader_parameter("fill_att", Vector2(1.0 / maxf(fill.omni_range, 0.1), fill.omni_attenuation))
	var xe := 0.0
	if flare != null and flare.is_visible_in_tree():
		xe = flare.light_energy
		var xc := flare.light_color.srgb_to_linear()
		sm.set_shader_parameter("flare_pos", flare.global_position)
		sm.set_shader_parameter("flare_col", Vector3(xc.r, xc.g, xc.b))
		sm.set_shader_parameter("flare_att", Vector2(1.0 / maxf(flare.omni_range, 0.1), flare.omni_attenuation))

	var env: Environment = w.env
	var fog_b := 1.0
	var fog_e := 14.0
	var fog_c := 0.75
	var amb := Color(0.009, 0.016, 0.035)
	if env != null:
		fog_b = env.fog_depth_begin
		fog_e = maxf(env.fog_depth_end, fog_b + 0.5)
		fog_c = env.fog_depth_curve
		# цвет окружения движок тоже переводит в линейный
		amb = env.ambient_light_color.srgb_to_linear() * env.ambient_light_energy

	var fx := Cfg.fx
	sm.set_shader_parameter("lamp_dir", ldir)
	sm.set_shader_parameter("lamp_e", le)
	sm.set_shader_parameter("fill_e", fe)
	sm.set_shader_parameter("flare_e", xe)
	sm.set_shader_parameter("amb_col", Vector3(amb.r, amb.g, amb.b))
	sm.set_shader_parameter("wind_vel", vel)
	sm.set_shader_parameter("cam_vel", _cam_vel)
	sm.set_shader_parameter("wind_speed", wind)
	sm.set_shader_parameter("off_n", _offs[0])
	sm.set_shader_parameter("off_m", _offs[1])
	sm.set_shader_parameter("off_f", _offs[2])
	sm.set_shader_parameter("band_ph", _band)
	sm.set_shader_parameter("dens", dens)
	sm.set_shader_parameter("fx", 1.0 if fx else 0.0)
	sm.set_shader_parameter("fog_begin", fog_b)
	sm.set_shader_parameter("fog_end", fog_e)
	sm.set_shader_parameter("fog_curve", fog_c)
	sm.set_shader_parameter("veil_u", _veil_u)
	sm.set_shader_parameter("drift_u", _drift_u)
	# завесы гуще в сильную пургу и в порыв; позёмка метёт сильнее с ветром
	sm.set_shader_parameter("veil_k", 0.02 * out_s * (1.0 - clear))
	sm.set_shader_parameter("drift_k", 0.15 * (0.2 + 0.8 * storm + 0.6 * gust) * out_s * (1.0 - clear * 0.8))
	sm.set_shader_parameter("storm", storm)
	# внутри — снег за окном рисуем раньше стекла (иней его приглушает), снаружи — поверх стёкол
	var prio := -1 if indoor > 0.5 else 1
	if prio != _prio:
		_prio = prio
		sm.render_priority = prio
	screen.global_position = cp
	screen.visible = dens > 0.005 or le > 0.001

	# частицы у огней построек
	lit.global_position = cp - WIND_DIR * (LIT_V * LIT_LIFE * 0.5) + Vector3(0.0, 0.6, 0.0)
	lit.speed_scale = clampf(wind / LIT_V, 0.4, 2.0)
	lit.amount_ratio = clampf(dens * (1.0 if fx else 0.5), 0.0, 1.0)
	lit.emitting = lit.amount_ratio > 0.01
	_lmat.set_shader_parameter("fog_begin", fog_b)
	_lmat.set_shader_parameter("fog_end", fog_e)
	_lmat.set_shader_parameter("fog_curve", fog_c)


## Владелец камеры с лампами (player.gd: lamp, fill, flare_light); у камеры меню его нет — тогда null.
## Храним номер объекта, а не ссылку: игрок между этапами пересоздаётся.
func _get_owner(cam: Node) -> Node:
	var cid := cam.get_instance_id() if cam != null else 0
	if cid != _cam_id or (_own_id != 0 and not is_instance_id_valid(_own_id)):
		_cam_id = cid
		_own_id = 0
		var n: Node = cam
		for i in 6:
			if n == null:
				break
			if "lamp" in n and n.get("lamp") is SpotLight3D:
				_own_id = n.get_instance_id()
				break
			n = n.get_parent()
	if _own_id == 0 or not is_instance_id_valid(_own_id):
		return null
	return instance_from_id(_own_id) as Node


func _build_screen() -> void:
	_smat = ShaderMaterial.new()
	_smat.shader = load("res://src/shaders/snow_screen.gdshader")
	_smat.set_shader_parameter("cells", CELLS)
	_smat.render_priority = 1
	_prio = 1
	var qm := QuadMesh.new()
	qm.size = Vector2(2.0, 2.0)
	screen = MeshInstance3D.new()
	screen.name = "SnowScreen"
	screen.mesh = qm
	screen.material_override = _smat
	screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	screen.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	# квад рисуется у ближней плоскости во весь кадр — отсекать его по рамке нельзя
	screen.custom_aabb = AABB(Vector3(-5000.0, -5000.0, -5000.0), Vector3(10000.0, 10000.0, 10000.0))
	add_child(screen)


func _build_lit() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0))
	grad.add_point(0.12, Color(1, 1, 1, 1))
	grad.add_point(0.82, Color(1, 1, 1, 1))
	grad.set_color(grad.get_point_count() - 1, Color(1, 1, 1, 0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	_lmat = ShaderMaterial.new()
	_lmat.shader = load("res://src/shaders/snow_screen_lit.gdshader")
	lit = GPUParticles3D.new()
	lit.name = "SnowLit"
	# 4000 в коробке 18 × 6,4 × 18 м — около двух хлопьев на кубометр у фонарей построек
	lit.amount = 4000
	lit.lifetime = LIT_LIFE
	lit.preprocess = LIT_LIFE
	lit.local_coords = false
	lit.fixed_fps = 0
	lit.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	lit.visibility_aabb = AABB(Vector3(-30, -10, -30), Vector3(60, 20, 60))
	lit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(9.0, 3.2, 9.0)
	pm.direction = Vector3(WIND_DIR.x, -0.12, WIND_DIR.z).normalized()
	pm.spread = 8.0
	pm.initial_velocity_min = LIT_V - 2.0
	pm.initial_velocity_max = LIT_V + 2.0
	pm.gravity = Vector3(0, -0.8, 0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.2
	pm.turbulence_noise_scale = 2.4
	pm.turbulence_influence_min = 0.05
	pm.turbulence_influence_max = 0.2
	pm.scale_min = 0.6
	pm.scale_max = 1.5
	pm.color_ramp = ramp
	lit.process_material = pm
	var qm := QuadMesh.new()
	qm.size = Vector2(0.02, 0.048)
	qm.material = _lmat
	lit.draw_pass_1 = qm
	add_child(lit)
