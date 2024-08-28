#[compute]

#version 450

layout(set = 0, binding = 0, rgba32f) uniform image3D image;
layout(set = 0, binding = 1) uniform sampler2D paint_texture;

layout(push_constant, std430) uniform Params 
{	
	vec3 position;	
	float color_value;
	mat4 surface_matrix;
	int brush_radius;
	int nan1;
	int nan2;
	int nan3;
} params;

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

// from https://www.shadertoy.com/view/fdtfWM
vec3 rotate(float angle, vec3 axis, vec3 point) // NOTE: axis must be unit!
{
    float c = cos(angle);
    float s = sin(angle);
    return c * point + s * cross(axis, point) + (1.0 - c) * (dot(point, axis) * axis); // Rodrigues' Rotation Formula
}

void main() {
	ivec3 invocation_id = ivec3(gl_GlobalInvocationID.xyz);
	ivec2 texture_size = textureSize(paint_texture, 0);
	ivec3 local_invocation_offset = invocation_id - ivec3(params.brush_radius);
	ivec3 current_coordinate = local_invocation_offset + ivec3(params.position);
	vec3 image_size = imageSize(image);
	if(current_coordinate.x >= image_size.x || current_coordinate.y >= image_size.y || current_coordinate.z >= image_size.z
	|| invocation_id.x >= params.brush_radius * 2 || invocation_id.y >= params.brush_radius * 2 || invocation_id.z >= params.brush_radius * 2)
	{
		return;
	}	

	float offset_length = length(local_invocation_offset);

	if(offset_length > params.brush_radius)
	{
		return;
	}

	vec3 local_sample_offset = invocation_id;

	local_sample_offset = (inverse(params.surface_matrix) * vec4(local_sample_offset, 1.0)).xyz;

	vec2 texture_uv = vec2(local_sample_offset.xy) / float(params.brush_radius * 2);

	vec4 texture_sample = textureLod(paint_texture, texture_uv, 0.0);

	imageStore(image, current_coordinate, vec4(texture_sample));//vec4(texture_sample.xyz, clamp(imageLoad(image, current_coordinate).a + texture_sample.a * params.color_value * 0.1 * smoothstep(params.brush_radius, 0, offset_length), 0, 1)));
}
