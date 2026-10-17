shader_type canvas_item;
uniform float clock = 0.0;
uniform bool motion = true;
varying vec4 tint;
void vertex() { tint = COLOR; }
void fragment() {
	vec2 uv = UV;
	if (motion) {
		float tail = 1.0 - smoothstep(0.08, 0.42, UV.x);
		uv.y += sin(clock * 8.0 + UV.x * 9.0) * tail * 0.045;
		float fin = exp(-18.0 * distance(UV, vec2(0.5, 0.61)));
		uv.x += sin(clock * 10.0) * fin * 0.028;
		float edge = smoothstep(0.15, 0.4, abs(UV.y - 0.5));
		uv.y += sin(clock * 6.0 + UV.x * 12.0) * edge * 0.008;
	}
	COLOR = tint * texture(TEXTURE, clamp(uv, vec2(0.0), vec2(1.0)));
}
