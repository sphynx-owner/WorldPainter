shader_type spatial;

uniform sampler3D world_paint_texture;

void fragment() {
	vec4 world_position = INV_VIEW_MATRIX * INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2. - 1., FRAGCOORD.z, 1.0);
	world_position.xyz /= world_position.w;
}

//void light() {
	// Called for every pixel for every light affecting the material.
	// Uncomment to replace the default light processing function with this one.
//}
