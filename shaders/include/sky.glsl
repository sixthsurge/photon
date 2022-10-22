#if !defined SKY_INCLUDED
#define SKY_INCLUDED

//----------------------------------------------------------------------------//
#if   defined WORLD_OVERWORLD

#include "utility/random.glsl"
#include "atmosphere.glsl"
#include "palette.glsl"

// Stars based on https://www.shadertoy.com/view/Md2SR3

vec3 unstableStarField(vec2 coord) {
	const float threshold = 1.0 - 0.01 * STARS_COVERAGE;
	const float minTemp = 3500.0;
	const float maxTemp = 9500.0;

	vec2 noise = hash2(coord);

	float star = linearStep(threshold, 1.0, noise.x);
	      star = pow4(star) * STARS_INTENSITY;

	float temp = mix(minTemp, maxTemp, noise.y);
	vec3 color = blackbody(temp);

	return star * color;
}

// Stabilizes the star field by sampling at the four neighboring integer coordinates and
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
	// Project ray direction onto the plane
	vec2 coord  = rayDir.xy * rcp(abs(rayDir.z) + length(rayDir.xy)) + 41.21 * sign(rayDir.z);
	     coord *= 600.0;

	return stableStarField(coord) * (1.0 - timeNoon);
}

vec3 renderSky(vec3 rayDir) {
	// Sky gradient

	vec3 sky = illuminance[0] * atmosphereScattering(rayDir, sunDir)
	         + illuminance[1] * atmosphereScattering(rayDir, moonDir);

	sky += 1.0 * drawStars(rayDir) * atmosphereTransmittance(airViewerPos, rayDir);

	// Stars

	// Sun and moon

	// Clouds

	// Fade lower part of sky into cave fog color when underground so that the sky isn't visible
	// beyond the render distance
	float undergroundSkyFade = biomeCave * smoothstep(-0.1, 0.1, 0.4 - rayDir.y);
	sky = mix(sky, vec3(0.0), undergroundSkyFade);

	return sky;
}

//----------------------------------------------------------------------------//
#elif defined WORLD_NETHER

//----------------------------------------------------------------------------//
#elif defined WORLD_END

#endif

#endif // SKY_INCLUDED
