// The last pass of the picture, over everything (the lit world and the HUD
// and menus on top of it). The game is drawn at a low resolution, so every
// pixel is already one pixel of the picture (pixel = 1); with pixel > 1 the
// screen would be cut into blocks of that many pixels, each filled from what
// lies inside it (the brightest tap counts most, so thin strokes survive). Then
// - graded: a little washed out, bruised violet in the shade and a sickly
//   warm in the light, with the darks pressed down so the night is really dark;
// - roughened by a faint grain that changes a dozen times a second;
// - cut to a few steps per channel with a fixed 4x4 ordered dither between
//   them (none in the deepest dark, or the night turns into a screen door).
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float pixel = 1.0;
uniform float levels = 12.0;
uniform float dither = 0.9;
uniform float grain = 0.03;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float bayer(ivec2 p) {
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[(p.y % 4) * 4 + (p.x % 4)]) + 0.5) / 16.0;
}

void fragment() {
	vec2 cell = floor(FRAGCOORD.xy / pixel);
	// one tap per pixel at low resolution, else 2x2 (small) or 3x3 (big)
	int n = pixel <= 1.0 ? 1 : (pixel <= 3.0 ? 2 : 3);
	vec3 sum = vec3(0.0);
	vec3 hi = vec3(0.0);
	for (int k = 0; k < n * n; k++) {
		vec2 o = vec2(float(k % n) + 0.5, float(k / n) + 0.5) / float(n);
		vec3 t = texture(screen_tex, (cell + o) * pixel * SCREEN_PIXEL_SIZE).rgb;
		sum += t;
		hi = max(hi, t);
	}
	vec3 c = mix(sum / float(n * n), hi, 0.65);
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, 0.82);
	// shade bruised toward violet and old blood, light a sickly warm
	c *= mix(vec3(0.98, 0.82, 0.96), vec3(1.08, 0.95, 0.8), smoothstep(0.08, 0.5, l));
	c = max(c - 0.02, vec3(0.0)) * 1.14;
	// a gentle S-curve: deeper shadows, the same highlights
	c = mix(c, c * c * (3.0 - 2.0 * c), 0.35);
	c += (hash(cell + mod(floor(TIME * 12.0), 61.0) * vec2(17.3, 5.1)) - 0.5) * grain;
	float b = (bayer(ivec2(cell)) - 0.5) * dither * smoothstep(0.02, 0.12, l);
	COLOR = vec4(floor(c * levels + 0.5 + b) / levels, 1.0);
}
