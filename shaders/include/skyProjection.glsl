#if !defined SKYPROJECTION_INCLUDED
#define SKYPROJECTION_INCLUDED

#include "/include/utility/fastMath.glsl"

// Sky capture projection from https://sebh.github.io/publications/egsr2020.pdf

const ivec2 skyCaptureRes = ivec2(192, 108);

vec2 projectSky(vec3 direction) {
	vec2 projectedDir = normalize(direction.xz);

	float azimuthAngle = pi + atan(projectedDir.x, -projectedDir.y);
	float altitudeAngle = halfPi - fastAcos(direction.y);

	vec2 coord;
	coord.x = azimuthAngle * (1.0 / tau);
	coord.y = 0.5 + 0.5 * sign(altitudeAngle) * sqrt(2.0 * rcpPi * abs(altitudeAngle)); // Section 5.3

	return vec2(
		getUvFromUnitRange(coord.x, skyCaptureRes.x) * (255.0 / 256.0),
		getUvFromUnitRange(coord.y, skyCaptureRes.y)
	);
}

vec3 unprojectSky(vec2 coord) {
	coord = vec2(
		getUnitRangeFromUv(coord.x * (256.0 / 255.0), skyCaptureRes.x),
		getUnitRangeFromUv(coord.y, skyCaptureRes.y)
	);

	// Non-linear mapping of altitude angle (See section 5.3 of the paper)
	coord.y = (coord.y < 0.5)
		? -sqr(1.0 - 2.0 * coord.y)
		:  sqr(2.0 * coord.y - 1.0);

	float azimuthAngle = coord.x * tau - pi;
	float altitudeAngle = coord.y * halfPi;

	float altitudeCos = cos(altitudeAngle);
	float altitudeSin = sin(altitudeAngle);
	float azimuthCos = cos(azimuthAngle);
	float azimuthSin = sin(azimuthAngle);

	return vec3(altitudeCos * azimuthSin, altitudeSin, -altitudeCos * azimuthCos);
}

#endif // SKYPROJECTION_INCLUDED
