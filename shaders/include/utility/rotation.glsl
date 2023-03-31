#if !defined INCLUDE_UTILITY_ROTATION
#define INCLUDE_UTILITY_ROTATION

mat2 get_rotation_matrix(float angle) {
	float cosine = cos(angle);
	float sine   = sin(angle);
	return mat2(cosine, -sine, sine, cosine);
}

// Rotation matrix using Rodriguez's rotation formula
// https://math.stackexchange.com/questions/3233842/rotation-matrix-from-axis-angle-representation
mat3 get_rotation_matrix(vec3 axis, float cosine, float sine) {
	vec3 mul = axis - axis * cosine;
	vec3 add = axis * sine;
	vec3 axis_sq = axis * axis;
	vec3 diagonal = axis_sq + (cosine - cosine * axis_sq);

	return mat3(
		diagonal.x, axis.x * mul.y - add.z, axis.x * mul.z + add.y,
		axis.x * mul.y + add.z, diagonal.y, axis.y * mul.z - add.x,
		axis.x * mul.z - mul.y, axis.y * mul.z + add.x, diagonal.z
	);
}
mat3 get_rotation_matrix(vec3 axis, float angle) {
	return get_rotation_matrix(axis, cos(angle), sin(angle));
}

#if 0
// Not tested!
// q0 + q1 i + q2 j + q3 k -> vec4(q1, q2, q3, q0)
// https://www.geeks3d.com/20141201/how-to-rotate-a-vertex-by-a-quaternion-in-glsl/

vec4 get_rotation_quaternion(vec3 axis, float angle) {
	angle *= 0.5;
	float sin_half_angle = sin(angle);
	float cos_half_angle = cos(angle);

	return vec4(axis * sin_half_angle, cos_half_angle);
}

vec4 get_rotation_quaternion(vec3 from, vec3 to) {
	vec3 axis = cross(from, to);
	float cos_angle = dot(from, to);

	// Find sine and cosine of half angle using half angle identities
	float sin_half_angle = sqrt(0.5 - 0.5 * cos_angle);
	float cos_half_angle = sqrt(0.5 + 0.5 * cos_angle);

	return vec4(axis * sin_half_angle, cos_half_angle);
}

vec3 rotate(vec4 q, vec3 v) {
	return v + 2.0 * cross(q.xyz, cross(q.xyz, v) + q.w * v);
}
#endif

#endif // INCLUDE_UTILITY_ROTATION
