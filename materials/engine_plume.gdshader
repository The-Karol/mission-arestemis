shader_type spatial;
render_mode unshaded,blend_add,cull_back,depth_draw_never,shadows_disabled;
uniform float core = 0.0;
uniform float phase = 0.0;
varying float axial;
void vertex(){
 axial=clamp(0.5-VERTEX.y,0.0,1.0);
 float wave=sin(axial*34.0-0.5)*exp(-axial*2.8);
 float width=(0.40+0.59*sin(pow(axial,0.76)*3.14159))*(1.0-0.78*axial)*(1.0+0.14*wave);
 VERTEX.xz*=width*(1.0-core*0.45);
 VERTEX.y=-axial*(9.6-core*3.1);
}
void fragment(){
 float a=axial;
 float shock=pow(0.5+0.5*cos(35.0*a),4.0)*exp(-a*3.0);
 float stream=sin(UV.x*81.68+sin(a*16.0-TIME*9.0+phase)*1.8)*0.07;
 float fade=(1.0-smoothstep(0.25,1.0,a))*smoothstep(0.0,0.018,a);
 float edge=pow(max(0.0,dot(normalize(NORMAL),normalize(VIEW))),0.55);
 vec3 gas=mix(vec3(0.42,0.56,1.0),vec3(1.0,0.34,0.065),smoothstep(0.01,0.35,a));
 ALBEDO=mix(gas,vec3(1.0,0.93,0.70),core*0.80+shock*0.18);
 ALPHA=fade*edge*(0.53+core*0.48+shock*0.36+stream);
}
