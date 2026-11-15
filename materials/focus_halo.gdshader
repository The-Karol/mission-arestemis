shader_type spatial;
render_mode unshaded, blend_add, cull_front, depth_draw_never, shadows_disabled;
uniform float thickness = 0.02;
void vertex() { VERTEX += NORMAL*thickness; }
void fragment() { ALBEDO=vec3(0.85,0.93,1.0); ALPHA=0.20; }
