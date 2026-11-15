shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
void fragment() {
	float dash=1.0-smoothstep(0.55,0.62,fract(UV.y/0.9-TIME*0.28));
	float edge=pow(max(0.0,1.0-abs(UV.x-0.5)*2.0),1.2);
	ALBEDO=vec3(0.12,0.72,1.0);
	EMISSION=vec3(0.08,0.5,0.9)*edge;
	ALPHA=dash*edge*0.8;
}
