shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform float curvature = 4.0;
uniform float vignette_multiplier = 1.0;
uniform float aberration_amount = 1.5;
uniform float scanlines_intensity = 0.2;
uniform float scanlines_count = 720.0;
uniform float brightness = 1.2;

vec2 curve(vec2 uv) {
	uv = (uv - 0.5) * 2.0;
	uv.x *= 1.0 + pow((abs(uv.y) / curvature), 2.0);
	uv.y *= 1.0 + pow((abs(uv.x) / curvature), 2.0);
	uv = (uv / 2.0) + 0.5;
	return uv;
}

void fragment() {
	vec2 uv = curve(SCREEN_UV);
	
	// Chromatic Aberration
	float ca = aberration_amount * 0.003;
	float r_color = texture(SCREEN_TEXTURE, uv + vec2(ca, 0.0)).r;
	float g_color = texture(SCREEN_TEXTURE, uv).g;
	float b_color = texture(SCREEN_TEXTURE, uv - vec2(ca, 0.0)).b;
	vec3 color = vec3(r_color, g_color, b_color) * brightness;
	
	// Scanlines
	float s = sin(uv.y * scanlines_count * 3.14159);
	s = (s * 0.5 + 0.5) * 0.9 + 0.1;
	color = mix(color, color * s, scanlines_intensity);
	
	// Vignette
	float r = length(uv - vec2(0.5, 0.5));
	float vignette = smoothstep(0.8, 0.2, r * vignette_multiplier);
	color *= vignette;
	
	// Cutoff for areas outside the curved screen
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		color = vec3(0.0);
	}
	
	COLOR = vec4(color, 1.0);
}
