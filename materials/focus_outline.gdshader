shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;
uniform float thickness = 0.012;
void vertex() { VERTEX += NORMAL * thickness; }
void fragment() { ALBEDO = vec3(0.92,0.97,1.0); EMISSION=vec3(0.35); }
