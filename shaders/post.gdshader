// Post-processing: coloured point lights over a dim ambient, soft glow around
// bright glyphs, faint scanlines and a vignette. Bright glyphs (sparks, eyes,
// projectiles) stay visible in the dark.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float radius = 1.6;
uniform float glow = 0.75;
uniform float scanlines = 0.05;
uniform float vignette = 0.35;
uniform float lighting = 1.0;
uniform float ambient = 0.5;
uniform int light_count = 0;
uniform vec4 light_pos[32];
uniform vec4 light_col[32];

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

	vec2 frag = uv / SCREEN_PIXEL_SIZE;
	vec3 light = vec3(ambient);
	for (int i = 0; i < 32; i++) {
		if (i >= light_count) {
			break;
		}
		float d = distance(frag, light_pos[i].xy) / max(light_pos[i].z, 1.0);
		float f = clamp(1.0 - d, 0.0, 1.0);
		light += light_col[i].rgb * f * f * 1.3;
	}
	light = min(light, vec3(1.6));
	float lum = dot(base, vec3(0.299, 0.587, 0.114));
	vec3 lit = base * light;
	lit = max(lit, base * smoothstep(0.5, 0.95, lum));
	vec3 c = mix(base, lit, lighting);
	c += max(blur * mix(1.0, light.r * 0.5 + 0.5, lighting) - 0.04, vec3(0.0)) * glow;

	float s = 0.5 + 0.5 * sin(FRAGCOORD.y * 3.14159);
	c *= 1.0 - scanlines * s;
	vec2 v = uv - 0.5;
	c *= clamp(1.0 - dot(v, v) * vignette * 1.6, 0.0, 1.0);
	COLOR = vec4(c, 1.0);
}
