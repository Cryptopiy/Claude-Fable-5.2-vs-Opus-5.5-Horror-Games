class_name Door
extends Node3D
## Дверь на петлях. Состояния: открыта/закрыта, заперта (ключ, код, засов, заклинило).
## Хозяйка открывает незапертые двери и проходит сквозь запертые.

signal opened(by_monster: bool)

## Филёнки темнее полотна: тем же материалом они сливались с ним, и оставалась одна случайная полоска-кромка.
const PANEL_SHADE := 0.78

var id := ""
var kind := "wood"
var room_a := ""
var room_b := ""
var width := 1.0
var height := 2.1
var along_x := true
var leaves: Array = []      # [{pivot: Node3D, body: AnimatableBody3D, sign: float}]
var amount := 0.0
var target := 0.0
var swing := 1.0
var swing_side := 0.0       # ≠ 0 — створка всегда открывается в эту сторону, кто бы ни открывал
var monster_ignores_lock := false  # засов держит только игрока: её путь по навмешу идёт через проём, сквозь створку не ходит
var locked := false
var key := ""               # предмет-ключ
var code := ""              # кодовый замок
var code_hint: Callable     # () -> String: строка над кнопками кодового замка (что игрок знает о коде)
var lock_text := "Заперто."
var unlock_text := ""
var on_locked: Callable     # вызывается, когда игрок дёргает запертую дверь
var on_open: Callable
var max_angle := 100.0
var creak := "door_wood"
var slam_next := false
var _fast := false          # створку захлопнули: закрывается быстро (slam_next set_open сбрасывает сразу, для звука)
var last_by_monster := 0.0
var lock_x := 0.0           # x накладки замка на стальной створке (в осях её петли)
var _block: StaticBody3D = null   # преграда в проёме, пока она проходит в запертую на засов дверь


func setup(pos: Vector3, ax: bool, w: float, h: float) -> void:
	along_x = ax
	width = w
	height = h
	position = pos
	if not along_x:
		rotation.y = PI * 0.5
	# створка почти во весь проём: 5 мм у петли, 6 мм сверху (в прежние щели 2–3 см светила соседняя комната и
	# виднелся торец стены в чужой краске). Обкладка откоса (builder.gd) входит в проём на 1.5 см: у петли и сверху
	# створка заходит за неё (щели нет), а притвор одностворчатой не доходит до неё 2 мм — иначе кромка на первых
	# градусах поворота проходила сквозь обкладку. У двустворчатой в середине обкладки нет.
	match kind:
		"wood":
			_leaf(-w * 0.5, w - 0.022, 1.0, _mat_wood(), _mat_wood(PANEL_SHADE))
		"wood2", "entrance":
			_leaf(-w * 0.5, w * 0.5 - 0.0075, 1.0, _mat_wood(), _mat_wood(PANEL_SHADE))
			_leaf(w * 0.5, w * 0.5 - 0.0075, -1.0, _mat_wood(), _mat_wood(PANEL_SHADE))
		"steel":
			_leaf(-w * 0.5, w - 0.022, 1.0, _mat_steel(), _mat_steel(PANEL_SHADE))
			# скрип — тот же, что у деревянных (door_wood*, свои записи ElevenLabs): так решил автор;
			# синтезированные door_steel* остались в snd/ (музей звуков), но двери их не играют
			# кнопки кодового замка — когда сценарий уже задал code (он делает это после постройки дверей)
			call_deferred("_keypad")
		"grate":
			_leaf(-w * 0.5, w - 0.022, 1.0, null)
			creak = "door_grate"
	_restore()


func _mat_wood(shade := 1.0) -> Material:
	var tex := "planks_weather"
	var t := Color(0.9, 0.88, 0.8)
	if kind == "entrance":
		tex = "planks_dark"
		t = Color(0.75, 0.6, 0.5)
	elif room_a.ends_with("steam") or room_b.ends_with("steam") or room_b == "banya":
		tex = "planks_dark"
		t = Color(0.8, 0.65, 0.5)
	return Mat.m(tex, {"tint": Color(t.r * shade, t.g * shade, t.b * shade), "local": true})


## Крашеная сталь: без металличности и почти без затемнения — иначе полотно без отражений выходило чёрной плитой.
func _mat_steel(shade := 1.0) -> Material:
	return Mat.m("metal_green", {"metal": 0.1, "tint": Color(0.95 * shade, 1.0 * shade, 0.95 * shade), "local": true})


func _leaf(hinge_x: float, lw: float, sgn: float, mat: Material, panel: Material = null) -> void:
	var pivot := Node3D.new()
	pivot.position = Vector3(hinge_x, 0, 0)
	add_child(pivot)
	var body := AnimatableBody3D.new()
	body.collision_layer = 4  # слой «двери»
	body.collision_mask = 0
	body.sync_to_physics = false
	pivot.add_child(body)
	body.set_meta("door", self)
	var th := 0.05
	var cx := sgn * (lw * 0.5 + 0.005)
	var h := height - 0.006
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(lw, h, th)
	cs.shape = sh
	cs.position = Vector3(cx, h * 0.5, 0)
	body.add_child(cs)
	var b := Geo.Batch.new()
	if kind == "grate":
		var bar := Mat.m("rust", {"metal": 0.7, "local": true})
		var x0 := cx - lw * 0.5
		var x1 := cx + lw * 0.5
		b.box(bar, Vector3(cx, 0.05, 0), Vector3(lw, 0.05, 0.04))
		b.box(bar, Vector3(cx, h - 0.03, 0), Vector3(lw, 0.05, 0.04))
		b.box(bar, Vector3(cx, h * 0.5, 0), Vector3(lw, 0.04, 0.03))
		var n := int(lw / 0.12)
		for i in n + 1:
			var xx := lerpf(x0 + 0.02, x1 - 0.02, float(i) / n)
			b.cyl(bar, Vector3(xx, 0.03, 0), Vector3(xx, h - 0.03, 0), 0.012, 6)
		# висячий замок
		b.box(Mat.m("rust", {"metal": 0.8, "tint": Color(0.6, 0.6, 0.6), "local": true}), Vector3(x1 - 0.12, 1.05, -0.06), Vector3(0.07, 0.09, 0.03))
	else:
		b.box(mat, Vector3(cx, h * 0.5, 0), Vector3(lw, h, th))
		# филёнки: свой, более тёмный материал и выступ 1.2 см — читаются рамкой, а не полоской-кромкой
		var pm: Material = panel if panel else mat
		if kind == "steel":
			b.box(pm, Vector3(cx, h * 0.5, 0), Vector3(lw * 0.7, h * 0.8, th + 0.012))
		else:
			# филёнка — тем же деревом, по контуру тонкая раскладка (рамка), а не тёмная заплатка
			for py in [h * 0.72, h * 0.27]:
				for s2 in [-1.0, 1.0]:
					b.box(pm, Vector3(cx, py + s2 * (h * 0.16 + 0.015), 0), Vector3(lw * 0.7 + 0.06, 0.03, th + 0.04))
					b.box(pm, Vector3(cx + s2 * (lw * 0.35 + 0.015), py, 0), Vector3(0.03, h * 0.32, th + 0.04))
		# нащельник на двустворчатой: накрывает щель между створками
		if (kind == "wood2" or kind == "entrance") and sgn > 0.0:
			b.box(pm, Vector3(cx + lw * 0.5 + 0.0025, h * 0.5, th * 0.5 + 0.007), Vector3(0.04, h, 0.014))
		# окошко в двери парилки / входа: тёмное гладкое стекло (ловит блик фонаря) в штапике
		if room_a.ends_with("steam") or room_b.ends_with("steam") or kind == "entrance":
			var glass := Mat.flat(Color(0.035, 0.045, 0.055), 0.06)
			var ww := lw * 0.45
			var wh := 0.32 if kind != "entrance" else 0.6
			var wy := h * 0.72
			b.box(glass, Vector3(cx, wy, 0), Vector3(ww, wh, th + 0.034))
			for s in [-1.0, 1.0]:
				b.box(mat, Vector3(cx, wy + s * (wh * 0.5 + 0.015), 0), Vector3(ww + 0.06, 0.03, th + 0.05))
				b.box(mat, Vector3(cx + s * (ww * 0.5 + 0.015), wy, 0), Vector3(0.03, wh, th + 0.05))
		# ручка
		var hx := cx + sgn * (lw * 0.5 - 0.09)
		# латунная ручка ловит тёплый луч фонаря
		var hm := Mat.flat(Color(0.62, 0.46, 0.22), 0.3, 0.9)
		for zz in [-0.06, 0.06]:
			b.box(hm, Vector3(hx, 1.0, zz), Vector3(0.12, 0.025, 0.025))
		if kind == "steel":
			# накладка замка: тёмная шершавая сталь (светлая гладкая под фонарём выгорала в белый прямоугольник)
			# и латунный цилиндр под ключ; кнопки кодового — в _keypad
			lock_x = hx
			var lm := Mat.flat(Color(0.12, 0.12, 0.115), 0.6, 0.5)
			for zs in [-1.0, 1.0]:
				b.box(lm, Vector3(hx, 1.25, zs * (th * 0.5 + 0.009)), Vector3(0.08, 0.16, 0.018))
				b.cyl(hm, Vector3(hx, 1.19, zs * (th * 0.5 + 0.018)), Vector3(hx, 1.19, zs * (th * 0.5 + 0.024)), 0.011, 8, true)
	b.commit(body, "leaf")
	leaves.append({"pivot": pivot, "body": body, "sign": sgn})


## Кнопки кодового замка (3×4, латунь) на накладке — только у двери с кодом; у дверей под ключ остаётся цилиндр.
func _keypad() -> void:
	if code == "" or leaves.is_empty():
		return
	var body: Node3D = leaves[0]["body"]
	var hm := Mat.flat(Color(0.62, 0.46, 0.22), 0.3, 0.9)
	var b := Geo.Batch.new()
	for zs in [-1.0, 1.0]:
		for r in 4:
			for c in 3:
				b.box(hm, Vector3(lock_x + (c - 1) * 0.022, 1.3 - r * 0.024, zs * 0.0455), Vector3(0.014, 0.014, 0.005))
	b.commit(body, "keypad", false)


func _restore() -> void:
	var st: Variant = Game.flags.get("door:" + id)
	if st == null:
		return
	match String(st):
		"open", "open-":
			locked = false
			# «open-» — открыта в другую сторону (swing −1); простое «open» (точки в texts.gd, старые сохранения) — +1
			swing = -1.0 if String(st) == "open-" else 1.0
			set_open(1.0, true)
		"unlocked":
			locked = false
		"locked":
			locked = true


## Преграда в проёме на слое дверей (4): игрок упирается, а её навмеш и луч касания (слой 1) идут насквозь.
## Метка «door» — прицел видит в ней эту дверь.
func _bolt_block(on: bool) -> void:
	if on and _block == null:
		_block = StaticBody3D.new()
		_block.collision_layer = 4
		_block.collision_mask = 0
		_block.set_meta("door", self)
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(width, height, 0.1)
		cs.shape = sh
		cs.position = Vector3(0, height * 0.5, 0)
		_block.add_child(cs)
		add_child(_block)
	elif not on and _block != null:
		_block.queue_free()
		_block = null


func save_state() -> void:
	Game.set_flag("door:" + id, ("open-" if swing < 0.0 else "open") if target > 0.5 else ("locked" if locked else "unlocked"))


func is_open() -> bool:
	return amount > 0.45


func get_prompt(_p: Node) -> String:
	if target > 0.5:
		return "Закрыть"
	if locked:
		if key != "" and Game.has(key):
			return "Отпереть"
		if code != "":
			return "Набрать код"
		return "Открыть"
	return "Открыть"


func use(p: Node) -> void:
	if target > 0.5:
		set_open(0.0)
		save_state()
		return
	if locked:
		if key != "" and Game.has(key):
			locked = false
			Snd.at("unlock", global_position + Vector3.UP, -2.0)
			if unlock_text != "":
				Game.think(unlock_text)
		elif code != "":
			if Game.main and Game.main.has_method("open_code"):
				Game.main.open_code(self)
			return
		else:
			Snd.at("door_locked", global_position + Vector3.UP, -4.0, randf_range(0.9, 1.1))
			if on_locked.is_valid():
				on_locked.call()
			else:
				Game.think(lock_text, 3.0)
			return
	_swing_from(p.global_position if p is Node3D else global_position)
	set_open(1.0)
	save_state()
	if on_open.is_valid():
		on_open.call()


func code_ok() -> void:
	locked = false
	code = ""
	Snd.at("unlock", global_position + Vector3.UP, 0.0)
	save_state()


func _swing_from(from: Vector3) -> void:
	# приоткрытая (0.3) или ещё закрывающаяся створка открывается туда, куда уже повёрнута: смена знака
	# перебрасывала её за кадр сквозь закрытое положение
	if amount > 0.01:
		return
	# дверь, открывающаяся всегда в одну сторону (как настоящая): створка не ходит над мостками котельной
	if swing_side != 0.0:
		swing = swing_side
		return
	var local := to_local(from)
	swing = -1.0 if local.z > 0.0 else 1.0


func set_open(v: float, silent := false, by_monster := false) -> void:
	var was := target
	target = v
	if silent:
		_fast = false
		amount = v
		_apply()
		return
	if v > was:
		_fast = false
		Snd.at(creak if not by_monster else creak + "_slow", global_position + Vector3.UP * 1.2, 2.0 if by_monster else -3.0, randf_range(0.85, 1.05))
		if Game.world and not by_monster:
			Game.world.noise(global_position, 7.0, "door")
		opened.emit(by_monster)
	elif v < was:
		var slam := slam_next
		slam_next = false
		_fast = slam
		Snd.at("door_slam" if slam else creak + "_close", global_position + Vector3.UP * 1.2, 4.0 if slam else -4.0, randf_range(0.9, 1.05))
		if Game.world and slam:
			Game.world.noise(global_position, 15.0, "door")


## Хозяйка у двери: открывает, если не заперта.
func monster_pass(from: Vector3) -> void:
	if (locked and not monster_ignores_lock) or target > 0.5:
		return
	if Time.get_ticks_msec() / 1000.0 - last_by_monster < 2.0:
		return
	last_by_monster = Time.get_ticks_msec() / 1000.0
	_swing_from(from)
	set_open(1.0, false, true)
	if locked:
		# засов держит игрока: она прошла — створка закрывается за ней и остаётся запертой (в снимок «открыта» не пишем,
		# иначе после перезагрузки засов снимался бы сам). Пока створка распахнута, в проёме преграда для игрока —
		# иначе за ней можно было проскочить в бассейн мимо подсобки, кода и техкоридора
		_bolt_block(true)
		get_tree().create_timer(3.0, false).timeout.connect(func():
			if is_instance_valid(self):
				_bolt_block(false)
				if locked and target > 0.5:
					set_open(0.0))
		return
	save_state()


func slam() -> void:
	slam_next = true
	set_open(0.0)
	slam_next = false  # дверь уже была закрыта — флаг не должен дожидаться чужого закрытия
	save_state()


func _physics_process(delta: float) -> void:
	if absf(amount - target) < 0.001:
		_fast = false
		return
	var speed := 4.0 if _fast else 1.6
	amount = move_toward(amount, target, delta * speed)
	_apply()


func _apply() -> void:
	var e := ease(amount, -1.8)
	for l in leaves:
		var pv: Node3D = l["pivot"]
		pv.rotation.y = deg_to_rad(max_angle) * e * float(l["sign"]) * swing * -1.0


## Центр проёма в мировых координатах.
func center() -> Vector3:
	return global_position + Vector3.UP * 1.0


## Нормаль проёма (в сторону room_b не гарантируется) — горизонтальная ось через проём.
func through_axis() -> Vector3:
	return global_transform.basis.z.normalized()
