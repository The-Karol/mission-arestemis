shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;

varying float opacity;

void vertex() {
	vec3 center = MODEL_MATRIX[3].xyz;
	float phase = INSTANCE_CUSTOM.r * 6.283185;
	center += vec3(0.20 * sin(TIME * 0.22 + phase), 0.16 * sin(TIME * 0.31 + phase), 0.14 * cos(TIME * 0.24 + phase));
	vec3 eye = (VIEW_MATRIX * vec4(center, 1.0)).xyz;
	eye.xy += VERTEX.xy * (0.6 + INSTANCE_CUSTOM.g);
	POSITION = PROJECTION_MATRIX * vec4(eye, 1.0);
	opacity = (0.08 + 0.22 * INSTANCE_CUSTOM.b) * smoothstep(0.4, 1.8, -eye.z);
}

void fragment() {
	float radius = length(UV * 2.0 - 1.0);
	ALBEDO = vec3(1.0, 0.83, 0.62);
	ALPHA = (1.0 - smoothstep(0.06, 1.0, radius)) * opacity;
}
