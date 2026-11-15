shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
void fragment() {
	vec2 p=abs(UV-0.5)*2.0;
	float a=(1.0-smoothstep(0.5,1.0,p.x))*(1.0-smoothstep(0.5,1.0,p.y));
	ALBEDO=vec3(0.005,0.009,0.012); ALPHA=a*0.34;
}
