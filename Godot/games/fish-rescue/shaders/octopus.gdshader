shader_type canvas_item;
uniform float clock = 0.0;
uniform bool motion = true;
void fragment() {
	vec2 uv = UV;
	float tentacles = smoothstep(0.42, 0.9, UV.y);
	if (motion) {
		uv.x += sin(UV.y * 19.0 + clock * 3.2) * tentacles * 0.018;
		uv.y += sin(UV.x * 21.0 - clock * 2.5) * tentacles * 0.009;
	}
	COLOR = texture(TEXTURE, uv);
}
