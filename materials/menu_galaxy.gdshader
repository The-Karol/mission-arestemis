shader_type canvas_item;
uniform mat3 sky_basis;
uniform vec2 lens=vec2(1.7778,0.36);
uniform sampler3D nebula_volume : repeat_enable,filter_linear;

float hash(vec3 p){
	p=fract(p*vec3(.1031,.1030,.0973));
	p+=dot(p,p.yxz+33.33);
	return fract((p.x+p.y)*p.z);
}
// Stars live on a cube surrounding the camera. Measure their angular distance
// in world space, so each point stays circular even when the camera turns.
float star_face(vec3 ray, int axis, float grid, float density, float brightness, float pixel_angle){
 float facing=axis==0?abs(ray.x):(axis==1?abs(ray.y):abs(ray.z));
 float dominant=max(max(abs(ray.x),abs(ray.y)),abs(ray.z));
 if(facing<dominant-.025)return 0.;
 vec2 projected=(axis==0?ray.yz:(axis==1?ray.xz:ray.xy))/facing;
 vec2 cell=floor((projected*.5+.5)*grid);
 float side=sign(axis==0?ray.x:(axis==1?ray.y:ray.z));
 float total=0.;
 for(int y=-1;y<=1;y++){
  for(int x=-1;x<=1;x++){
   vec2 id=cell+vec2(float(x),float(y));
   if(any(lessThan(id,vec2(0.)))||any(greaterThanEqual(id,vec2(grid))))continue;
   vec3 seed=vec3(id,float(axis)*53.+side*17.+grid);
   float chance=hash(seed);
   if(chance<1.-density)continue;
   vec2 jitter=vec2(hash(seed+11.7),hash(seed+29.3));
   vec2 uv=((id+.18+jitter*.64)/grid)*2.-1.;
   vec3 direction=normalize(axis==0?vec3(side,uv.x,uv.y):(axis==1?vec3(uv.x,side,uv.y):vec3(uv.x,uv.y,side)));
   float distance_px=length(direction-ray)/max(pixel_angle,.00001);
   float intensity=hash(seed+81.);
   float radius=mix(.52,1.05,intensity*intensity);
   float core=1.-smoothstep(max(0.,radius-.45),radius+.45,distance_px);
   float halo=exp(-distance_px*distance_px/2.8)*.055*step(.87,intensity);
   total+=(core+halo)*mix(.25,1.,intensity)*brightness;
  }
 }
 return total;
}
float star_layer(vec3 ray,float grid,float density,float brightness,float pixel_angle){
 return star_face(ray,0,grid,density,brightness,pixel_angle)+star_face(ray,1,grid,density,brightness,pixel_angle)+star_face(ray,2,grid,density,brightness,pixel_angle);
}
void fragment(){
	vec3 ray=normalize(sky_basis*vec3((UV.x*2.-1.)*lens.x*lens.y,(1.-UV.y*2.)*lens.y,-1.));
	float pixel_angle=max(length(dFdx(ray)),length(dFdy(ray)));
	float star=star_layer(ray,180.,.055,1.05,pixel_angle);
	star+=star_layer(ray,340.,.025,.45,pixel_angle);
	// Sample a baked, seamless 3D field along the world-space viewing direction.
	// Domain warping breaks up round noise cells; thin dust lanes interrupt the glow.
	vec3 p=ray*.88+vec3(.17,.39,.61);
	vec3 warp=vec3(texture(nebula_volume,p*.36).r,
	 texture(nebula_volume,p*.36+vec3(.31,.17,.43)).r,
	 texture(nebula_volume,p*.36+vec3(.63,.51,.29)).r)-.5;
	p+=warp*.32;
	float broad=texture(nebula_volume,p*.48).r;
	float middle=texture(nebula_volume,p*1.16+vec3(.23,.4,.57)).r;
	float fine=texture(nebula_volume,p*3.1+vec3(.49,.13,.71)).r;
	float veil=broad*.48+middle*.35+fine*.17;
	float latitude=dot(ray,normalize(vec3(.83,.12,-.47)))+(broad-.5)*.23;
	float band=exp(-latitude*latitude*9.);
	float density=pow(smoothstep(.27,.79,veil),1.45)*band;
	float dust=smoothstep(.43,.72,texture(nebula_volume,p*1.7+vec3(.67,.25,.1)).r);
	float emission=density*mix(1.,.28,dust);
	vec3 tint=mix(vec3(.075,.085,.20),vec3(.23,.072,.29),smoothstep(.35,.65,middle));
	vec3 backdrop=vec3(.003,.005,.010)+tint*emission*.8;
	COLOR=vec4((backdrop+star*vec3(.92,.94,1.)*(1.-dust*density*.45))*(1.-.23*length(UV-.5)),1.);
}