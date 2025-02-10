#if !defined INCLUDE_MISC_WEATHER
#define INCLUDE_MISC_WEATHER

#include "/include/fog/overworld/parameters.glsl"
#include "/include/sky/clouds/constants.glsl"
#include "/include/sky/clouds/parameters.glsl"
#include "/include/utility/color.glsl"
#include "/include/utility/fast_math.glsl"
#include "/include/utility/random.glsl"

uniform float day_factor;

struct Weather {
	float temperature; // [0, 1]
	float humidity;    // [0, 1]
	float wind;        // [0, 1]
};

Weather get_weather() {
	Weather weather;

	const float temperature_variation_speed = golden_ratio * rcp(600.0) * 1.0;
	const float humidity_variation_speed    = golden_ratio * rcp(600.0) * 1.5;
	const float wind_variation_speed        = golden_ratio * rcp(600.0) * 2.0;
	const float random_temperature_min      = 0.0;
	const float random_temperature_max      = 1.0;
	const float random_humidity_min         = 0.2;
	const float random_humidity_max         = 0.8;
	const float random_wind_min             = 0.0;
	const float random_wind_max             = 1.0;
	const float biome_temperature_influence = 0.1;
	const float biome_humidity_influence    = 0.1;

	// Random weather variation
	weather.temperature = mix(
		random_temperature_min,
		random_temperature_max,
		noise_1d(world_age * temperature_variation_speed)
	);
	weather.humidity = mix(
		random_humidity_min,
		random_humidity_max,
		noise_1d(world_age * humidity_variation_speed)
	);
	weather.wind = mix(
		random_wind_min,
		random_wind_max,
		noise_1d(world_age * wind_variation_speed)
	);

	// Time-of-day-based variation 
	weather.temperature -= 0.2 * time_sunrise + 0.2 * time_midnight;

	// Biome-based variation 
	weather.temperature += (biome_temperature - 0.6) * biome_temperature_influence;
	weather.humidity += (biome_humidity + 0.2) * biome_humidity_influence;

	// Weather-based variation
	weather.humidity += wetness;
	weather.wind += 0.33 * wetness;

	// Saturate 
	weather.temperature = clamp01(weather.temperature);
	weather.humidity    = clamp01(weather.humidity);
	weather.wind        = clamp01(weather.wind);

	return weather;
}

float clouds_cumulus_congestus_blend(Weather weather) {
	return linear_step(0.4, 0.6, weather.temperature * weather.wind);
}

float clouds_l0_cumulus_stratus_blend(Weather weather) {
	float temperature_weight = dampen(linear_step(0.5, 1.0, 1.0 - weather.temperature));
	float wind_weight = dampen(1.0 - weather.wind);

	return clamp01(temperature_weight * wind_weight);
}

vec2 clouds_l0_coverage(Weather weather, float cumulus_congestus_blend) {
	// very high temperature -> lower coverage
	// higher humidity -> higher coverage
	float temperature_weight = 1.0 - 0.33 * linear_step(0.67, 1.0, weather.temperature);
	float humidity_weight = 0.5 * weather.humidity + 0.5 * cube(weather.humidity);
	float stratus_sheet = sqr(clouds_l0_cumulus_stratus_blend(weather));
	vec2 local_variation = vec2(0.0, 1.0) * (0.2 + 0.2 * weather.wind) * (1.0 + 0.2 * stratus_sheet);

	return clamp01(temperature_weight * humidity_weight + local_variation + 0.3 * stratus_sheet) 
		* clamp01(1.0 - 2.0 * cumulus_congestus_blend);
}

vec2 clouds_l0_detail_weights(Weather weather, float cumulus_stratus_blend) {
	float wind_torn_factor = linear_step(0.66, 0.9, weather.wind) * (1.0 - cumulus_stratus_blend);

	return mix(
		vec2(0.33, 0.40) * (1.0 + 0.5 * wind_torn_factor), 
		vec2(0.07, 0.10),
		vec2(sqr(cumulus_stratus_blend), cumulus_stratus_blend)
	) * CLOUDS_CUMULUS_DETAIL_STRENGTH;
}

vec2 clouds_l0_edge_sharpening(Weather weather, float cumulus_stratus_blend) {
	return mix(vec2(3.0, 8.0), vec2(1.0, 2.0), sqr(cumulus_stratus_blend));
}

float clouds_l0_altitude_scale(Weather weather, vec2 coverage) {
	float dynamic_thickness = mix(0.5, 1.0, smoothstep(0.4, 0.6, dot(coverage, vec2(0.25, 0.75))));
	return 0.8 * rcp(dynamic_thickness * clouds_cumulus_thickness);
}

float clouds_l1_cumulus_stratus_blend(Weather weather) {
	float temperature_weight = linear_step(0.5, 0.66, 1.0 - weather.temperature);

	return cubic_smooth(temperature_weight);
}

vec2 clouds_l1_coverage(Weather weather, float cumulus_stratus_blend) {
	// Altocumulus: high temperature, high humidity, not too high temperature
	vec2 coverage_ac = weather.humidity * linear_step(0.25, 0.75, weather.wind) 
		* dampen(linear_step(0.5, 1.0, weather.temperature) 
		* linear_step(0.0, 0.1, 1.0 - weather.temperature)) * vec2(0.5, 1.5);

	// Altostratus: high wind, high humidity
	vec2 coverage_as = vec2(linear_step(0.25, 0.45, weather.wind * weather.humidity));

	return clamp01(mix(coverage_ac, coverage_as, cumulus_stratus_blend));
}

float clouds_cirrus_amount(Weather weather) {
	float temperature_weight = 0.6 + 0.4 * sqr(linear_step(0.5, 0.9, weather.temperature))
		+ 0.4 * (1.0 - linear_step(0.0, 0.2, weather.temperature));
	float humidity_weight = 1.0 - 0.33 * linear_step(0.5, 0.75, weather.humidity);

	return clamp01(0.5 * temperature_weight * humidity_weight + 0.5 * rainStrength);
}

float clouds_cirrocumulus_amount(Weather weather) {
	float temperature_weight = 0.4 + 0.6 * linear_step(0.5, 0.8, weather.temperature);
	float humidity_weight    = linear_step(0.4, 0.6, weather.humidity);

	return 0.5 * dampen(temperature_weight * humidity_weight);
}

float clouds_noctilucent_amount() {
	float intensity = hash1(fract(float(worldDay) * golden_ratio));
	intensity = linear_step(CLOUDS_NOCTILUCENT_RARITY, 1.0, intensity);

	return dampen(intensity) * CLOUDS_NOCTILUCENT_INTENSITY;
}

CloudsParameters get_clouds_parameters(Weather weather) {
	CloudsParameters params;

	// Shaping parameters

	params.cumulus_congestus_blend  = clouds_cumulus_congestus_blend(weather);

	// Volumetric layer 0 - cumulus/stratocumulus/stratus
	params.l0_cumulus_stratus_blend = clouds_l0_cumulus_stratus_blend(weather);
	params.l0_coverage              = clouds_l0_coverage(weather, params.cumulus_congestus_blend);
	params.l0_detail_weights        = clouds_l0_detail_weights(weather, params.l0_cumulus_stratus_blend);
	params.l0_edge_sharpening       = clouds_l0_edge_sharpening(weather, params.l0_cumulus_stratus_blend);
	params.l0_altitude_scale        = clouds_l0_altitude_scale(weather, params.l0_coverage);

	// Volumetric layer 1 - altocumulus/altostratus/undulatus
	params.l1_cumulus_stratus_blend = clouds_l1_cumulus_stratus_blend(weather);
	params.l1_coverage              = clouds_l1_coverage(weather, params.l1_cumulus_stratus_blend);

	// Planar clouds
	params.cirrus_amount            = clouds_cirrus_amount(weather);
	params.cirrocumulus_amount      = clouds_cirrocumulus_amount(weather);
	params.noctilucent_amount       = clouds_noctilucent_amount();

	// Lighting parameters

	params.l0_shadow = linear_step(
		0.7, 
		1.0, 
		dot(params.l1_coverage, vec2(0.25, 0.75)) * (1.0 + params.l1_cumulus_stratus_blend)
	) * dampen(day_factor);
	params.l0_extinction_coeff = mix(0.05, 0.1, smoothstep(0.0, 0.3, abs(sun_dir.y))) * (1.0 - 0.33 * rainStrength) * (1.0 - 0.6 * params.l0_shadow) * CLOUDS_CUMULUS_DENSITY;
	params.l0_extinction_coeff *= 1.0 - 0.4 * linear_step(0.8, 1.0, params.l0_coverage.y - params.l0_coverage.y * params.l0_cumulus_stratus_blend);
	params.l0_scattering_coeff = params.l0_extinction_coeff * mix(1.00, 0.66, rainStrength);

	// Crepuscular rays

	params.crepuscular_rays_amount = cube(linear_step(0.4, 0.75, dot(params.l0_coverage, vec2(0.25, 0.75))));

	return params;
}

OverworldFogParameters get_fog_parameters(Weather weather) {
	OverworldFogParameters params;

	// Rayleigh coefficient

	const vec3 rayleigh_normal = from_srgb(vec3(AIR_FOG_RAYLEIGH_R,        AIR_FOG_RAYLEIGH_G,        AIR_FOG_RAYLEIGH_B       )) * AIR_FOG_RAYLEIGH_DENSITY;
	const vec3 rayleigh_rain   = from_srgb(vec3(AIR_FOG_RAYLEIGH_R_RAIN,   AIR_FOG_RAYLEIGH_G_RAIN,   AIR_FOG_RAYLEIGH_B_RAIN  )) * AIR_FOG_RAYLEIGH_DENSITY_RAIN;
	const vec3 rayleigh_arid   = from_srgb(vec3(AIR_FOG_RAYLEIGH_R_ARID,   AIR_FOG_RAYLEIGH_G_ARID,   AIR_FOG_RAYLEIGH_B_ARID  )) * AIR_FOG_RAYLEIGH_DENSITY_ARID; const vec3 rayleigh_snowy  = from_srgb(vec3(AIR_FOG_RAYLEIGH_R_SNOWY,  AIR_FOG_RAYLEIGH_G_SNOWY,  AIR_FOG_RAYLEIGH_B_SNOWY )) * AIR_FOG_RAYLEIGH_DENSITY_SNOWY;
	const vec3 rayleigh_taiga  = from_srgb(vec3(AIR_FOG_RAYLEIGH_R_TAIGA,  AIR_FOG_RAYLEIGH_G_TAIGA,  AIR_FOG_RAYLEIGH_B_TAIGA )) * AIR_FOG_RAYLEIGH_DENSITY_TAIGA;
	const vec3 rayleigh_jungle = from_srgb(vec3(AIR_FOG_RAYLEIGH_R_JUNGLE, AIR_FOG_RAYLEIGH_G_JUNGLE, AIR_FOG_RAYLEIGH_B_JUNGLE)) * AIR_FOG_RAYLEIGH_DENSITY_JUNGLE;
	const vec3 rayleigh_swamp  = from_srgb(vec3(AIR_FOG_RAYLEIGH_R_SWAMP,  AIR_FOG_RAYLEIGH_G_SWAMP,  AIR_FOG_RAYLEIGH_B_SWAMP )) * AIR_FOG_RAYLEIGH_DENSITY_SWAMP;

	params.rayleigh_scattering_coeff 
		= rayleigh_normal * biome_temperate
		+ rayleigh_arid   * biome_arid
	    + rayleigh_snowy  * biome_snowy
		+ rayleigh_taiga  * biome_taiga
		+ rayleigh_jungle * biome_jungle
		+ rayleigh_swamp  * biome_swamp;

	// rain
	params.rayleigh_scattering_coeff = mix(
		params.rayleigh_scattering_coeff, 
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

	mie = mix(mie, AIR_FOG_MIE_DENSITY_RAIN, rainStrength * biome_may_rain);
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

#endif // INCLUDE_MISC_WEATHER
