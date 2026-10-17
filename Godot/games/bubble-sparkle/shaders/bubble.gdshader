shader_type canvas_item;
uniform float clock = 0.0;
uniform vec4 tint : source_color = vec4(0.4, 1.0, 0.85, 1.0);
uniform float visibility = 1.0;
void fragment() {
    vec2 p = (UV - 0.5) * 2.0;
    float r = length(p);
    float edge = 1.0 - smoothstep(0.77, 0.80, r);
    float sphere = sqrt(max(0.0, 1.0 - pow(r / 0.8, 2.0)));
    float rim = exp(-pow((r - 0.765) * 55.0, 2.0));
    float angle = atan(p.y, p.x);
    vec3 rainbow = 0.6 + 0.4 * cos(angle * 2.0 + clock * 0.55 + vec3(0.0, 2.1, 4.2));
    vec3 col = mix(tint.rgb * 0.3, tint.rgb, sphere * 0.65);
    col += rainbow * rim * 0.85;
    float shine = exp(-length((p - vec2(-0.28, -0.34)) * vec2(5.0, 9.0)) * 2.0);
    float crescent = exp(-pow((length(p - vec2(0.05, 0.08)) - 0.64) * 35.0, 2.0));
    crescent *= smoothstep(0.0, 0.45, -p.y) * smoothstep(-0.6, 0.05, -p.x);
    col += vec3(0.8, 0.98, 1.0) * (shine * 1.4 + crescent * 0.65);
    float inner = exp(-length(p - vec2(0.22, 0.34)) * 5.0);
    col += rainbow * inner * 0.22;
    float halo = exp(-max(r - 0.79, 0.0) * 18.0) * 0.16;
    COLOR = vec4(col, (edge * 0.88 + (1.0 - edge) * halo) * visibility);
}
