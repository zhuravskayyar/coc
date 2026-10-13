shader_type canvas_item;
render_mode unshaded;

uniform vec2 tile_size = vec2(96.0, 72.0);
varying vec2 ground_position;

void vertex() {
	ground_position = VERTEX;
}

void fragment() {
	vec3 pixel = texture(TEXTURE, UV).rgb;
	float brightest = max(pixel.r, max(pixel.g, pixel.b));
	float darkest = min(pixel.r, min(pixel.g, pixel.b));
	float saturation = (brightest - darkest) / max(brightest, 0.001);
	// Soil is less saturated than the amber poles. Also soften the dark ground outline.
	float soil = 1.0 - smoothstep(0.76, 0.86, saturation);
	float outline = 1.0 - smoothstep(0.25, 0.40, brightest);
	float ground_mask = max(soil, outline) * smoothstep(-2.0, 4.0, ground_position.y);
	vec2 grid = vec2(ground_position.x / tile_size.x + ground_position.y / tile_size.y,
		-ground_position.x / tile_size.x + ground_position.y / tile_size.y);
	float edge_distance = 0.5 - max(abs(grid.x), abs(grid.y));
	float edge_alpha = smoothstep(-0.045, 0.14, edge_distance);
	COLOR.a *= mix(1.0, edge_alpha, ground_mask);
}
