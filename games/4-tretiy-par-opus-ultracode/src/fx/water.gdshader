shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_always, specular_schlick_ggx;
// Чёрная вода «мёртвой гладью»: дна не видно, своего цвета нет — только отражения. Френелевский отсвет тона зоны,
// отражение ярких прямоугольников (фонарь в потолке бассейна, дверцы топок) считается аналитически, без пробников.
// Кольца расходятся только от звуков в воде (шаги вброд, шайка, Хозяйка): видно, что вода «услышала».
// murk — насколько мутная (1 = дна не видно), alpha_shallow — прозрачность у краёв и на мелком.

uniform vec3 deep_color : source_color = vec3(0.004, 0.005, 0.005);
uniform vec3 shallow_color : source_color = vec3(0.02, 0.022, 0.02);
uniform float murk = 0.9;
uniform float alpha_shallow = 0.55;
uniform float wave_scale = 1.0;
uniform float wave_speed = 0.08;
uniform float wave_amp = 0.9;
uniform vec3 sheen = vec3(0.005, 0.006, 0.007);     // слабый отсвет под скользящим углом (тон зоны)
uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;
// кольца: x, z, время начала, радиус (0 — нет)
uniform vec4 rings[8];
uniform float ring_now = 0.0;
// отражаемые излучатели: центр + яркость, полуоси u (w — число рам поперёк u), v, цвет
uniform vec4 mir_c[4];
uniform vec4 mir_u[4];
uniform vec4 mir_v[4];
uniform vec4 mir_col[4];

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

vec3 wave_normal(vec2 p, float t) {
	float e = 0.08;
	vec2 o = vec2(t * 0.11, t * 0.07);
	float h0 = texture(noise_tex, p * 0.21 + o).r;
	float hx = texture(noise_tex, (p + vec2(e, 0.0)) * 0.21 + o).r;
	float hz = texture(noise_tex, (p + vec2(0.0, e)) * 0.21 + o).r;
	return normalize(vec3((h0 - hx) * wave_amp, 1.0, (h0 - hz) * wave_amp));
}

void fragment() {
	// часы мира, а не TIME: TIME сбрасывается раз в час (time_rollover_secs), и рябь на всей воде прыгала за кадр
	float t = ring_now * wave_speed;
	vec3 n = wave_normal(world_pos.xz * wave_scale, t);
	for (int i = 0; i < 8; i++) {
		vec4 r = rings[i];
		float age = ring_now - r.z;
		if (r.w <= 0.0 || age < 0.0 || age > 3.0) {
			continue;
		}
		vec2 dv = world_pos.xz - r.xy;
		float dist = length(dv) + 0.0001;
		float front = age * 1.6;
		float x = dist - front;
		float w = sin(x * 14.0) * exp(-x * x * 6.0) * exp(-age * 1.2) * (1.0 - smoothstep(r.w * 0.7, r.w, dist));
		n.xz += dv / dist * w * 0.4;
	}
	n = normalize(n);
	vec3 nv = (VIEW_MATRIX * vec4(n, 0.0)).xyz;
	NORMAL = normalize(mix(NORMAL, nv, 0.35));
	float depth = texture(depth_tex, SCREEN_UV).r;
	vec4 upos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	upos.xyz /= upos.w;
	float thick = clamp((VERTEX.z - upos.z) * 1.2, 0.0, 1.0);
	float m = clamp(mix(thick, 1.0, murk), 0.0, 1.0);
	ALBEDO = mix(shallow_color, deep_color, m);
	// антиалиасинг блика: где волнистая нормаль меняется быстрее пикселя (вдали, под фонарём), лепесток GGX
	// шире — ровный блик вместо белого «конфетти»; где нормаль гладкая, гладь остаётся зеркальной (0.03)
	vec3 dn = fwidth(n);
	ROUGHNESS = clamp(sqrt(0.0009 + dot(dn, dn) * 2.0), 0.03, 0.25);
	METALLIC = 0.0;
	SPECULAR = 0.5;
	ALPHA = mix(alpha_shallow, 0.985, m);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	vec3 em = sheen * fres * 3.0;
	// отражение излучателей: луч от глаза, отражённый волнистой гладью, против прямоугольника
	// для зеркала — смягчённая нормаль: волна качает отражение, а не рвёт его на «лужи с дырами»
	vec3 nm = normalize(mix(vec3(0.0, 1.0, 0.0), n, 0.06));
	vec3 rd = reflect(normalize(world_pos - CAMERA_POSITION_WORLD), nm);
	for (int i = 0; i < 4; i++) {
		if (mir_c[i].w <= 0.0) {
			continue;
		}
		vec3 u = mir_u[i].xyz;
		vec3 v = mir_v[i].xyz;
		vec3 pn = normalize(cross(u, v));
		float den = dot(rd, pn);
		if (den > -0.0001) {
			continue;
		}
		float tt = dot(mir_c[i].xyz - world_pos, pn) / den;
		if (tt <= 0.0) {
			continue;
		}
		vec3 h = world_pos + rd * tt - mir_c[i].xyz;
		float a = abs(dot(h, u)) / dot(u, u);
		float b = abs(dot(h, v)) / dot(v, v);
		float inside = (1.0 - smoothstep(0.5, 1.3, a)) * (1.0 - smoothstep(0.5, 1.3, b));
		if (mir_u[i].w > 0.0) {
			float f = fract((dot(h, u) / dot(u, u) * 0.5 + 0.5) * mir_u[i].w);
			inside *= mix(1.0, smoothstep(0.0, 0.15, f) * smoothstep(0.0, 0.15, 1.0 - f), 0.6);
		}
		em += mir_col[i].rgb * mir_c[i].w * inside * (0.35 + fres * 0.65) / (1.0 + tt * 0.08);
	}
	EMISSION = em;
}
