shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx, shadows_disabled;

uniform vec4 albedo : source_color;
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_enable;

uniform float roughness : hint_range(0.0, 1.0);
uniform sampler2D texture_metallic : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec4 metallic_texture_channel;
uniform sampler2D texture_roughness : hint_roughness_r, filter_linear_mipmap, repeat_enable;

uniform float specular : hint_range(0.0, 1.0, 0.01);
uniform float metallic : hint_range(0.0, 1.0, 0.01);

uniform vec3 uv1_scale;
uniform vec3 uv1_offset;
uniform vec3 uv2_scale;
uniform vec3 uv2_offset;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;

uniform sampler3D world_paint_texture : repeat_disable;
uniform vec3 mesh_extents = vec3(1);

vec3 get_world(vec3 ndc, mat4 inverse_matrix){
	vec4 world_position = inverse_matrix * vec4(ndc, 1.);
	world_position.xyz /= world_position.w;
	return world_position.xyz;
}
// from https://www.shadertoy.com/view/fsVczR
vec3 get_normal(vec2 uv, vec2 texel_size, mat4 inverse_matrix){
	float c0 = texture(depth_texture, uv).x;
	float l2 = texture(depth_texture, uv - texel_size * vec2(2, 0)).x;
	float l1 = texture(depth_texture, uv - texel_size * vec2(1, 0)).x;
	float r1 = texture(depth_texture, uv + texel_size * vec2(1, 0)).x;
	float r2 = texture(depth_texture, uv + texel_size * vec2(2, 0)).x;
	float b2 = texture(depth_texture, uv - texel_size * vec2(0, 2)).x;
	float b1 = texture(depth_texture, uv - texel_size * vec2(0, 1)).x;
	float t1 = texture(depth_texture, uv + texel_size * vec2(0, 1)).x;
	float t2 = texture(depth_texture, uv + texel_size * vec2(0, 2)).x;
	
	float dl = abs(l1 * l2 / (2.0 * l2 - l1) - c0);
	float dr = abs(r1 * r2 / (2.0 * r2 - r1) - c0);
	float db = abs(b1 * b2 / (2.0 * b2 - b1) - c0);
	float dt = abs(t1 * t2 / (2.0 * t2 - t1) - c0);
	
	vec3 ce = get_world(vec3(uv * 2. - 1., c0), inverse_matrix);
	
	vec3 dpdx = (dl < dr) ? ce - get_world(vec3((uv - texel_size * vec2(1, 0)) * 2. - 1., l1), inverse_matrix) 
	: - ce + get_world(vec3((uv + texel_size * vec2(1, 0)) * 2. - 1., r1), inverse_matrix);
	vec3 dpdy = (db < dt) ? ce - get_world(vec3((uv - texel_size * vec2(0, 1)) * 2. - 1., b1), inverse_matrix) 
	: - ce + get_world(vec3((uv + texel_size * vec2(0, 1)) * 2. - 1., t1), inverse_matrix);
	
	return normalize(cross(dpdx, dpdy));
}

void fragment() {
	float depth = texture(depth_texture, SCREEN_UV).x;
	
	vec3 world_position = get_world(vec3(SCREEN_UV * 2. - 1., depth), INV_VIEW_MATRIX * INV_PROJECTION_MATRIX);
	
	vec3 model_position = vec3(MODEL_MATRIX[3][0], MODEL_MATRIX[3][1], MODEL_MATRIX[3][2]);
	
	mat3 model_matrix = mat3(
		vec3(
			MODEL_MATRIX[0][0] * mesh_extents.x, 
			MODEL_MATRIX[0][1] * mesh_extents.x, 
			MODEL_MATRIX[0][2] * mesh_extents.x),
		vec3(
			MODEL_MATRIX[1][0] * mesh_extents.y, 
			MODEL_MATRIX[1][1] * mesh_extents.y, 
			MODEL_MATRIX[1][2] * mesh_extents.y),
		vec3(
			MODEL_MATRIX[2][0] * mesh_extents.z, 
			MODEL_MATRIX[2][1] * mesh_extents.z, 
			MODEL_MATRIX[2][2] * mesh_extents.z)
	 );
	
	vec3 local_position = inverse(model_matrix) * (world_position - model_position) + vec3(0.5);
	
	if (local_position.x > 1. || local_position.x < 0. || local_position.y > 1. || local_position.y < 0. || local_position.z > 1. || local_position.z < 0.)
	{
		discard;
	}
	
	vec4 paint_texture_sample = texture(world_paint_texture, local_position);
	
	ALBEDO = paint_texture_sample.xyz;
	ALPHA = paint_texture_sample.a * (1. - step(depth, 0));
	DEPTH = depth;
	
	vec3 constructed_normal = get_normal(SCREEN_UV, vec2(1) / vec2(textureSize(depth_texture, 0)), INV_PROJECTION_MATRIX);
	NORMAL = -constructed_normal;
	
	float metallic_tex = dot(texture(texture_metallic, UV), metallic_texture_channel);
	METALLIC = metallic_tex * metallic;
	SPECULAR = specular;

	vec4 roughness_texture_channel = vec4(1.0, 0.0, 0.0, 0.0);
	float roughness_tex = dot(texture(texture_roughness, UV), roughness_texture_channel);
	ROUGHNESS = roughness_tex * roughness;
}
