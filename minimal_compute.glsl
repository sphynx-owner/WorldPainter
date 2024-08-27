#[compute]

#version 450

layout(set = 0, binding = 0, r32f) uniform image3D image;

layout(push_constant, std430) uniform Params 
{	
	vec3 position;
	float color_value;
	int brush_radius;
	int nan1;
	int nan2;
	int nan3;
} params;

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

void main() {
	ivec3 invocation_id = ivec3(gl_GlobalInvocationID.xyz);
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

	imageStore(image, current_coordinate, vec4(params.color_value, 1, 1, 1));
}
