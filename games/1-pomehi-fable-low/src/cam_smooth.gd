extends Node3D
## Плавная камера между шагами физики.
## Игрок ходит в _physics_process 60 раз в секунду, а монитор рисует 144–240 кадров: без сглаживания камера
## два-три кадра стоит на месте и потом прыгает — при ходьбе и поворотах картинка дёргается.
## Узел стоит между телом игрока и головой (камерой) и в каждом кадре сдвигает её туда, где тело было бы
## в этот момент — между двумя последними шагами физики. Перед каждым шагом физики сдвиг снимается,
## так что лучи, шум и ИИ видят настоящее положение игрока.

const TELEPORT := 0.75  # м за один шаг физики: больше — это телепорт, его не сглаживаем

var _body: Node3D
var _prev := Vector3.ZERO
var _curr := Vector3.ZERO
var _armed := false


func _ready() -> void:
	_body = get_parent() as Node3D
	process_priority = -1000          # раньше остального кадра: фонарь, звук, зеркала берут уже сглаженную камеру
	process_physics_priority = 1000   # после того как тело сдвинулось
	get_tree().physics_frame.connect(_before_physics)


func _before_physics() -> void:
	position = Vector3.ZERO


func _physics_process(_dt: float) -> void:
	var p := _body.global_position
	_prev = p if not _armed or p.distance_to(_curr) > TELEPORT else _curr
	_curr = p
	_armed = true


func _process(_dt: float) -> void:
	position = Vector3.ZERO
	if not _armed:
		return
	var p := _body.global_position
	if not p.is_equal_approx(_curr):
		# тело переставили вне физики (укрытие, катсцена) — этот кадр без сглаживания
		_prev = p
		_curr = p
		return
	var off := _prev.lerp(_curr, Engine.get_physics_interpolation_fraction()) - _curr
	position = _body.global_basis.inverse() * off
