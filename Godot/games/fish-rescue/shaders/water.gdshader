shader_type canvas_item;
uniform float clock = 0.0;
uniform bool motion = true;
uniform float night = 0.0;
uniform float saturation = 0.42;
uniform float ambience = 0.6;
void fragment() {
	// Only the peripheral scenery sways. The rescue zone stays anchored.
	float border = smoothstep(0.22, 0.49, max(abs(UV.x - 0.5), abs(UV.y - 0.45)));
	float t = motion ? clock : 0.0;
	vec2 uv = UV;
	if (motion) {
		uv += vec2(sin(UV.y * 14.0 + t * 0.32), sin(UV.x * 12.0 - t * 0.27)) * border * 0.0018 * ambience;
	}
	// Soft detail and compressed highlights reduce competition with the fish.
	vec2 soften = TEXTURE_PIXEL_SIZE * 1.2;
	vec4 base = texture(TEXTURE, uv) * 0.5;
	base += texture(TEXTURE, uv + vec2(soften.x, 0.0)) * 0.125;
	base += texture(TEXTURE, uv - vec2(soften.x, 0.0)) * 0.125;
	base += texture(TEXTURE, uv + vec2(0.0, soften.y)) * 0.125;
	base += texture(TEXTURE, uv - vec2(0.0, soften.y)) * 0.125;
	float luminance = dot(base.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 calm = mix(vec3(luminance), base.rgb, saturation);
	calm = (calm - 0.5) * 0.78 + 0.43;
	calm = mix(calm, vec3(0.17, 0.34, 0.38), 0.14);
	float caustic = sin(UV.x * 25.0 + UV.y * 17.0 + t * 0.25) * sin(UV.x * 14.0 - UV.y * 21.0 - t * 0.19);
	float ray = pow(max(0.0, sin(UV.x * 18.0 + UV.y * 3.0 + t * 0.07)), 8.0) * (1.0 - UV.y);
	float light = (caustic * 0.025 + ray * 0.045) * ambience;
	vec3 lighting = mix(vec3(0.9, 0.98, 1.0), vec3(0.25, 0.4, 0.61), night);
	COLOR = vec4(calm * lighting * (1.0 + light), base.a);
}
