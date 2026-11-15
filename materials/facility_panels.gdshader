shader_type spatial;
uniform vec4 paint_color : source_color = vec4(0.49,0.52,0.51,1.0);
uniform float ceiling = 0.0;
uniform sampler2D enamel : repeat_enable,filter_linear_mipmap;
varying vec3 world_pos;
varying vec3 world_normal;
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
	vec2 p = abs(world_normal.y)>0.7 ? world_pos.xz : vec2(abs(world_normal.x)>0.7 ? world_pos.z : world_pos.x, world_pos.y);
	vec2 cell_size = ceiling > 0.5 ? vec2(1.8,1.8) : vec2(1.8,4.0);
	vec2 grid = fract(p / cell_size);
	vec2 distance_to_edge = min(grid,1.0-grid)*cell_size;
	float aa = max(fwidth(p.x),fwidth(p.y));
	float seam = 1.0-smoothstep(0.002,0.009+aa,min(distance_to_edge.x,distance_to_edge.y));
	float patina=texture(enamel,p*0.65).r;
	vec3 base = paint_color.rgb*(0.84+0.34*patina);
	base = mix(base,base*0.55,seam*0.5);
	float belt = 1.0-smoothstep(0.10,0.105+aa,abs(mod(world_pos.y,4.0)-1.05));
	base = mix(base,vec3(0.30,0.067,0.048)*(0.85+patina*0.28),belt*(1.0-ceiling));
	ALBEDO = base;
	METALLIC = 0.12;
	ROUGHNESS = 0.46+patina*0.22;
}
