// NOTE: Shader automatically converted from Godot Engine 4.3.stable's StandardMaterial3D.

shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 albedo : source_color;
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform float point_size : hint_range(0.1, 128.0, 0.1);

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

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable;
uniform sampler2D depth_texture : hint_depth_texture;

uniform float refraction_index = 0.5;

varying vec3 world_normal;

// from https://www.shadertoy.com/view/fdtfWM
// Rodrigues' Rotation Formula: can be used to rotate a point around an axis. However to combine rotations use quaternions!
vec3 rotate(float angle, vec3 axis, vec3 point) // NOTE: axis must be unit!
{
    float c = cos(angle);
    float s = sin(angle);
    return c * point + s * cross(axis, point) + (1.0 - c) * (dot(point, axis) * axis); // Rodrigues' Rotation Formula
}

mat3 orthonormalize(mat3 in_mat)
{
	return mat3(normalize(vec3(in_mat[0][0], in_mat[0][1], in_mat[0][2])),
	normalize(vec3(in_mat[1][0], in_mat[1][1], in_mat[1][2])),
	normalize(vec3(in_mat[2][0], in_mat[2][1], in_mat[2][2])));
}

void vertex() {
	UV = UV * uv1_scale.xy + uv1_offset.xy;
	world_normal = orthonormalize(MODEL_NORMAL_MATRIX) * NORMAL;
}

void fragment() {
	vec2 base_uv = UV;

	vec4 world_position = INV_VIEW_MATRIX * INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2. - 1., FRAGCOORD.z, 1.);
	world_position.xyz /= world_position.w;

	vec4 back_world_position = INV_VIEW_MATRIX * INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2. - 1., texture(depth_texture, SCREEN_UV).x, 1.);
	back_world_position.xyz /= back_world_position.w;

	float background_distance = length(back_world_position.xyz - world_position.xyz);

	vec3 ray = world_position.xyz - CAMERA_POSITION_WORLD;

	float ray_length = length(ray);

	vec3 wray = ray / ray_length;

	vec3 ray_normal_cross = cross(wray, world_normal);

	float rnc_length = length(ray_normal_cross);

	vec3 wrnc = ray_normal_cross / rnc_length;

	float angle = asin(sin(pow(rnc_length, 10)) * refraction_index);

	vec3 rotated_ray = rotate(angle, wrnc, wray);

	vec4 new_clip = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world_position.xyz + rotated_ray * background_distance, 1.0);

	vec3 new_ndc = new_clip.xyz / new_clip.w;

	vec2 new_screen_uv = new_ndc.xy / 2. + 0.5;

	vec4 albedo_tex = texture(screen_texture, new_screen_uv);

	ALBEDO = albedo.rgb * albedo_tex.rgb;

	float metallic_tex = dot(texture(texture_metallic, base_uv), metallic_texture_channel);
	METALLIC = metallic_tex * metallic;
	SPECULAR = specular;

	vec4 roughness_texture_channel = vec4(1.0, 0.0, 0.0, 0.0);
	float roughness_tex = dot(texture(texture_roughness, base_uv), roughness_texture_channel);
	ROUGHNESS = roughness_tex * roughness;
}

void light() {
	DIFFUSE_LIGHT = vec3(1);
}
