shader_type canvas_item;
uniform float swim_clock = 0.0;
uniform float lighting_time = 5.0;
// Per-trial village, woodland and sky scenery, with a fixed lighting preset.
uniform int look = 0;
void fragment() {
 float zoom = look == 2 ? 0.8 : 1.0;
 float start = look == 2 ? 0.10 : 0.0;
 float ux = UV.x;
 float scroll = clamp(swim_clock / 60.0, 0.0, 1.0) * 0.25;
 vec2 uv = vec2(ux * 0.74 * zoom + start + scroll, (UV.y * 0.96 + 0.02) * zoom + (1.0 - zoom) * 0.35);
 vec4 scene = texture(TEXTURE, clamp(uv, vec2(0.0), vec2(1.0)));
 float evening = smoothstep(15.0, 22.0, lighting_time);
 float night = smoothstep(35.0, 42.0, lighting_time);
 float sky = 1.0 - smoothstep(0.15, 0.7, UV.y);
 vec3 daylight = mix(scene.rgb, vec3(0.48, 0.73, 0.91) * (0.7 + 0.3 * scene.r), sky * 0.65);
 scene.rgb = mix(daylight, scene.rgb, evening);
 if (look == 1) {
  // Cool, hazy morning.
  scene.rgb = mix(scene.rgb, vec3(0.70, 0.86, 0.95) * (0.65 + 0.35 * scene.g), sky * 0.5);
  scene.rgb *= vec3(0.86, 1.0, 1.08);
 } else if (look == 2) {
  // Overcast monsoon: desaturated, darker, with a heavy grey sky.
  float grey = dot(scene.rgb, vec3(0.3, 0.59, 0.11));
  scene.rgb = mix(vec3(grey), scene.rgb, 0.5);
  scene.rgb = mix(scene.rgb, vec3(0.52, 0.58, 0.64) * (0.8 + 0.2 * grey), sky * 0.75);
  scene.rgb *= vec3(0.82, 0.90, 1.0) * 0.9;
 }
 scene.rgb = mix(scene.rgb, scene.rgb * vec3(0.45, 0.50, 0.75), night);
 COLOR = scene;
}
