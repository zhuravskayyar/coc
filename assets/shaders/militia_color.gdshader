shader_type canvas_item;
render_mode unshaded;

uniform float brightness_gamma : hint_range(0.5, 1.5) = 1.05;
uniform float saturation : hint_range(1.0, 2.5) = 1.8;
uniform float contrast : hint_range(1.0, 1.6) = 1.25;

void fragment() {
	// Restore color separation and darker shading instead of whitening the midtones.
	vec3 pixel = pow(max(COLOR.rgb, vec3(0.0)), vec3(brightness_gamma));
	float luminance = dot(pixel, vec3(0.2126, 0.7152, 0.0722));
	vec3 vivid = mix(vec3(luminance), pixel, saturation);
	COLOR.rgb = clamp((vivid - vec3(0.5)) * contrast + vec3(0.5), vec3(0.0), vec3(1.0));
}
