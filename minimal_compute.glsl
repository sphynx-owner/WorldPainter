#[compute]

#version 450

layout(set = 0, binding = 0, r32f) uniform image3D image;

layout(push_constant, std430) uniform Params 
{	
	vec3 position;
	float nan8;
} params;

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

void main() {
	ivec3 current_pixel = ivec3(gl_GlobalInvocationID.xyz);
	vec3 image_size = imageSize(image);
	if(current_pixel.x >= image_size.x || current_pixel.y >= image_size.y || current_pixel.z >= image_size.z)
	{
		return;
	}

	imageStore(image, current_pixel, vec4(1, 1, 1, 1));
}
