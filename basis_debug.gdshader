shader_type spatial;

varying vec3 position;

void vertex() {
	position = VERTEX;
}

void fragment() {
	ALBEDO = position * 100.;
}

//void light() {
	// Called for every pixel for every light affecting the material.
	// Uncomment to replace the default light processing function with this one.
//}
