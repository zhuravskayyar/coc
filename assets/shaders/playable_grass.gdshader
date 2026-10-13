shader_type canvas_item;
render_mode unshaded;

#include "res://assets/shaders/field_grass.gdshaderinc"

varying float grass_variant;

void vertex() {
	grass_variant = COLOR.r;
}

void fragment() {
	// Preserve the first sprite's color and grass detail. Only alternating
	// cells receive a small darkening; the texture itself stays the same.
	COLOR = vec4(field_grass(UV, grass_variant), 1.0);
}
