shader_type canvas_item;
uniform sampler2D scene_color : hint_screen_texture, repeat_disable, filter_linear_mipmap;
void fragment() {
	vec3 room = textureLod(scene_color,SCREEN_UV,2.5).rgb;
	float edge=1.0-smoothstep(0.15,0.89,length(UV-vec2(0.5)));
	COLOR=vec4(room*vec3(0.39,0.41,0.39)*edge+vec3(0.012,0.025,0.022),1.0);
}
