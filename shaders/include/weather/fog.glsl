#if !defined INCLUDE_WEATHER_FOG
#define INCLUDE_WEATHER_FOG

#include "/include/fog/overworld/parameters.glsl"
#include "/include/utility/color.glsl"
#include "/include/weather/core.glsl"

uniform float biome_pale_garden;

OverworldFogParameters get_fog_parameters(Weather weather) {
	OverworldFogParameters params;

	// Rayleigh coefficient

	const vec3 rayleigh_normal      = from_srgb(vec3(AIR_FOG_RAYLEIGH_R,        AIR_FOG_RAYLEIGH_G,        AIR_FOG_RAYLEIGH_B       )) * AIR_FOG_RAYLEIGH_DENSITY;
	const vec3 rayleigh_rain        = from_srgb(vec3(AIR_FOG_RAYLEIGH_R_RAIN,   AIR_FOG_RAYLEIGH_G_RAIN,   AIR_FOG_RAYLEIGH_B_RAIN  )) * AIR_FOG_RAYLEIGH_DENSITY_RAIN;
	const vec3 rayleigh_arid        = from_srgb(vec3(AIR_FOG_RAYLEIGH_R_ARID,   AIR_FOG_RAYLEIGH_G_ARID,   AIR_FOG_RAYLEIGH_B_ARID  )) * AIR_FOG_RAYLEIGH_DENSITY_ARID; 
	const vec3 rayleigh_snowy       = from_srgb(vec3(AIR_FOG_RAYLEIGH_R_SNOWY,  AIR_FOG_RAYLEIGH_G_SNOWY,  AIR_FOG_RAYLEIGH_B_SNOWY )) * AIR_FOG_RAYLEIGH_DENSITY_SNOWY;
	const vec3 rayleigh_taiga       = from_srgb(vec3(AIR_FOG_RAYLEIGH_R_TAIGA,  AIR_FOG_RAYLEIGH_G_TAIGA,  AIR_FOG_RAYLEIGH_B_TAIGA )) * AIR_FOG_RAYLEIGH_DENSITY_TAIGA;
	const vec3 rayleigh_jungle      = from_srgb(vec3(AIR_FOG_RAYLEIGH_R_JUNGLE, AIR_FOG_RAYLEIGH_G_JUNGLE, AIR_FOG_RAYLEIGH_B_JUNGLE)) * AIR_FOG_RAYLEIGH_DENSITY_JUNGLE;
	const vec3 rayleigh_swamp       = from_srgb(vec3(AIR_FOG_RAYLEIGH_R_SWAMP,  AIR_FOG_RAYLEIGH_G_SWAMP,  AIR_FOG_RAYLEIGH_B_SWAMP )) * AIR_FOG_RAYLEIGH_DENSITY_SWAMP;
	const vec3 rayleigh_pale_garden = from_srgb(vec3(AIR_FOG_RAYLEIGH_R_PALE_GARDEN,  AIR_FOG_RAYLEIGH_G_PALE_GARDEN,  AIR_FOG_RAYLEIGH_B_PALE_GARDEN )) * AIR_FOG_RAYLEIGH_DENSITY_PALE_GARDEN;

	params.rayleigh_scattering_coeff 
		= rayleigh_normal * biome_temperate
		+ rayleigh_arid   * biome_arid
	    + rayleigh_snowy  * biome_snowy
		+ rayleigh_taiga  * biome_taiga
		+ rayleigh_jungle * biome_jungle
		+ rayleigh_swamp  * biome_swamp
		+ rayleigh_pale_garden * biome_pale_garden;

	// rain
	params.rayleigh_scattering_coeff = mix(
		params.rayleigh_scattering_coeff * (1.0 + weather.humidity * weather.temperature), 
		rayleigh_rain, 
		rainStrength * biome_may_rain
	);

	// Mie coefficient

	// Increased mie density and scattering strength during late sunset / blue hour
	float blue_hour = linear_step(0.05, 1.0, exp(-190.0 * sqr(sun_dir.y + 0.07283)));

	float mie 
		= AIR_FOG_MIE_DENSITY_MORNING   * time_sunrise
		+ AIR_FOG_MIE_DENSITY_NOON      * time_noon
		+ AIR_FOG_MIE_DENSITY_EVENING   * time_sunset
		+ AIR_FOG_MIE_DENSITY_MIDNIGHT  * time_midnight
		+ AIR_FOG_MIE_DENSITY_BLUE_HOUR * blue_hour;

	// Weather influence
	mie = mix(
		mie + 8.0 * AIR_FOG_MIE_DENSITY_NOON * sqr(clamp01(weather.humidity * rcp(0.8))), 
		AIR_FOG_MIE_DENSITY_RAIN, 
		rainStrength * biome_may_rain
	);
	mie = mix(mie, AIR_FOG_MIE_DENSITY_SNOW, rainStrength * biome_may_snow);

	float mie_albedo = mix(0.9, 0.5, rainStrength * biome_may_rain);
	params.mie_scattering_coeff = vec3(mie_albedo * mie);
	params.mie_extinction_coeff = vec3(mie);

#ifdef DESERT_SANDSTORM
	const float desert_sandstorm_density    = 0.2;
	const float desert_sandstorm_scattering = desert_sandstorm_density * 0.5;
	const vec3  desert_sandstorm_extinction = desert_sandstorm_density * vec3(0.2, 0.27, 0.45);

	params.mie_scattering_coeff += desert_sandstorm * desert_sandstorm_scattering;
	params.mie_extinction_coeff += desert_sandstorm * desert_sandstorm_extinction;
#endif

	return params;
}

#endif // INCLUDE_WEATHER_FOG

