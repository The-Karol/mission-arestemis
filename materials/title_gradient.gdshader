shader_type canvas_item;
uniform float title_top = 0.055;
uniform float title_height = 0.17;
void fragment(){
 vec4 ink=COLOR;
 // Label fill is orange; keep the ivory outline and dark drop shadow intact.
 if(ink.r>ink.b*1.45 && ink.r>0.12){
  float vertical=clamp((SCREEN_UV.y-title_top)/title_height,0.0,1.0);
  float wave=sin(SCREEN_UV.x*7.0+vertical*2.5-TIME*0.85);
  float blend=clamp(vertical+wave*0.10,0.0,1.0);
  vec3 orange=mix(vec3(0.43,0.12,0.025),vec3(0.88,0.72,0.46),smoothstep(0.0,0.9,blend));
  float sheen=pow(max(0.0,sin(SCREEN_UV.x*5.5-vertical*1.5-TIME*0.6)),12.0)*0.15;
  ink.rgb=mix(orange,vec3(0.96,0.85,0.62),sheen);
 }
 COLOR=ink;
}
