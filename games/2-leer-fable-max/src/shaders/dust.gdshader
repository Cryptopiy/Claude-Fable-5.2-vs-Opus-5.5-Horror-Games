shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, shadows_disabled, specular_disabled;
// Пыль в доме: видна только там, где светит лампа, печь или фонарь.

void fragment() {
	float r = length(UV - 0.5) * 2.0;
	ALBEDO = vec3(0.0);
	ALPHA = smoothstep(1.0, 0.0, r) * COLOR.a * 0.55;
}

void light() {
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * 0.5;
}
