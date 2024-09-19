shader_type spatial;

uniform sampler2D input_texture;

uniform float blur;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	ALBEDO = textureLod(input_texture, UV, )
}

//void light() {
	// Called for every pixel for every light affecting the material.
	// Uncomment to replace the default light processing function with this one.
//}
