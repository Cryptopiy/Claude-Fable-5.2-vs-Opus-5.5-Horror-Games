shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap;
// Флажок на столбе леера: полощется по ветру. Цвет — из экземпляра MultiMesh.

global uniform vec4 g_wind;
global uniform float g_gust;
varying vec3 col;

void vertex() {
	float k = UV.x;
	vec3 wp = MODEL_MATRIX[3].xyz;
	float ph = wp.x * 1.7 + wp.z * 2.3;
	float sp = 9.0 + g_gust * 9.0;
	float amp = (0.025 + 0.05 * g_wind.z + 0.06 * g_gust) * k;
	VERTEX.z += sin(TIME * sp + k * 7.0 + ph) * amp;
	VERTEX.y += sin(TIME * sp * 1.3 + k * 5.0 + ph) * amp * 0.5 - k * k * 0.03;
	col = COLOR.rgb;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	// свободный край истрёпан ветром: рваная бахрома, у каждого флажка своя
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float seed = floor(col.r * 97.0 + col.g * 61.0) + floor(NODE_POSITION_WORLD.x * 3.1 + NODE_POSITION_WORLD.z * 1.7);
	// неровный рваный край: несколько синусов с разной частотой, без «лесенки»
	float fray = 0.92 + 0.035 * sin(UV.y * 31.0 + seed) + 0.025 * sin(UV.y * 77.0 + seed * 1.7) + 0.015 * sin(UV.y * 9.0 + seed * 0.3);
	if (UV.x > fray) {
		discard;
	}
	// наледь по верхней кромке
	float ice = smoothstep(0.8, 0.99, 1.0 - UV.y) * 0.3;
	ALBEDO = mix(col * (0.8 + 0.2 * sin(UV.x * 40.0)), vec3(0.7, 0.72, 0.76), ice);
	ROUGHNESS = 0.75;
	SPECULAR = 0.3;
}
