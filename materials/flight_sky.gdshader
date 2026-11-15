shader_type sky;
uniform float space_blend = 0.0;
float hash(vec3 p){return fract(sin(dot(p,vec3(17.13,45.71,91.3)))*43758.5453);}
void sky(){vec3 d=normalize(EYEDIR);vec3 day=mix(vec3(.73,.77,.77),vec3(.19,.39,.65),smoothstep(-.05,.8,d.y));float sun=pow(max(dot(d,normalize(vec3(-.5,.3,.4))),0.0),400.0);day+=vec3(1.0,.77,.45)*sun*2.0;vec3 grid=d*220.0;float star=step(.993,hash(floor(grid)))*pow(max(0.0,1.0-length(fract(grid)-.5)*2.0),3.0);vec3 night=vec3(.001,.003,.008)+vec3(.7,.82,1.0)*star*3.0;COLOR=mix(day,night,space_blend);}
