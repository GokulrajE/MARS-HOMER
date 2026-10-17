shader_type canvas_item;
uniform float clock = 0.0;
uniform bool motion = true;
uniform bool rush = false;
varying vec4 tint;
void vertex() { tint = COLOR; }
void fragment() {
	vec2 uv = UV;
	if (motion) {
		float swim_clock = clock * (rush ? 1.7 : 1.0);
		float tail = 1.0 - smoothstep(0.05, 0.5, UV.x);
		uv.y += sin(swim_clock * 6.0 + UV.x * 7.0) * tail * 0.055;
		float fins = smoothstep(0.55, 0.85, UV.y) * sin(UV.x * 3.14159);
		uv.x += sin(swim_clock * 6.0 + 1.2) * fins * 0.012;
	}
	vec4 body = tint * texture(TEXTURE, clamp(uv, vec2(0.0), vec2(1.0)));
	// A constant warm silhouette distinguishes the rival without flashing.
	vec2 spread = vec2(0.012, 0.018);
	float rim = 0.0;
	for (int i = 0; i < 8; i++) {
		float angle = float(i) * 0.785398;
		rim += texture(TEXTURE, clamp(uv + vec2(cos(angle), sin(angle)) * spread, vec2(0.0), vec2(1.0))).a;
	}
	rim = clamp(rim * 0.23, 0.0, 1.0) * (1.0 - body.a) * 0.85;
	float alpha = body.a + rim;
	vec3 glow = vec3(1.0, 0.73, 0.32);
	COLOR = vec4((body.rgb * body.a + glow * rim) / max(alpha, 0.001), alpha);
}
