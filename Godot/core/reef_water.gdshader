shader_type canvas_item;
uniform float swim_clock = 0.0;
uniform float lighting_time = 5.0;
uniform sampler2D next_scene;
void fragment() {
 // Travel across a cropped panorama, never mirror or wrap it.
 float phase = clamp(swim_clock/60.0,0.0,1.0);
 vec2 uv = vec2(UV.x*0.76+phase*0.23,UV.y*0.94+0.025);
 uv += vec2(sin(uv.y*24.0+swim_clock*1.6),cos(uv.x*20.0-swim_clock*1.2))*0.0035;
 vec4 reef = texture(TEXTURE,uv);
 vec4 forest = texture(next_scene,uv);
 float visit = smoothstep(16.0,23.0,swim_clock);
 vec4 scene = reef;
 scene.rgb=mix(scene.rgb,scene.rgb*vec3(1.12,.91,.87),smoothstep(15.0,22.0,lighting_time)*0.45);
 float night = smoothstep(35.0,42.0,lighting_time);
 scene.rgb = mix(scene.rgb,scene.rgb*vec3(0.36,0.48,0.85),night*0.7);
 float ripple = sin(UV.x*45.0+UV.y*20.0+swim_clock*1.7)*sin(UV.x*26.0-UV.y*34.0-swim_clock*1.2);
 scene.rgb += vec3(0.08,0.16,0.17)*pow(max(ripple,0.0),8.0)*(0.3+UV.y*0.7);
 COLOR = scene;
}

