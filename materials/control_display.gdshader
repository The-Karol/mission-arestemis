shader_type spatial;
render_mode unshaded;
uniform float channel=0.0;
void fragment(){
	vec2 p=UV;
	vec2 q=p*2.0-1.0;
	vec2 cell=abs(fract(p*vec2(14.0,8.0))-0.5);
	float grid=smoothstep(0.464,0.49,max(cell.x,cell.y));
	float signal;
	if(channel<2.0){
		q.x*=1.5;
		float globe=length(q)-0.70;
		float parallels=abs(fract((q.y+1.0)*4.2)-0.5);
		float meridian=abs(length(q*vec2(1.85,1.0))-0.70);
		signal=exp(-abs(globe)*90.0)+step(globe,0.0)*(exp(-parallels*28.0)+exp(-meridian*100.0))*0.4;
		signal+=exp(-abs(length((q+vec2(0.13,0.02))*vec2(0.77,1.5))-0.72)*95.0)*0.85;
	}else{
		float curve=0.25+0.33*p.x+0.13*sin(p.x*8.5+channel);
		signal=exp(-abs(p.y-curve)*170.0)+0.4*exp(-abs(p.y-0.19-0.055*sin(p.x*22.0+channel))*180.0);
	}
	float sweep=0.55+0.45*smoothstep(-0.035,0.0,fract(TIME*0.06+channel*0.2)-p.x);
	ALBEDO=vec3(0.018,0.047,0.068)+grid*vec3(0.018,0.07,0.092)+signal*vec3(0.29,0.72,0.84)*sweep;
}