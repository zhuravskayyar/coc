shader_type canvas_item;
render_mode unshaded;

#include "res://assets/shaders/field_grass.gdshaderinc"
uniform vec2 tile_size = vec2(96.0, 72.0);
uniform float total_size = 50.0;
uniform float border_size = 3.0;
uniform float undergrowth_strength : hint_range(0.0, 1.0) = 0.0;
varying vec2 ground_position;

void vertex() {
	ground_position = VERTEX;
}

void fragment() {
	vec2 grid = vec2(ground_position.x / tile_size.x + ground_position.y / tile_size.y,
		-ground_position.x / tile_size.x + ground_position.y / tile_size.y)
		+ total_size * 0.5 - border_size;
	float field_size = total_size - border_size * 2.0;
	float outside = max(max(-grid.x, -grid.y),
		max(grid.x - field_size, grid.y - field_size));
	float variation = sin(grid.x * 0.63 + grid.y * 0.21)
		* sin(grid.y * 0.71 - grid.x * 0.18);
	float transition = smoothstep(0.0, 2.8, outside + variation * 0.35);
	float distant = smoothstep(3.0, 9.0, outside + variation * 0.8);
	vec2 cell = floor(grid);
	float variant = mod(cell.x + cell.y, 2.0);
	vec3 grass = field_grass(grid, mix(variant, 1.0, transition));
	// A light clearing gradually gives way to darker grass under the clusters.
	vec3 tint = mix(vec3(1.025, 1.02, 0.96), vec3(0.90, 0.95, 0.87), distant);
	grass *= mix(vec3(1.0), tint * (1.0 + variation * 0.025), transition);
	// Only the background material enables the denser grass beneath the shrubs.
	float fringe_distance = outside + variation * 0.65;
	float fringe = smoothstep(1.2, 3.1, fringe_distance)
		* (1.0 - smoothstep(6.0, 10.0, fringe_distance));
	vec3 wild_grass = field_grass(grid * 1.9, 1.0) * vec3(0.88, 0.97, 0.84);
	grass = mix(grass, wild_grass, fringe * undergrowth_strength * 0.65);
	COLOR = vec4(grass, 1.0);
}
