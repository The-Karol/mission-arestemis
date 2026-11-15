shader_type spatial;
uniform sampler2D brushed : repeat_enable, filter_linear_mipmap;
varying vec3 at;
void vertex() {
	at = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
}
void fragment() {
	vec2 p = at.xz;
	vec2 seam = abs(fract(p / vec2(1.2, 2.4) + 0.5) - 0.5) * vec2(1.2,2.4);
	float joint = 1.0 - smoothstep(0.002,0.008+fwidth(p.x)+fwidth(p.y),min(seam.x,seam.y));
	vec2 tread = p * 12.0;
	tread.x += 0.5 * mod(floor(tread.y),2.0);
	vec2 cell = fract(tread)-0.5;
	float angle = mix(-0.65,0.65,mod(floor(tread.x)+floor(tread.y),2.0));
	vec2 uv = mat2(vec2(cos(angle),sin(angle)),vec2(-sin(angle),cos(angle))) * cell;
	float ridge = 1.0-smoothstep(0.60,1.0,length(uv*vec2(2.6,9.0)));
	ridge *= 1.0-smoothstep(0.16,0.60,max(fwidth(tread.x),fwidth(tread.y)));
	float coat = texture(brushed,p*0.8).r;
	ALBEDO = mix(vec3(0.17,0.21,0.22),vec3(0.27,0.30,0.30),coat) + 0.055*ridge - 0.07*joint;
	METALLIC = 0.35;
	ROUGHNESS = 0.53-0.16*ridge+0.12*joint;
}
