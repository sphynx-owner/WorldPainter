shader_type spatial;

render_mode unshaded, cull_back;

uniform sampler2D screen_texture : hint_screen_texture;
uniform sampler2D depth_texture : hint_depth_texture;

uniform sampler3D world_paint_texture : repeat_disable;

uniform ivec3 map_size;

uniform vec3 map_extents;

varying vec3 normal;

void vertex() {
	normal = NORMAL;
}

void fragment() {
	float depth = texture(depth_texture, SCREEN_UV).x;
	
	float fragment_depth = FRAGCOORD.z;
	vec4 fragment_world_position = INV_VIEW_MATRIX * INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2. - 1., fragment_depth, 1.);
	fragment_world_position.xyz /= fragment_world_position.w;

	vec3 camera_fragment_offset = CAMERA_POSITION_WORLD - fragment_world_position.xyz;
	float from_outside = step(0, dot(camera_fragment_offset, normal));
	
	float final_depth = mix(depth, FRAGCOORD.z, from_outside);
	vec4 world_position = INV_VIEW_MATRIX * INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2. - 1., final_depth, 1.);
	world_position.xyz /= world_position.w;

	vec3 truncated_world_position = vec3((world_position.xyz + map_extents / 2.) / map_extents);

	vec4 paint_texture_sample = texture(world_paint_texture, truncated_world_position);
	
	ALBEDO = vec3(normal);//texture(screen_texture, SCREEN_UV).xyz + paint_texture_sample.xyz;
	DEPTH = final_depth;
}
