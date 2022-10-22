#if !defined PALETTE_INCLUDED
#define PALETTE_INCLUDED

//----------------------------------------------------------------------------//
#if   defined WORLD_OVERWORLD

#include "atmosphere.glsl"

vec3 getSunIlluminance() {
	const vec3 userSunTintSqrt = vec3(SUN_R, SUN_G, SUN_B) * SUN_I;
	const vec3 userSunTint = userSunTintSqrt * userSunTintSqrt;

	vec3 illuminance = 9.0 * baseSunCol * userSunTint;

	// Magic brightness adjustment, pretty much pre-exposing for the light source to
	// compensate for the lack of auto exposure by default
	float blueHour = cube(pulse(float(worldTime), 13200.0, 800.0, 24000.0))  // dusk
	               + cube(pulse(float(worldTime), 22800.0, 800.0, 24000.0)); // dawn

	illuminance *= 1.0 + 44.0 * blueHour;

	// Nice purpley tint during the blue hour
	const vec3 purpleTint = vec3(1.0, 0.85, 0.95);
	illuminance *= (1.0 - blueHour) + blueHour * purpleTint;

	return illuminance;
}

vec3 getMoonIlluminance() {
	return vec3(0.05);
}

vec3 getLightColor() {
	vec3 lightCol  = mix(getSunIlluminance(), getMoonIlluminance(), step(0.5, sunAngle));
	     lightCol *= atmosphereTransmittance(airViewerPos, lightDir);
	     lightCol *= clamp01(rcp(0.02) * lightDir.y); // fade away during day/night transition

	return lightCol;
}

vec3 getSkyColor() {
	vec3 skyCol = vec3(0.41, 0.50, 0.73) * timeSunrise
	            + vec3(0.69, 0.87, 1.67) * timeNoon
				+ vec3(0.48, 0.55, 0.75) * timeSunset
				+ vec3(0.00, 0.00, 0.00) * timeMidnight;

	float lateSunset = pulse(float(worldTime), 12500.0, 500.0, 24000.0)
	                 + pulse(float(worldTime), 23500.0, 500.0, 24000.0);

	float blueHour = pulse(float(worldTime), 13000.0, 500.0, 24000.0)  // dusk
	               + pulse(float(worldTime), 23000.0, 500.0, 24000.0); // dawn

	skyCol = mix(skyCol, vec3(0.26, 0.28, 0.33), lateSunset);
	skyCol = mix(skyCol, vec3(0.44, 0.45, 0.70), blueHour);

	return skyCol;
}

float getSkylightBoost() {
	return 1.0;
}

//----------------------------------------------------------------------------//
#elif defined WORLD_NETHER

//----------------------------------------------------------------------------//
#elif defined WORLD_END

#endif

#endif // PALETTE_INCLUDED
