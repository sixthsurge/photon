#if !defined INCLUDE_ATMOSPHERE_SKY
#define INCLUDE_ATMOSPHERE_SKY

#include "/include/utility/fastMath.glsl"
#include "/include/utility/random.glsl"

vec3 drawSun(vec3 rayDir) {
	float nu = dot(rayDir, sunDir);

	// Limb darkening model from http://www.physics.hmc.edu/faculty/esin/a101/limbdarkening.pdf
	const vec3 alpha = vec3(0.429, 0.522, 0.614); // for AP1 primaries
	float centerToEdge = max0(sunAngularRadius - acosApprox(nu));
	vec3 limbDarkening = pow(vec3(1.0 - sqr(1.0 - centerToEdge)), 0.5 * alpha);

	return step(0.0, centerToEdge) * sunRadiance * limbDarkening;
}

// Stars based on https://www.shadertoy.com/view/Md2SR3

vec3 unstableStarField(vec2 coord) {
	const float threshold = 1.0 - 0.006 * STARS_COVERAGE;
	const float minTemp = STARS_TEMPERATURE - STARS_TEMPERATURE_VARIATION;
	const float maxTemp = STARS_TEMPERATURE + STARS_TEMPERATURE_VARIATION;

	vec2 noise = hash2(coord);

	float star = linearStep(threshold, 1.0, noise.x);
	      star = cube(star) * STARS_INTENSITY;

	float temp = mix(minTemp, maxTemp, noise.y);
	vec3 color = blackbody(temp);

	return star * color;
}

// Stabilizes the star field by only sampling at the four neighboring integer coordinates and
// interpolating
vec3 stableStarField(vec2 coord) {
	coord = abs(coord) + 33.3 * step(0.0, coord);
	vec2 i, f = modf(coord, i);

	f.x = cubicSmooth(f.x);
	f.y = cubicSmooth(f.y);

	return unstableStarField(i + vec2(0.0, 0.0)) * (1.0 - f.x) * (1.0 - f.y)
	     + unstableStarField(i + vec2(1.0, 0.0)) * f.x * (1.0 - f.y)
	     + unstableStarField(i + vec2(0.0, 1.0)) * f.y * (1.0 - f.x)
	     + unstableStarField(i + vec2(1.0, 1.0)) * f.x * f.y;
}

vec3 drawStars(vec3 rayDir) {
#if defined WORLD_OVERWORLD && defined SHADOW
	// Trick to make stars rotate alongside the sun and moon
	rayDir = mat3(shadowModelView) * rayDir * (sunAngle < 0.5 ? 1.0 : -1.0);
#endif

	// Project ray direction onto the plane
	vec2 coord  = rayDir.xy * rcp(abs(rayDir.z) + length(rayDir.xy)) + 41.21 * sign(rayDir.z);
	     coord *= 600.0 - 400.0 * STARS_SCALE;

	return stableStarField(coord) * (1.0 - timeNoon);
}

#endif // INCLUDE_ATMOSPHERE_SKY
