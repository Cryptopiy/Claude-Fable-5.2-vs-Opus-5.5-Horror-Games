shader_type fog;
// Пар и стелющийся туман для объёмного тумана (среднее и высокое качество).
// layer > 0: пар копится под потолком (рост Хозяйки 2.6 м уходит в эту полосу — видно волосы от плеч и ниже);
// layer < 0: туман стелется у самого пола и воды (голени пропадают). Медленно течёт шум; края объёма мягкие.

uniform float density = 0.0;
uniform float layer = 1.0;
uniform vec3 albedo : source_color = vec3(0.9, 0.9, 0.88);
// повтор явно: шум берётся по мировым координатам (далеко за 0..1), без repeat он упирался бы в край текстуры
uniform sampler3D noise3d : hint_default_white, filter_linear, repeat_enable;

void fog() {
	float h = UVW.y;
	float k = 1.0;
	if (layer > 0.0) {
		k = mix(1.0, smoothstep(0.25, 0.95, h) * 1.6 + 0.25, layer);
	} else {
		k = mix(1.0, (1.0 - smoothstep(0.0, 0.85, h)) * 1.7 + 0.05, -layer);
	}
	float n = texture(noise3d, WORLD_POSITION * 0.18 + vec3(0.0, -TIME * 0.03, TIME * 0.015)).r;
	float edge = smoothstep(0.0, 0.12, min(min(UVW.x, 1.0 - UVW.x), min(UVW.z, 1.0 - UVW.z)));
	DENSITY = density * k * mix(0.55, 1.35, n) * edge;
	ALBEDO = albedo;
}
