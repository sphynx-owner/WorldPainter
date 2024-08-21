shader_type spatial;

uniform sampler3D world_paint_texture;

uniform ivec3 map_size;

uniform vec3 map_extents;

void fragment() {
	vec4 world_position = INV_VIEW_MATRIX * INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2. - 1., FRAGCOORD.z, 1.);
	world_position.xyz /= world_position.w;
	
	vec3 truncated_world_position = vec3((world_position.xyz + vec3(map_extents) / 2.) * vec3(map_size) / map_extents);
	
	ALBEDO = vec3(texture(world_paint_texture, truncated_world_position).x);
}

//void light() {
	// Called for every pixel for every light affecting the material.
	// Uncomment to replace the default light processing function with this one.
//}
