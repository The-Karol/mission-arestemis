shader_type spatial;
render_mode unshaded;
void fragment() {
	vec2 uv = UV;
	float grid = step(0.95,fract(uv.x*16.0))*0.12 + step(0.96,fract(uv.y*12.0))*0.12;
	float trace = exp(-abs(uv.y-(0.5+0.18*sin(uv.x*9.0)+0.06*sin(uv.x*23.0)))*180.0);
	float lines = 0.92+0.08*sin(uv.y*700.0);
	float sweep = exp(-abs(uv.y-fract(TIME*0.12))*35.0)*0.08;
	float edge = smoothstep(0.0,0.05,min(min(uv.x,1.0-uv.x),min(uv.y,1.0-uv.y)));
	ALBEDO = (vec3(0.008,0.035,0.025)+vec3(0.13,0.6,0.31)*(grid+trace*0.8+sweep))*lines*edge;
}
