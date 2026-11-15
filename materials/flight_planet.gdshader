shader_type spatial;
render_mode specular_schlick_ggx;
uniform vec3 ocean : source_color = vec3(0.025,0.13,0.26);
uniform vec3 land : source_color = vec3(0.19,0.27,0.18);
uniform bool terrestrial = true;
float hash(vec3 p){return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);}
float noise(vec3 p){vec3 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);}
void fragment(){vec3 p=vec3(sin(UV.x*6.283)*sin(UV.y*3.1416),cos(UV.y*3.1416),cos(UV.x*6.283)*sin(UV.y*3.1416));float n=noise(p*3.5)*.6+noise(p*9.0)*.27+noise(p*27.0)*.13;vec3 c=mix(ocean,land,smoothstep(.48,.54,n));float cloud=smoothstep(.57,.72,noise(p*10.0+vec3(TIME*.002,0,0))*.7+noise(p*28.0)*.3);if(terrestrial){c=mix(c,vec3(.86,.9,.93),cloud*.85);c=mix(c,vec3(.87,.9,.94),smoothstep(.88,.98,abs(p.y)));}else{c=land*(.65+n*.65);}ALBEDO=c;ROUGHNESS=.83;float rim=pow(1.0-max(dot(NORMAL,VIEW),0.0),3.0);EMISSION=vec3(.08,.28,.52)*rim*(terrestrial?.7:.05);}
