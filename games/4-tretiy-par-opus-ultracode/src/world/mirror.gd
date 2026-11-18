class_name Mirror
extends Node3D
## Настоящее зеркало: вторая камера с косой пирамидой видимости рисует отражение.
## Видит слой 20 — там может стоять то, чего в комнате нет. Запотевает в пару; надписи пальцем
## на стекле видны только на запотевшем зеркале.

const GHOST_LAYER := 1 << 19
## слой «видимости» зеркала: его видит камера игрока, но не своя камера отражения — иначе она сама держала
## notifier «на экране» и отражение рисовалось каждый кадр, куда бы игрок ни смотрел
const NOTIFY_LAYER := 1 << 18
## что меняется в окружении мира на ходу (зоны, пар, настройки) — переносится в окружение зеркала.
## Объёмный туман — отдельно (_vol_fog): сетка вокселей тумана общая и не уменьшается под 384-пиксельное отражение,
## это второй полный проход тумана на кадр — только на высоком качестве; обычный туман (fog_density) есть всегда.
const ENV_SYNC := ["ambient_light_color", "ambient_light_energy", "fog_density", "fog_light_color",
	"volumetric_fog_density", "background_color"]

var size := Vector2(0.8, 1.0)
var room := ""
var writing: Texture2D = null
var vp: SubViewport
var cam: Camera3D
var mi: MeshInstance3D
var mat: ShaderMaterial
var fog := 0.0
var force_fog := -1.0
var notifier: VisibleOnScreenNotifier3D
var on_screen := false
var env: Environment       # своё окружение камеры отражения (копия мирового, см. _make_env)


static func make(parent: Node3D, pos: Vector3, yaw: float, sz: Vector2, room_id: String, write_tex := "") -> Mirror:
	var m := Mirror.new()
	m.size = sz
	m.room = room_id
	if write_tex != "":
		m.writing = load(write_tex)
	parent.add_child(m)
	m.global_position = pos
	m.rotation.y = yaw
	return m


func _ready() -> void:
	vp = SubViewport.new()
	vp.size = Vector2i(int(384 * size.x / size.y), 384)
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.world_3d = get_viewport().world_3d
	add_child(vp)
	cam = Camera3D.new()
	cam.cull_mask = 0xFFFFF & ~NOTIFY_LAYER
	cam.projection = Camera3D.PROJECTION_FRUSTUM
	vp.add_child(cam)
	_make_env()
	mi = MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = size
	mi.mesh = qm
	mat = ShaderMaterial.new()
	mat.shader = load("res://src/fx/mirror.gdshader")
	mat.set_shader_parameter("refl", vp.get_texture())
	mat.set_shader_parameter("msize", size)
	if writing:
		mat.set_shader_parameter("writing", writing)
		mat.set_shader_parameter("has_writing", true)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	# рамка
	var fr := Mat.flat(Color(0.25, 0.22, 0.18), 0.6, 0.3)
	var b := Geo.Batch.new()
	b.box(fr, Vector3(0, size.y * 0.5 + 0.02, -0.01), Vector3(size.x + 0.06, 0.04, 0.03))
	b.box(fr, Vector3(0, -size.y * 0.5 - 0.02, -0.01), Vector3(size.x + 0.06, 0.04, 0.03))
	b.box(fr, Vector3(-size.x * 0.5 - 0.02, 0, -0.01), Vector3(0.04, size.y, 0.03))
	b.box(fr, Vector3(size.x * 0.5 + 0.02, 0, -0.01), Vector3(0.04, size.y, 0.03))
	b.commit(self, "frame")
	notifier = VisibleOnScreenNotifier3D.new()
	notifier.aabb = AABB(Vector3(-size.x * 0.5, -size.y * 0.5, -0.05), Vector3(size.x, size.y, 0.1))
	notifier.layers = NOTIFY_LAYER
	add_child(notifier)
	notifier.screen_entered.connect(func(): on_screen = true)
	notifier.screen_exited.connect(func(): on_screen = false)


## Своё окружение камеры зеркала. Отражение уходит в EMISSION и в основном кадре проходит тонмаппинг AgX, свечение
## и «Яркость» — здесь их не применять (линейно, без свечения и поправок), иначе всё это ложится дважды:
## отражение плоское, серое, тусклее комнаты. SSR и SSAO в 384-пиксельном отражении не видны — выключены
## (меньше работы видеокарте).
func _make_env() -> void:
	var w: World = Game.world
	if w == null or w.env == null:
		return
	env = w.env.duplicate() as Environment
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	env.glow_enabled = false
	env.adjustment_enabled = false
	env.ssr_enabled = false
	env.ssao_enabled = false
	env.volumetric_fog_enabled = _vol_fog(w)
	cam.environment = env


func _vol_fog(w: World) -> bool:
	return w.env.volumetric_fog_enabled and Settings.quality >= 2


func _sync_env() -> void:
	var w: World = Game.world
	if env == null or w == null or w.env == null:
		return
	for p in ENV_SYNC:
		var v: Variant = w.env.get(p)
		if env.get(p) != v:
			env.set(p, v)
	var vf := _vol_fog(w)
	if env.volumetric_fog_enabled != vf:
		env.volumetric_fog_enabled = vf


func _process(delta: float) -> void:
	var w: World = Game.world
	if w and room != "":
		var s := w.steam_at(room)
		fog = lerpf(fog, clampf(s * 2.2, 0.0, 1.0), delta * 0.6)
	if force_fog >= 0.0:
		fog = force_fog
	mat.set_shader_parameter("fog", fog)
	var pl: Player = Game.player
	if pl == null:
		return
	var main_cam := pl.cam
	var near := main_cam.global_position.distance_to(global_position) < 8.0
	if not (near and on_screen):
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if env == null:
		_make_env()
	_sync_env()
	# отражаем позицию камеры относительно плоскости зеркала (нормаль — +Z зеркала)
	var n := global_transform.basis.z.normalized()
	var p0 := global_position
	var cp := main_cam.global_position
	var dist := (cp - p0).dot(n)
	if dist <= 0.02:
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	var rp := cp - n * dist * 2.0
	# камера из отражённой точки смотрит на зеркало (вдоль +Z зеркала)
	var cb := global_transform.basis.orthonormalized() * Basis(Vector3.UP, PI)
	cam.global_transform = Transform3D(cb, rp)
	var rel := cb.inverse() * (p0 - rp)
	cam.set_frustum(size.y, Vector2(rel.x, rel.y), maxf(0.05, -rel.z), 60.0)
