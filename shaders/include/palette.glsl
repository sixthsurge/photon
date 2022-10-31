#if !defined PALETTE_INCLUDED
#define PALETTE_INCLUDED

//----------------------------------------------------------------------------//
#if   defined WORLD_OVERWORLD

#include "atmosphere.glsl"
#include "utility/color.glsl"

// Magic brightness adjustments, pre-exposing for the light source to compensate
// for the lack of auto exposure by default
float getSunBrightness() {
	const float baseSunBrightness = 8.0;
	const float userSunBrightness = SUN_I;

	float blueHour = cube(pulse(float(worldTime), 13200.0, 900.0, 24000.0))  // dusk
	               + cube(pulse(float(worldTime), 22800.0, 900.0, 24000.0)); // dawn

	float blueHourMul = 1.0 + 40.0 * blueHour;

	return baseSunBrightness * userSunBrightness * blueHourMul;
}
float getMoonBrightness() {
	const float baseMoonBrightness = 0.5;
	const float userMoonBrightness = MOON_I;

	return baseMoonBrightness * userMoonBrightness;
}

vec3 getSunTint() {
	const vec3 userSunTint = toRec2020(vec3(SUN_R, SUN_G, SUN_B));

	float blueHour = cube(pulse(float(worldTime), 13200.0, 800.0, 24000.0))  // dusk
	               + cube(pulse(float(worldTime), 22800.0, 800.0, 24000.0)); // dawn

	const vec3 purple = vec3(1.0, 0.85, 0.95);
	vec3 blueHourTint = (1.0 - blueHour) + blueHour * purple;

	return blueHourTint * userSunTint;
}
vec3 getMoonTint() {
	return vec3(1.0);
}

vec3 getLightColor() {
	vec3 lightColor  = mix(getSunBrightness() * getSunTint(), getMoonBrightness() * getMoonTint(), step(0.5, sunAngle));
	     lightColor *= atmosphereSunColor(lightDir.y, planetRadius);
	     lightColor *= clamp01(rcp(0.02) * lightDir.y); // fade away during day/night transition

	return lightColor;
}

vec3 getSkyColor() {
	vec3 skyColor = vec3(0.41, 0.50, 0.73) * timeSunrise
	            + vec3(0.69, 0.87, 1.67) * timeNoon
				+ vec3(0.48, 0.55, 0.75) * timeSunset
				+ vec3(0.00, 0.00, 0.00) * timeMidnight;

	float lateSunset = pulse(float(worldTime), 12500.0, 500.0, 24000.0)
	                 + pulse(float(worldTime), 23500.0, 500.0, 24000.0);

	float blueHour = pulse(float(worldTime), 13000.0, 500.0, 24000.0)  // dusk
	               + pulse(float(worldTime), 23000.0, 500.0, 24000.0); // dawn

	skyColor = mix(skyColor, vec3(0.26, 0.28, 0.33), lateSunset);
	skyColor = mix(skyColor, vec3(0.44, 0.45, 0.70), blueHour);

	return skyColor;
}

float getSkylightBoost() {
	float nightSkylightBoost = 4.0 * (1.0 - smoothstep(-0.2, -0.1, sunDir.y));

	return 1.0 + nightSkylightBoost;
}

//----------------------------------------------------------------------------//
#elif defined WORLD_NETHER

//----------------------------------------------------------------------------//
#elif defined WORLD_END

#endif

#endif // PALETTE_INCLUDED
