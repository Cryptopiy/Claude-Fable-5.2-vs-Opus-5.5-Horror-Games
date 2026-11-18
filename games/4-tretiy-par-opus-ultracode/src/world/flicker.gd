extends Node
## Старая лампа: горит почти ровно, изредка на миг проседает (плохой контакт).

var light: Light3D
var base := 1.0
var blink := 0.0      # > 0 — мигание с этим периодом, с (маячок), иначе — старая лампа
var fire := false     # пламя: медленное неровное дыхание без провалов
var _t := 0.0
var _dip := 0.0


func _process(delta: float) -> void:
	if light == null or not is_instance_valid(light):
		return
	_t += delta
	if fire:
		light.light_energy = base * (0.78 + 0.12 * sin(_t * 7.0) + 0.07 * sin(_t * 17.0 + 1.3) + randf() * 0.06)
		return
	if blink > 0.0:
		var ph := fmod(_t, blink) / blink
		light.light_energy = base * pow(maxf(0.0, sin(ph * TAU)), 3.0)
		return
	if _dip <= 0.0 and randf() < delta * 0.35:
		_dip = randf_range(0.06, 0.25)
	var k := 1.0 + sin(_t * 47.0) * 0.015 + sin(_t * 3.1) * 0.03
	if _dip > 0.0:
		_dip -= delta
		k *= randf_range(0.15, 0.6)
	light.light_energy = base * k
