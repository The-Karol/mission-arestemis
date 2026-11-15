shader_type canvas_item;
uniform sampler2D frame : hint_screen_texture,repeat_disable,filter_linear;
uniform vec2 shutter_pixels;
void fragment(){
	vec2 d=shutter_pixels*SCREEN_PIXEL_SIZE;
	vec3 c=texture(frame,SCREEN_UV).rgb*0.4;
	c+=(texture(frame,SCREEN_UV+d*.5).rgb+texture(frame,SCREEN_UV-d*.5).rgb)*.23;
	c+=(texture(frame,SCREEN_UV+d).rgb+texture(frame,SCREEN_UV-d).rgb)*.07;
	COLOR=vec4(c,1.);
}