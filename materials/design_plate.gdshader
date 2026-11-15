shader_type spatial;
render_mode unshaded;
uniform vec4 ink : source_color = vec4(0.74,0.84,0.67,1.);
uniform float line_weight = 1.0;
void fragment(){
	float facing=abs(dot(normalize(NORMAL),normalize(VIEW)));
	float shade=dot(normalize(NORMAL),normalize(vec3(-0.35,0.7,0.6)));
	float bevel=clamp(length(fwidth(NORMAL))*3.8*line_weight,0.,1.);
	float hatch=smoothstep(0.76,0.98,fract((FRAGCOORD.x+FRAGCOORD.y)*0.18));
	float edge=max(1.-smoothstep(0.04,0.29*line_weight,facing),bevel);
	ALBEDO=mix(vec3(0.035,0.105,0.087),ink.rgb,clamp(0.23+0.24*shade+0.11*hatch*(1.-shade)+edge*0.76,0.,1.));
}