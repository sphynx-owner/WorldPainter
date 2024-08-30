shader_type spatial;

render_mode unshaded, cull_disabled;

uniform sampler2D screen_texture : hint_screen_texture;
uniform sampler2D depth_texture : hint_depth_texture;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	ALBEDO = texture(screen_texture, SCREEN_UV).xyz + vec3(0.1, 0, 0);
	DEPTH = texture(depth_texture, SCREEN_UV).x;
}

//void light() {
	// Called for every pixel for every light affecting the material.
	// Uncomment to replace the default light processing function with this one.
//}
