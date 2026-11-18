extends Node3D
## Метель — сменный модуль погоды. Договор с Weather: setup(w) — построить; set_hide_boxes(mn, mx, n) — коробки помещений
## (снег внутри не рисуется); tick(w, cam_pos, dt) — каждый кадр: за камерой, плотность и скорость от w.intensity(), w.gust,
## w.base, w.indoor, w.clear, w.vis, Cfg.fx.
## Состав (выбран сравнением четырёх вариантов по кадрам, см. docs/POLISH_LOG.md):
##  • snow_screen.gd — экранные слои: снежная пыль, мягкие диски расфокуса у камеры, штрихи и дальняя пыль в трёх решётках
##    мира, завесы и позёмка шумом; закрыты глубиной сцены и освещены фонарём игрока так же, как его считает движок;
##    у огней построек светятся настоящие частицы;
##  • snow_streaks.gd — тонкие мягкие штрихи средних хлопьев по ветру и струйки позёмки у наста (слои mid и drift).
## Раньше хлопья были резкими белыми прямоугольниками: на 540 строк, растянутых на экран, они читались как «палки».

var screen: Node3D
var streaks: Node3D


func setup(w: Node3D) -> void:
	screen = Node3D.new()
	screen.name = "Screen"
	screen.set_script(load("res://src/world/snow_screen.gd"))
	add_child(screen)
	screen.setup(w)
	streaks = Node3D.new()
	streaks.name = "Streaks"
	streaks.set_script(load("res://src/world/snow_streaks.gd"))
	streaks.only_layers = ["mid", "drift"]
	streaks.with_sheet = false
	streaks.with_fog = false
	add_child(streaks)
	streaks.setup(w)


func set_hide_boxes(mn: PackedVector3Array, mx: PackedVector3Array, n: int) -> void:
	screen.set_hide_boxes(mn, mx, n)
	streaks.set_hide_boxes(mn, mx, n)


func tick(w: Node3D, cp: Vector3, dt: float) -> void:
	screen.tick(w, cp, dt)
	streaks.tick(w, cp, dt)
