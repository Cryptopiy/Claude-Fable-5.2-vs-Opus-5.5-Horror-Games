shader_type sky;
// Ночное небо над двором: почти чёрный зенит, у горизонта бурая засветка города (на ней читаются силуэты
// крыши, трубы и деревьев), редкие тусклые звёзды. Без TIME — небо считается один раз.

uniform vec3 top_color : source_color = vec3(0.004, 0.006, 0.012);
uniform vec3 horizon_color : source_color = vec3(0.05, 0.042, 0.03);  // натриевая засветка города
uniform vec3 ground_color : source_color = vec3(0.004, 0.004, 0.005);
uniform float stars = 1.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void sky() {
	float h = EYEDIR.y;
	vec3 c = mix(horizon_color, top_color, smoothstep(-0.02, 0.5, h));
	c = mix(c, ground_color, smoothstep(0.0, -0.15, h));
	if (stars > 0.0 && h > 0.02) {
		// кубическая сетка на сфере взгляда: плотность ровная до зенита (сетка азимут/высота сгущалась
		// к зениту в «вертушку»); звезда лежит на сфере внутри своей ячейки, диск ~0.003 рад — не меньше
		// 1.5 px при 720p и масштабе 0.85, поэтому не мерцает и не пропадает при повороте головы.
		// Проекция на сферу сдвигает звезду по радиусу, и она может выйти к грани ячейки или за неё (тогда
		// диск обрезан или звезды нет): рисуем только те, что лежат в ячейке с запасом 0.2 (там яркость диска
		// уже < 0.3), а порог снижен с 0.99 до 0.984 — плотность видимых звёзд прежняя
		vec3 q = normalize(EYEDIR) * 90.0;
		vec3 cell = floor(q);
		float r = hash(cell.xy + cell.z * 17.31);
		if (r > 0.984) {
			vec3 j = vec3(hash(cell.xy + 1.7), hash(cell.yz + 3.1), hash(cell.zx + 5.3));
			vec3 sp = normalize(cell + 0.3 + 0.4 * j) * 90.0;
			vec3 f = sp - cell;
			if (min(f.x, min(f.y, f.z)) > 0.2 && max(f.x, max(f.y, f.z)) < 0.8) {
				float s = smoothstep(0.28, 0.05, length(q - sp));
				c += vec3(0.55, 0.6, 0.75) * s * (r - 0.984) * 28.0 * smoothstep(0.02, 0.35, h) * stars;
			}
		}
	}
	COLOR = c;
}
