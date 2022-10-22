#if !defined WEATHER_INCLUDED
#define WEATHER_INCLUDED

#include "utility/color.glsl"

// clouds

// fog

mat2x3 fogRayleighCoeff() {
	const vec3 rayleighNormal = toRec2020(vec3(FOG_RAYLEIGH_R,        FOG_RAYLEIGH_G,        FOG_RAYLEIGH_B       )) * FOG_RAYLEIGH_DENSITY;
	const vec3 rayleighRain   = toRec2020(vec3(FOG_RAYLEIGH_R_RAIN,   FOG_RAYLEIGH_G_RAIN,   FOG_RAYLEIGH_B_RAIN  )) * FOG_RAYLEIGH_DENSITY_RAIN;
	const vec3 rayleighArid   = toRec2020(vec3(FOG_RAYLEIGH_R_ARID,   FOG_RAYLEIGH_G_ARID,   FOG_RAYLEIGH_B_ARID  )) * FOG_RAYLEIGH_DENSITY_ARID;
	const vec3 rayleighSnowy  = toRec2020(vec3(FOG_RAYLEIGH_R_SNOWY,  FOG_RAYLEIGH_G_SNOWY,  FOG_RAYLEIGH_B_SNOWY )) * FOG_RAYLEIGH_DENSITY_SNOWY;
	const vec3 rayleighTaiga  = toRec2020(vec3(FOG_RAYLEIGH_R_TAIGA,  FOG_RAYLEIGH_G_TAIGA,  FOG_RAYLEIGH_B_TAIGA )) * FOG_RAYLEIGH_DENSITY_TAIGA;
	const vec3 rayleighJungle = toRec2020(vec3(FOG_RAYLEIGH_R_JUNGLE, FOG_RAYLEIGH_G_JUNGLE, FOG_RAYLEIGH_B_JUNGLE)) * FOG_RAYLEIGH_DENSITY_JUNGLE;
	const vec3 rayleighSwamp  = toRec2020(vec3(FOG_RAYLEIGH_R_SWAMP,  FOG_RAYLEIGH_G_SWAMP,  FOG_RAYLEIGH_B_SWAMP )) * FOG_RAYLEIGH_DENSITY_SWAMP;

	vec3 rayleigh = rayleighNormal * biomeTemperate
	              + rayleighArid   * biomeArid
	              + rayleighSnowy  * biomeSnowy
		          + rayleighTaiga  * biomeTaiga
		          + rayleighJungle * biomeJungle
		          + rayleighSwamp  * biomeSwamp;

	rayleigh  = mix(rayleigh, rayleighRain, rainStrength * biomeMayRain);

	return mat2x3(rayleigh, rayleigh);
}

mat2x3 fogMieCoeff() {
	// Increased mie density during late sunset / blue hour
	float blueHour = sqr(pulse(float(worldTime), 13100.0, 800.0, 24000.0))  // dusk
	               + sqr(pulse(float(worldTime), 22900.0, 800.0, 24000.0)); // dawn

	float mieCoeff = FOG_MIE_DENSITY_MORNING  * timeSunrise
	               + FOG_MIE_DENSITY_NOON     * timeNoon
	               + FOG_MIE_DENSITY_EVENING  * timeSunset
	               + FOG_MIE_DENSITY_MIDNIGHT * timeMidnight
	               + FOG_MIE_DENSITY_BLUE_HOUR * blueHour;

	mieCoeff = mix(mieCoeff, FOG_MIE_DENSITY_RAIN, rainStrength * biomeMayRain);

	float mieAlbedo = mix(0.9, 0.5, rainStrength * biomeMayRain);

	return mat2x3(vec3(mieCoeff * mieAlbedo), vec3(mieCoeff));
}

// puddles

#endif // WEATHER_INCLUDED
