shader_type spatial;
render_mode cull_back;
// Снег на предметах: сугробы у стен и столбов, снег на крышах. Текстура берётся по мировым координатам
// с трёх сторон (triplanar) и смешивается так же, как у земли (snow.gdshader) — сугроб не отличается по цвету
// от наста вокруг и не растягивается на изогнутой поверхности.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float tile = 2.6;
uniform vec3 tint : source_color = vec3(0.9, 0.93, 1.0);
varying vec3 wpos;
varying vec3 wn;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 w = pow(abs(wn), vec3(4.0));
	w /= (w.x + w.y + w.z + 0.0001);
	vec3 ax = texture(albedo_tex, wpos.zy / tile).rgb;
	vec3 ay = texture(albedo_tex, wpos.xz / tile).rgb;
	vec3 az = texture(albedo_tex, wpos.xy / tile).rgb;
	vec3 alb = ax * w.x + ay * w.y + az * w.z;
	alb = mix(vec3(0.80, 0.83, 0.88), alb, 0.42);
	float macro = texture(noise_tex, wpos.xz * 0.011).r;
	alb *= mix(0.84, 1.04, macro);
	// у земли и на теневых откосах снег чуть синее и темнее
	alb *= mix(0.86, 1.0, smoothstep(-0.2, 0.8, wn.y));
	ALBEDO = alb * tint * 0.9;
	NORMAL_MAP = texture(normal_tex, wpos.xz / tile).rgb;
	NORMAL_MAP_DEPTH = 0.8 * w.y;
	float sp = texture(noise_tex, wpos.xz * 2.3 + wpos.y * 1.7).b * texture(noise_tex, wpos.zx * 3.1 + 0.37).b;
	float glint = smoothstep(0.62, 0.8, sp);
	ROUGHNESS = mix(0.9, 0.25, glint);
	SPECULAR = mix(0.2, 0.85, glint);
}
