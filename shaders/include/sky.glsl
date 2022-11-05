#if !defined SKY_INCLUDED
#define SKY_INCLUDED

//----------------------------------------------------------------------------//
#if   defined WORLD_OVERWORLD

#include "atmosphere.glsl"
#include "palette.glsl"
#include "utility/fastMath.glsl"
#include "utility/random.glsl"

const float sunLuminance  = 10.0; // luminance of sun disk
const float moonLuminance = 5.0; // luminance of sun disk

vec3 drawSun(vec3 rayDir) {
	float nu = dot(rayDir, sunDir);

	// Limb darkening model from http://www.physics.hmc.edu/faculty/esin/a101/limbdarkening.pdf
	const vec3 alpha = vec3(0.429, 0.522, 0.614);
	float centerToEdge = max0(sunAngularRadius - fastAcos(nu));
	vec3 limbDarkening = pow(vec3(1.0 - sqr(1.0 - centerToEdge)), 0.5 * alpha);

	return baseSunCol * sunLuminance * step(0.0, centerToEdge) * limbDarkening * illuminance[0];
}

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
	vec3 sky = vec3(0.0);

	// Sun, moon and stars

#if defined PROGRAM_DEFERRED3
	vec4 vanillaSky = texelFetch(colortex3, ivec2(gl_FragCoord.xy), 0);
	vec3 vanillaSkyColor = srgbToLinear(vanillaSky.rgb) * rec709_to_rec2020;
	uint vanillaSkyId = uint(255.0 * vanillaSky.a);

#ifdef VANILLA_SUN
	if (vanillaSkyId == 2) {
		const vec3 brightnessScale = baseSunCol * sunLuminance;
		sky += vanillaSkyColor * brightnessScale * illuminance[0];
	}
#else
	sky += drawSun(rayDir);
#endif

#ifdef VANILLA_MOON
	if (vanillaSkyId == 3) {
		const vec3 brightnessScale = baseSunCol * moonLuminance;
		sky += vanillaSkyColor * brightnessScale;
	}
#else
	sky += drawMoon(rayDir);
#endif

#ifdef STARS
	sky += drawStars(rayDir);
#endif
#endif

	// Sky gradient

	sky *= atmosphereTransmittance(airViewerPos, rayDir);
	sky += illuminance[0] * atmosphereScattering(rayDir, sunDir);
	sky += illuminance[1] * atmosphereScattering(rayDir, moonDir);

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
