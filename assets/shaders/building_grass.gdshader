shader_type canvas_item;
render_mode unshaded;

#include "res://assets/shaders/field_grass.gdshaderinc"

uniform vec2 patch_size_in_cells = vec2(5.0);
uniform bool soil_enabled = false;
uniform vec4 soil_color : source_color = vec4(0.9, 0.67, 0.36, 1.0);
varying vec2 ground_position;

float grass_hash(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	ground_position = VERTEX;
}

void fragment() {
	// Reuse the field texture with finer detail and a denser green tint.
	vec3 grass = field_grass(UV * patch_size_in_cells * 1.8, 1.0);

	// Fade the entire outer half-cell band instead of leaving a sharp green square.
	vec2 edge_cells = min(UV, vec2(1.0) - UV) * patch_size_in_cells;
	float edge_distance = min(edge_cells.x, edge_cells.y);
	float alpha = smoothstep(0.0, 0.5, edge_distance);
	if (soil_enabled) {
		// Continue the PNG's soil color beneath its edge, then blend into grass.
		// This ground layer never fades or masks the wooden palisade itself.
		float outside_soil = 0.5 - edge_distance;
		float grain = grass_hash(floor(ground_position / 3.0));
		float soil_blend = 1.0 - smoothstep(-0.04, 0.22, outside_soil);
		vec3 soil = soil_color.rgb * mix(0.96, 1.04, grain);
		grass = mix(grass, soil, soil_blend);
	}
	COLOR = vec4(grass, alpha);
}
