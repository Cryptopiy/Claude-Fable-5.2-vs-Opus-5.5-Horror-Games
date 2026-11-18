extends RefCounted
## «Золотой набор» кадров для сверки визуала до/после (tools/dev/golden.sh).
## Каждый кадр: name, cp (контрольная точка — состояние мира), pos (ноги игрока), look [yaw°, pitch°]
## (yaw 0 — на север, -z; 90 — на запад; -90 — на восток), light (фонарь).
## Необязательно: hoz (где стоит Хозяйка), steam {комната: 0..1}, ui (phone|note|pause|code), event (метод сценария).

const POINTS := [
	# ---------- двор ----------
	{"name": "01_yard_front", "cp": "c01_yard", "pos": Vector3(26, 0.05, 44), "look": [0.0, 5.0], "light": false},
	{"name": "02_yard_van", "cp": "c01_yard", "pos": Vector3(24, 0.05, 47), "look": [-60.0, 0.0], "light": false},
	{"name": "03_yard_west", "cp": "c01_yard", "pos": Vector3(-5, 0.05, 36), "look": [-14.0, 10.0], "light": false},
	{"name": "04_yard_door", "cp": "c01_yard", "pos": Vector3(26, 0.05, 35), "look": [0.0, 8.0], "light": true},
	# ---------- вестибюль и коридор персонала ----------
	{"name": "05_lobby_w", "cp": "c02_lobby", "pos": Vector3(17, 0.05, 28.5), "look": [-60.0, -5.0], "light": true},
	{"name": "06_lobby_dark", "cp": "c02_lobby", "pos": Vector3(25.5, 0.05, 28.8), "look": [0.0, 0.0], "light": false},
	{"name": "07_lobby_stairs", "cp": "c02_lobby", "pos": Vector3(31, 0.05, 28.5), "look": [-41.0, -20.0], "light": true},
	{"name": "08_lobby_kassa", "cp": "c02_lobby", "pos": Vector3(21, 0.05, 27.5), "look": [65.0, -5.0], "light": false},
	{"name": "09_admin", "cp": "c02_lobby", "pos": Vector3(35, 0.05, 21.5), "look": [90.0, -5.0], "light": true},
	{"name": "10_office", "cp": "c02_lobby", "pos": Vector3(21.2, 0.05, 19.5), "look": [45.0, -10.0], "light": true},
	{"name": "11_barber", "cp": "c02_lobby", "pos": Vector3(28, 0.05, 19.4), "look": [-66.0, -15.0], "light": true},
	# ---------- мужское отделение ----------
	{"name": "12_m_lock", "cp": "c03_mlock", "pos": Vector3(13, 0.05, 29), "look": [30.0, -5.0], "light": true},
	{"name": "13_m_lock_mirror", "cp": "c03_mlock", "pos": Vector3(7.9, 0.05, 27.6), "look": [180.0, 0.0], "light": true},
	{"name": "14_m_wait", "cp": "c03_mlock", "pos": Vector3(3, 0.05, 21.2), "look": [175.0, -5.0], "light": true},
	{"name": "15_m_wash", "cp": "c04_mwash", "pos": Vector3(12, 0.05, 19), "look": [40.0, 0.0], "light": true},
	{"name": "16_m_wash_dark", "cp": "c04_mwash", "pos": Vector3(12, 0.05, 19), "look": [40.0, 0.0], "light": false},
	{"name": "17_m_steam", "cp": "c04_mwash", "pos": Vector3(4, 0.05, 8.5), "look": [0.0, -5.0], "light": true},
	{"name": "18_m_shower", "cp": "c04_mwash", "pos": Vector3(11, 0.05, 10.0), "look": [0.0, 0.0], "light": true},
	{"name": "19_m_wash_hoz", "cp": "c04_mwash", "pos": Vector3(7, 0.05, 18.5), "look": [0.0, 0.0], "light": true, "hoz": Vector3(7, 0.0, 12.5)},
	{"name": "20_m_wash_steam", "cp": "c04_mwash", "pos": Vector3(12, 0.05, 19), "look": [40.0, 0.0], "light": true, "steam": {"m_wash": 0.85}},
	# ---------- интерфейс ----------
	{"name": "21_ui_phone", "cp": "c05_code", "pos": Vector3(2.0, 0.05, 27.6), "look": [-90.0, 0.0], "light": true, "ui": "phone"},
	{"name": "22_ui_note", "cp": "c05_code", "pos": Vector3(2.0, 0.05, 27.6), "look": [-90.0, 0.0], "light": true, "ui": "note"},
	{"name": "23_ui_pause", "cp": "c05_code", "pos": Vector3(2.0, 0.05, 27.6), "look": [-90.0, 0.0], "light": true, "ui": "pause"},
	{"name": "24_ui_code", "cp": "c05_code", "pos": Vector3(11, 0.05, 4.2), "look": [0.0, 0.0], "light": true, "ui": "code"},
	# ---------- технический коридор ----------
	{"name": "25_service", "cp": "c06_service", "pos": Vector3(50, 0.05, 1.5), "look": [90.0, 0.0], "light": true},
	{"name": "26_service_fire", "cp": "c06_service", "pos": Vector3(7.2, 0.05, 1.4), "look": [115.0, -10.0], "light": false},
	{"name": "27_stairwell", "cp": "c06_service", "pos": Vector3(25.5, 0.05, 4.8), "look": [0.0, -10.0], "light": true},
	# ---------- женское отделение, бассейн ----------
	{"name": "28_f_wash", "cp": "c07_women", "pos": Vector3(40, 0.05, 19), "look": [-40.0, 0.0], "light": true},
	{"name": "29_f_lock", "cp": "c07_women", "pos": Vector3(39, 0.05, 29), "look": [-30.0, -5.0], "light": true},
	{"name": "30_f_attend", "cp": "c07_women", "pos": Vector3(49.2, 0.05, 25.0), "look": [-160.0, -10.0], "light": true},
	{"name": "31_pool", "cp": "c07_women", "pos": Vector3(16, 0.05, 16), "look": [-66.0, -10.0], "light": true},
	{"name": "32_pool_dark", "cp": "c07_women", "pos": Vector3(16, 0.05, 16), "look": [-66.0, -10.0], "light": false},
	{"name": "33_pool_drained", "cp": "c09_drained", "pos": Vector3(33.6, 0.05, 15.6), "look": [90.0, -25.0], "light": true},
	# ---------- подвал ----------
	{"name": "34_collector", "cp": "c10_collector", "pos": Vector3(31, -4.45, 10.5), "look": [0.0, 0.0], "light": true},
	{"name": "35_boiler", "cp": "c11_boiler", "pos": Vector3(25.25, -4.32, -8.5), "look": [15.0, 0.0], "light": true},
	{"name": "36_boiler_dark", "cp": "c11_boiler", "pos": Vector3(25.25, -4.32, -8.5), "look": [15.0, 0.0], "light": false},
	{"name": "37_boiler_hoz", "cp": "c11_boiler", "pos": Vector3(25.25, -4.32, -8.5), "look": [15.0, 0.0], "light": true, "hoz": Vector3(23.6, -4.5, -15.0)},
	{"name": "38_banya", "cp": "c11_boiler", "pos": Vector3(32.7, -4.45, -8.2), "look": [-67.0, -10.0], "light": true},
	{"name": "39_stoker", "cp": "c11_boiler", "pos": Vector3(14.6, -4.32, -10.4), "look": [140.0, -15.0], "light": false},
	{"name": "40_meter", "cp": "c12_valve", "pos": Vector3(15, -4.32, -15.5), "look": [60.0, -10.0], "light": true},
	{"name": "41_coal", "cp": "c12_valve", "pos": Vector3(33, -4.45, -12), "look": [-19.0, 22.0], "light": true},
]
