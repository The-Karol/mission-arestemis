shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform vec2 origin=vec2(0.0);
uniform vec2 extent=vec2(1.0);
uniform vec2 flare_center=vec2(.5,.7);
uniform float glare=0.0;
float hash(vec2 p){return fract(sin(dot(p,vec2(12.9898,78.233)))*43758.5453);}
void fragment(){vec2 uv=UV;vec2 p=uv*2.0-1.0;p*=1.0+.035*dot(p,p);vec2 q=p*.5+.5;vec2 s=origin+q*extent;float wobble=sin(q.y*510.0+TIME*7.0)*.00065;vec3 c; c.r=texture(screen_tex,s+vec2(.0014+wobble,0)).r;c.g=texture(screen_tex,s).g;c.b=texture(screen_tex,s-vec2(.0014,0)).b;float scan=.85+.15*sin(q.y*570.0*3.14159);float grain=(hash(floor(q*vec2(720,540))+floor(TIME*24.0))-.5)*.065;c*=scan;c+=grain;c=mix(c,vec3(dot(c,vec3(.299,.587,.114))),.17);float vignette=clamp(1.0-.28*dot(p,p),.0,1.0);c*=vignette;float d=length((q-flare_center)*vec2(1.333,1));c+=vec3(1.0,.81,.51)*glare*(exp(-d*8.0)*.8+exp(-d*35.0)*2.0);float mask=step(0.,q.x)*step(q.x,1.)*step(0.,q.y)*step(q.y,1.);COLOR=vec4(c*mask,1.0);}
