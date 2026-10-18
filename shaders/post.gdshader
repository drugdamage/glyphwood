// Post-processing: soft glow around bright glyphs, faint scanlines and a vignette.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float radius = 1.6;
uniform float glow = 0.75;
uniform float scanlines = 0.05;
uniform float vignette = 0.35;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE * radius;
	vec3 base = texture(screen_tex, uv).rgb;
	vec3 acc = vec3(0.0);
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.7853982;
		vec2 d = vec2(cos(a), sin(a));
		acc += texture(screen_tex, uv + d * px * 1.5).rgb;
		acc += texture(screen_tex, uv + d * px * 4.0).rgb * 0.6;
	}
	vec3 blur = acc / 12.8;
	vec3 c = base + max(blur - 0.04, vec3(0.0)) * glow;
	float s = 0.5 + 0.5 * sin(FRAGCOORD.y * 3.14159);
	c *= 1.0 - scanlines * s;
	vec2 v = uv - 0.5;
	c *= clamp(1.0 - dot(v, v) * vignette * 1.6, 0.0, 1.0);
	COLOR = vec4(c, 1.0);
}
