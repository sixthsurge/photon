#if !defined WEATHER_INCLUDED
#define WEATHER_INCLUDED

#include "utility/color.glsl"

// clouds

// air fog

mat2x3 air_fog_rayleigh_coeff() {
	const vec3 rayleigh_normal = from_srgb(vec3(AIR_FOG_RAYLEIGH_R,        AIR_FOG_RAYLEIGH_G,        AIR_FOG_RAYLEIGH_B       )) * AIR_FOG_RAYLEIGH_DENSITY;
	const vec3 rayleigh_rain   = from_srgb(vec3(AIR_FOG_RAYLEIGH_R_RAIN,   AIR_FOG_RAYLEIGH_G_RAIN,   AIR_FOG_RAYLEIGH_B_RAIN  )) * AIR_FOG_RAYLEIGH_DENSITY_RAIN;
	const vec3 rayleigh_arid   = from_srgb(vec3(AIR_FOG_RAYLEIGH_R_ARID,   AIR_FOG_RAYLEIGH_G_ARID,   AIR_FOG_RAYLEIGH_B_ARID  )) * AIR_FOG_RAYLEIGH_DENSITY_ARID;
	const vec3 rayleigh_snowy  = from_srgb(vec3(AIR_FOG_RAYLEIGH_R_SNOWY,  AIR_FOG_RAYLEIGH_G_SNOWY,  AIR_FOG_RAYLEIGH_B_SNOWY )) * AIR_FOG_RAYLEIGH_DENSITY_SNOWY;
	const vec3 rayleigh_taiga  = from_srgb(vec3(AIR_FOG_RAYLEIGH_R_TAIGA,  AIR_FOG_RAYLEIGH_G_TAIGA,  AIR_FOG_RAYLEIGH_B_TAIGA )) * AIR_FOG_RAYLEIGH_DENSITY_TAIGA;
	const vec3 rayleigh_jungle = from_srgb(vec3(AIR_FOG_RAYLEIGH_R_JUNGLE, AIR_FOG_RAYLEIGH_G_JUNGLE, AIR_FOG_RAYLEIGH_B_JUNGLE)) * AIR_FOG_RAYLEIGH_DENSITY_JUNGLE;
	const vec3 rayleigh_swamp  = from_srgb(vec3(AIR_FOG_RAYLEIGH_R_SWAMP,  AIR_FOG_RAYLEIGH_G_SWAMP,  AIR_FOG_RAYLEIGH_B_SWAMP )) * AIR_FOG_RAYLEIGH_DENSITY_SWAMP;

	vec3 rayleigh = rayleigh_normal * biome_temperate
	              + rayleigh_arid   * biome_arid
	              + rayleigh_snowy  * biome_snowy
		          + rayleigh_taiga  * biome_taiga
		          + rayleigh_jungle * biome_jungle
		          + rayleigh_swamp  * biome_swamp;

	rayleigh  = mix(rayleigh, rayleigh_rain, rainStrength * biome_may_rain);

	return mat2x3(rayleigh, rayleigh);
}

mat2x3 air_fog_mie_coeff() {
	// Increased mie density during late sunset / blue hour
	float blue_hour = sqr(pulse(float(worldTime), 13100.0, 800.0, 24000.0))  // dusk
	                + sqr(pulse(float(worldTime), 22900.0, 800.0, 24000.0)); // dawn

	float mie_coeff = AIR_FOG_MIE_DENSITY_MORNING  * time_sunrise
	                + AIR_FOG_MIE_DENSITY_NOON     * time_noon
	                + AIR_FOG_MIE_DENSITY_EVENING  * time_sunset
	                + AIR_FOG_MIE_DENSITY_MIDNIGHT * time_midnight
	                + AIR_FOG_MIE_DENSITY_BLUE_HOUR * blue_hour;

	mie_coeff = mix(mie_coeff, AIR_FOG_MIE_DENSITY_RAIN, rainStrength * biome_may_rain);

	float mie_albedo = mix(0.9, 0.5, rainStrength * biome_may_rain);

	return mat2x3(vec3(mie_coeff * mie_albedo), vec3(mie_coeff));
}

// puddles

#endif // WEATHER_INCLUDED
