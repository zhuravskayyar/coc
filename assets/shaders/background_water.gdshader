shader_type canvas_item;
render_mode unshaded;

uniform vec2 tile_size = vec2(96.0, 72.0);
uniform float field_center = 22.0;
uniform bool shore_sprite = false;
varying vec2 water_position;

void vertex() {
	water_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 grid = vec2(water_position.x / tile_size.x + water_position.y / tile_size.y,
		-water_position.x / tile_size.x + water_position.y / tile_size.y) + field_center;
	// The sea follows the full southwest edge without ending at a polygon corner.
	float coast = 54.3 + sin(grid.x * 0.24) * 0.22
		+ sin(grid.x * 0.53 + 0.9) * 0.16;
	float shore_distance = grid.y - coast;
	float depth = smoothstep(0.0, 14.0, shore_distance);
	vec3 water = mix(vec3(0.12, 0.58, 0.64), vec3(0.025, 0.30, 0.38), depth);
	float drift = TIME * 0.18;
	float ripple = sin(water_position.x * 0.019 + water_position.y * 0.027 + drift)
		* sin(water_position.y * 0.033 - water_position.x * 0.013 - drift * 0.8);
	water += ripple * 0.014 * (1.0 - depth * 0.7);
	float alpha = smoothstep(-0.35, 0.75, shore_distance);
	if (shore_sprite) {
		// Keep the land and surf; blend the outer water of each PNG into the sea.
		vec4 shore = texture(TEXTURE, UV);
		float outer_fade = 1.0 - smoothstep(2.8, 6.2, shore_distance);
		COLOR = vec4(shore.rgb, shore.a * outer_fade);
	} else {
		COLOR = vec4(water, alpha);
	}
}
