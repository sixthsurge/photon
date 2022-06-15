#if !defined INCLUDE_ATMOSPHERE_SKYPROJECTION
#define INCLUDE_ATMOSPHERE_SKYPROJECTION

#include "/include/atmospherics/atmosphere.glsl"
#include "/include/utility/fastMath.glsl"

// Sky capture projection from https://sebh.github.io/publications/egsr2020.pdf

const ivec2 skyCaptureRes = ivec2(255, 128);

vec2 projectSky(vec3 direction) {
	const float horizonCos = sqrt(airViewerPos.y * airViewerPos.y - planetRadius * planetRadius) / airViewerPos.y;
	const float horizonAngle = acos(horizonCos);

	vec2 projectedDir = normalize(direction.xz);

	float azimuthAngle = pi + atan(projectedDir.x, -projectedDir.y);
	float altitudeAngle = horizonAngle - acosApprox(direction.y);

	vec2 coord;
	coord.x = azimuthAngle * (1.0 / tau);
	coord.y = 0.5 + 0.5 * sign(altitudeAngle) * sqrt(2.0 * rcpPi * abs(altitudeAngle)); // Section 5.3

	return vec2(
		getTexCoordFromUnitRange(coord.x, skyCaptureRes.x) * (255.0 / 256.0),
		getTexCoordFromUnitRange(coord.y, skyCaptureRes.y)
	);
}

vec3 unprojectSky(vec2 coord) {
	coord = vec2(
		getUnitRangeFromTexCoord(coord.x * (256.0 / 255.0), skyCaptureRes.x),
		getUnitRangeFromTexCoord(coord.y, skyCaptureRes.y)
	);

	// Non-linear mapping of altitude angle (See section 5.3 of the paper)
	coord.y = (coord.y < 0.5)
		? -sqr(1.0 - 2.0 * coord.y)
		:  sqr(2.0 * coord.y - 1.0);

	const float horizonCos = sqrt(airViewerPos.y * airViewerPos.y - planetRadius * planetRadius) / airViewerPos.y;
	const float horizonAngle = acos(horizonCos) - halfPi;

	float azimuthAngle = coord.x * tau - pi;
	float altitudeAngle = coord.y * halfPi - horizonAngle;

	float altitudeCos = cos(altitudeAngle);
	float altitudeSin = sin(altitudeAngle);
	float azimuthCos = cos(azimuthAngle);
	float azimuthSin = sin(azimuthAngle);

	return vec3(altitudeCos * azimuthSin, altitudeSin, -altitudeCos * azimuthCos);
}

#endif // INCLUDE_ATMOSPHERE_SKYPROJECTION
