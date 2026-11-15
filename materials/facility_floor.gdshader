shader_type spatial;
uniform sampler2D brushed : repeat_enable,filter_linear_mipmap;
varying vec3 world_position;
void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
    vec2 tile = abs(fract(world_position.xz * 0.5) - 0.5);
    float seam = smoothstep(0.496-fwidth(world_position.x)*0.15, 0.499, max(tile.x, tile.y));
    ALBEDO = mix(vec3(0.23, 0.26, 0.27), vec3(0.14, 0.17, 0.18), seam * 0.48);
    float finish = texture(brushed,world_position.xz*0.75).r;
    ALBEDO *= 0.78+finish*0.35;
    vec2 plate=floor(world_position.xz*0.5+0.0001);
    float lot=fract(sin(dot(plate,vec2(19.39,67.13)))*381.17);
    float scuff=texture(brushed,world_position.xz*vec2(0.19,3.8)).g;
    float joint=min(1.0,seam);
    ALBEDO*=0.965+lot*0.07;
    ROUGHNESS=clamp(0.17+finish*0.20+scuff*0.10+joint*0.17,0.18,0.7);
    NORMAL=normalize(NORMAL+TANGENT*(finish-0.5)*0.025);
    METALLIC = 0.27;
}
