shader_type spatial;
render_mode unshaded;
uniform sampler2D reflection:filter_linear;
void fragment(){
	vec2 uv=vec2(1.0-UV.x,UV.y);
	vec2 pixel=1.0/vec2(textureSize(reflection,0));
	// Frosted glass: keep the near floor/body legible, soften the distant upper field.
	vec2 radius=pixel*mix(1.2,4.2,smoothstep(0.25,0.9,UV.y));
	vec3 col=texture(reflection,uv).rgb*0.24;
	col+=(texture(reflection,uv+vec2(radius.x,0)).rgb+texture(reflection,uv-vec2(radius.x,0)).rgb)*0.12;
	col+=(texture(reflection,uv+vec2(0,radius.y)).rgb+texture(reflection,uv-vec2(0,radius.y)).rgb)*0.12;
	col+=(texture(reflection,uv+radius).rgb+texture(reflection,uv-radius).rgb+texture(reflection,uv+vec2(radius.x,-radius.y)).rgb+texture(reflection,uv+vec2(-radius.x,radius.y)).rgb)*0.07;
	ALBEDO=col*vec3(0.90,0.93,0.94)+vec3(0.018);
}
