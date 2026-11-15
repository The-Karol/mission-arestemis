shader_type spatial;
render_mode unshaded;
uniform float powered : hint_range(0.0,1.0) = 0.0;
void fragment() {
	float boot_line=exp(-pow((UV.y-0.5)/max(0.004,powered*0.52),2.0));
	float scan=0.94+0.06*sin(UV.y*600.0);
	ALBEDO=vec3(0.006,0.014,0.012)+vec3(0.17,0.66,0.42)*boot_line*powered*scan;
}
