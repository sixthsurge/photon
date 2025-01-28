#if !defined INCLUDE_FOG_AIR_FOG_COEFF
#define INCLUDE_FOG_AIR_FOG_COEFF

#include "/include/fog/overworld/coeff_struct.glsl"
#include "/include/misc/weather.glsl"

AirFogCoefficients calculate_air_fog_coefficients() {
	AirFogCoefficients coeff;
	float fogginess = daily_weather_blend(daily_weather_fogginess);

	// Rayleigh

	const vec3 rayleigh_normal = from_srgb(vec3(AIR_FOG_RAYLEIGH_R,        AIR_FOG_RAYLEIGH_G,        AIR_FOG_RAYLEIGH_B       )) * AIR_FOG_RAYLEIGH_DENSITY;
	const vec3 rayleigh_rain   = from_srgb(vec3(AIR_FOG_RAYLEIGH_R_RAIN,   AIR_FOG_RAYLEIGH_G_RAIN,   AIR_FOG_RAYLEIGH_B_RAIN  )) * AIR_FOG_RAYLEIGH_DENSITY_RAIN;
	const vec3 rayleigh_arid   = from_srgb(vec3(AIR_FOG_RAYLEIGH_R_ARID,   AIR_FOG_RAYLEIGH_G_ARID,   AIR_FOG_RAYLEIGH_B_ARID  )) * AIR_FOG_RAYLEIGH_DENSITY_ARID; const vec3 rayleigh_snowy  = from_srgb(vec3(AIR_FOG_RAYLEIGH_R_SNOWY,  AIR_FOG_RAYLEIGH_G_SNOWY,  AIR_FOG_RAYLEIGH_B_SNOWY )) * AIR_FOG_RAYLEIGH_DENSITY_SNOWY;
	const vec3 rayleigh_taiga  = from_srgb(vec3(AIR_FOG_RAYLEIGH_R_TAIGA,  AIR_FOG_RAYLEIGH_G_TAIGA,  AIR_FOG_RAYLEIGH_B_TAIGA )) * AIR_FOG_RAYLEIGH_DENSITY_TAIGA;
	const vec3 rayleigh_jungle = from_srgb(vec3(AIR_FOG_RAYLEIGH_R_JUNGLE, AIR_FOG_RAYLEIGH_G_JUNGLE, AIR_FOG_RAYLEIGH_B_JUNGLE)) * AIR_FOG_RAYLEIGH_DENSITY_JUNGLE;
	const vec3 rayleigh_swamp  = from_srgb(vec3(AIR_FOG_RAYLEIGH_R_SWAMP,  AIR_FOG_RAYLEIGH_G_SWAMP,  AIR_FOG_RAYLEIGH_B_SWAMP )) * AIR_FOG_RAYLEIGH_DENSITY_SWAMP;

	coeff.rayleigh = rayleigh_normal * biome_temperate
	               + rayleigh_arid   * biome_arid
	               + rayleigh_snowy  * biome_snowy
		           + rayleigh_taiga  * biome_taiga
		           + rayleigh_jungle * biome_jungle
		           + rayleigh_swamp  * biome_swamp;

	// rain
	coeff.rayleigh  = mix(coeff.rayleigh, rayleigh_rain, rainStrength * biome_may_rain);
	coeff.rayleigh += coeff.rayleigh * (2.0 * fogginess);

	// Mie

	// increased mie density and scattering strength during late sunset / blue hour
	float blue_hour = linear_step(0.05, 1.0, exp(-190.0 * sqr(sun_dir.y + 0.07283)));

	float mie = AIR_FOG_MIE_DENSITY_MORNING   * time_sunrise
	          + AIR_FOG_MIE_DENSITY_NOON      * time_noon
	          + AIR_FOG_MIE_DENSITY_EVENING   * time_sunset
	          + AIR_FOG_MIE_DENSITY_MIDNIGHT  * time_midnight
	          + AIR_FOG_MIE_DENSITY_BLUE_HOUR * blue_hour;

	mie = mix(mie, AIR_FOG_MIE_DENSITY_RAIN, rainStrength * biome_may_rain);
	mie = mix(mie, AIR_FOG_MIE_DENSITY_SNOW, rainStrength * biome_may_snow);

	float mie_albedo = mix(0.9, 0.5, rainStrength * biome_may_rain);
	coeff.mie_scattering = vec3(mie_albedo * mie);
	coeff.mie_extinction = vec3(mie);

#ifdef DESERT_SANDSTORM
	const float desert_sandstorm_density    = 0.2;
	const float desert_sandstorm_scattering = 0.5;
	const vec3  desert_sandstorm_extinction = vec3(0.2, 0.27, 0.45);

	coeff.mie_scattering += desert_sandstorm * (desert_sandstorm_density * desert_sandstorm_scattering);
	coeff.mie_extinction += desert_sandstorm * (desert_sandstorm_density * desert_sandstorm_extinction);
#endif

	return coeff;
}

#endif // INCLUDE_FOG_AIR_FOG_COEFF