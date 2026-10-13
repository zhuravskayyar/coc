uniform sampler2D grass_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 grass_tint : source_color = vec4(0.74, 0.79, 0.62, 1.0);
uniform float checker_darkening : hint_range(0.0, 0.15) = 0.04;

vec3 field_patch(vec2 point, vec2 gradient_x, vec2 gradient_y) {
	// Only the opaque grass inside sprite 1; exclude its raised tile edges.
	vec2 source_uv = vec2(0.5 + (point.x - point.y) * 0.30,
		0.495 + (point.x + point.y - 1.0) * 0.25);
	return textureGrad(grass_texture, source_uv, gradient_x, gradient_y).rgb;
}

vec3 field_grass(vec2 point, float variant) {
	vec2 first = fract(point);
	vec2 second = fract(point + 0.5);
	// Unwrapped gradients prevent mipmaps from treating the repeat seam as
	// an enormous texture jump and pulling in the sprite's transparent edges.
	vec2 point_x = dFdx(point);
	vec2 point_y = dFdy(point);
	vec2 gradient_x = vec2((point_x.x - point_x.y) * 0.30, (point_x.x + point_x.y) * 0.25);
	vec2 gradient_y = vec2((point_y.x - point_y.y) * 0.30, (point_y.x + point_y.y) * 0.25);
	vec2 blend = smoothstep(vec2(0.0), vec2(0.2), first)
		* (1.0 - smoothstep(vec2(0.8), vec2(1.0), first));
	vec3 first_row = mix(field_patch(second, gradient_x, gradient_y), field_patch(vec2(first.x, second.y), gradient_x, gradient_y), blend.x);
	vec3 second_row = mix(field_patch(vec2(second.x, first.y), gradient_x, gradient_y), field_patch(first, gradient_x, gradient_y), blend.x);
	vec3 grass = mix(first_row, second_row, blend.y) * grass_tint.rgb;
	return grass * (1.0 - (1.0 - variant) * checker_darkening);
}
