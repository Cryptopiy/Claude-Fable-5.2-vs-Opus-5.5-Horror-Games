shader_type spatial;
render_mode cull_back, specular_schlick_ggx;
// Зеркало: отражение из SubViewport, запотевание и надпись пальцем (видна в пару).

uniform sampler2D refl : source_color, filter_linear;
uniform sampler2D writing : hint_default_transparent, filter_linear_mipmap;
uniform bool has_writing = false;
uniform float fog = 0.0;
uniform vec2 msize = vec2(1.0, 1.0);   // размер стекла, м: пятна круглые при любом соотношении сторон

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

// гладкий шум: пятна без сетки (hash(floor(UV*60)) давал ровную решётку прямоугольников — «москитную сетку»)
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 uv = vec2(1.0 - UV.x, UV.y);
	vec3 r = texture(refl, uv).rgb;
	// старая амальгама: мягкие тёмные пятна, гуще у рамы, середина почти чистая
	float edge = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	vec2 pm = UV * msize;
	float nz = vnoise(pm * 16.0) * 0.65 + vnoise(pm * 38.0) * 0.35;
	float spots = smoothstep(0.0, 0.12, edge) * (1.0 - 0.22 * smoothstep(0.5, 0.85, nz) * (1.0 - 0.6 * smoothstep(0.04, 0.3, edge)));
	float w = has_writing ? texture(writing, UV).a : 0.0;
	float f = clamp(fog * (1.0 - w * 0.9), 0.0, 1.0);
	ALBEDO = vec3(0.42, 0.43, 0.42) * f;
	ROUGHNESS = mix(0.08, 0.7, f);
	SPECULAR = 0.5;
	EMISSION = r * spots * (1.0 - f * 0.92) * 0.95;
}
