#if !defined SKY_INCLUDED
#define SKY_INCLUDED

//----------------------------------------------------------------------------//
#if   defined WORLD_OVERWORLD

#include "utility/random.glsl"
#include "atmosphere.glsl"
#include "palette.glsl"

// Stars based on https://www.shadertoy.com/view/Md2SR3

vec3 unstableStarField(vec2 coord, float starThreshold) {
	const float minTemp = 3500.0;
	const float maxTemp = 9500.0;

	vec4 noise = hash4(coord);

	float star = linearStep(starThreshold, 1.0, noise.x);
	      star = pow4(star) * STARS_INTENSITY;

	float temp = mix(minTemp, maxTemp, noise.y);
	vec3 color = blackbody(temp);

	const float twinkleSpeed = 2.0;
	float twinkleAmount = noise.z;
	float twinkleOffset = tau * noise.w;
	star *= 1.0 - twinkleAmount * cos(frameTimeCounter * twinkleSpeed + twinkleOffset);

	return star * color;
}

// Stabilizes the star field by sampling at the four neighboring integer coordinates and
// interpolating
vec3 stableStarField(vec2 coord, float starThreshold) {
	coord = abs(coord) + 33.3 * step(0.0, coord);
	vec2 i, f = modf(coord, i);

	f.x = cubicSmooth(f.x);
	f.y = cubicSmooth(f.y);

	return unstableStarField(i + vec2(0.0, 0.0), starThreshold) * (1.0 - f.x) * (1.0 - f.y)
	     + unstableStarField(i + vec2(1.0, 0.0), starThreshold) * f.x * (1.0 - f.y)
	     + unstableStarField(i + vec2(0.0, 1.0), starThreshold) * f.y * (1.0 - f.x)
	     + unstableStarField(i + vec2(1.0, 1.0), starThreshold) * f.x * f.y;
}

vec3 drawStars(vec3 rayDir) {
#ifdef SHADOW
	// Trick to make stars rotate with sun and moon
	mat3 rot = (sunAngle < 0.5)
		? mat3(shadowModelViewInverse)
		: mat3(-shadowModelViewInverse[0].xyz, shadowModelViewInverse[1].xyz, -shadowModelViewInverse[2].xyz);

	rayDir *= rot;
#endif

	// Adjust star threshold so that brightest stars appear first
	float starThreshold = 1.0 - 0.008 * STARS_COVERAGE * smoothstep(-0.05, 0.1, -sunDir.y);

	// Project ray direction onto the plane
	vec2 coord  = rayDir.xy * rcp(abs(rayDir.z) + length(rayDir.xy)) + 41.21 * sign(rayDir.z);
	     coord *= 600.0;

	return stableStarField(coord, starThreshold);
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
