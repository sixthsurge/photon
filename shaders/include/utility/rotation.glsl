#if !defined INCLUDE_UTILITY_ROTATION
#define INCLUDE_UTILITY_ROTATION

mat2 getRotationMatrix(float angle) {
	float cosine = cos(angle);
	float sine   = sin(angle);
	return mat2(cosine, -sine, sine, cosine);
}

// Rotation matrix using Rodriguez's rotation formula
// https://math.stackexchange.com/questions/3233842/rotation-matrix-from-axis-angle-representation
mat3 getRotationMatrix(vec3 axis, float cosine, float sine) {
	vec3 mul = axis - axis * cosine;
	vec3 add = axis * sine;
	vec3 axisSq = axis * axis;
	vec3 diagonal = axisSq + (cosine - cosine * axisSq);

	return mat3(
		diagonal.x, axis.x * mul.y - add.z, axis.x * mul.z + add.y,
		axis.x * mul.y + add.z, diagonal.y, axis.y * mul.z - add.x,
		axis.x * mul.z - mul.y, axis.y * mul.z + add.x, diagonal.z
	);
}
mat3 getRotationMatrix(vec3 axis, float angle) {
	return getRotationMatrix(axis, cos(angle), sin(angle));
}

#if 0
// Not tested!
// q0 + q1 i + q2 j + q3 k -> vec4(q1, q2, q3, q0)
// https://www.geeks3d.com/20141201/how-to-rotate-a-vertex-by-a-quaternion-in-glsl/

vec4 getRotationQuaternion(vec3 axis, float angle) {
	angle *= 0.5;
	float sinHalfAngle = sin(angle);
	float cosHalfAngle = cos(angle);

	return vec4(axis * sinHalfAngle, cosHalfAngle);
}

vec4 getRotationQuaternion(vec3 from, vec3 to) {
	vec3 axis = cross(from, to);
	float cosAngle = dot(from, to);

	// Find sine and cosine of half angle using half angle identities
	float sinHalfAngle = sqrt(0.5 - 0.5 * cosAngle);
	float cosHalfAngle = sqrt(0.5 + 0.5 * cosAngle);

	return vec4(axis * sinHalfAngle, cosHalfAngle);
}

vec3 rotate(vec4 q, vec3 v) {
	return v + 2.0 * cross(q.xyz, cross(q.xyz, v) + q.w * v);
}
#endif

#endif // INCLUDE_UTILITY_ROTATION
