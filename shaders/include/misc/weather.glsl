#if !defined INCLUDE_MISC_WEATHER
#define INCLUDE_MISC_WEATHER

#include "/include/utility/color.glsl"
#include "/include/utility/random.glsl"

#define daily_weather_blend(weather_function) mix(weather_function(worldDay), weather_function(worldDay + 1), weather_mix_factor())

uint weather_day_index(int world_day) {
	// Start at noon
	world_day -= int(worldTime < 6000);

	const uint day_count = 12;

#if WEATHER_DAY == -1
	uint day_index = uint(world_day);
	     day_index = lowbias32(day_index) % day_count;
#else
	uint day_index = WEATHER_DAY;
#endif

	return day_index;
}

float weather_mix_factor() {
	return cubic_smooth(fract(float(worldTime) * rcp(24000.0) - 0.25));
}

float daily_weather_overcastness(int world_day) {
	const float[] overcastness = float[12](WEATHER_D0_OVERCASTNESS, WEATHER_D1_OVERCASTNESS, WEATHER_D2_OVERCASTNESS, WEATHER_D3_OVERCASTNESS, WEATHER_D4_OVERCASTNESS, WEATHER_D5_OVERCASTNESS, WEATHER_D6_OVERCASTNESS, WEATHER_D7_OVERCASTNESS, WEATHER_D8_OVERCASTNESS, WEATHER_D9_OVERCASTNESS, WEATHER_D10_OVERCASTNESS, WEATHER_D11_OVERCASTNESS);

	return overcastness[weather_day_index(world_day)];
}

float daily_weather_fogginess(int world_day) {
	const float[] fogginess = float[12](WEATHER_D0_FOGGINESS, WEATHER_D1_FOGGINESS, WEATHER_D2_FOGGINESS, WEATHER_D3_FOGGINESS, WEATHER_D4_FOGGINESS, WEATHER_D5_FOGGINESS, WEATHER_D6_FOGGINESS, WEATHER_D7_FOGGINESS, WEATHER_D8_FOGGINESS, WEATHER_D9_FOGGINESS, WEATHER_D10_FOGGINESS, WEATHER_D11_FOGGINESS);

	return fogginess[weather_day_index(world_day)];
}

// Clouds

#ifdef WEATHER_CLOUDS
void daily_weather_clouds(
	int world_day,
	out vec2 clouds_cumulus_coverage,
	out vec2 clouds_altocumulus_coverage,
	out vec2 clouds_cirrus_coverage,
	out float clouds_cumulus_congestus_amount,
	out float clouds_cumulonimbus_amount,
	out float clouds_stratus_amount
) {
	const uint day_count = 12;

	uint day_index = weather_day_index(world_day);

	switch (day_index) {
	case 0:
		clouds_cumulus_coverage         = vec2(WEATHER_D0_CLOUDS_CUMULUS_MIN, WEATHER_D0_CLOUDS_CUMULUS_MAX);
		clouds_altocumulus_coverage     = vec2(WEATHER_D0_CLOUDS_ALTOCUMULUS_MIN, WEATHER_D0_CLOUDS_ALTOCUMULUS_MAX);
		clouds_cirrus_coverage          = vec2(WEATHER_D0_CLOUDS_CIRRUS, WEATHER_D0_CLOUDS_CC);
		clouds_cumulus_congestus_amount = WEATHER_D0_CLOUDS_CUMULUS_CONGESTUS_AMOUNT;
		clouds_cumulonimbus_amount      = WEATHER_D0_CLOUDS_CUMULONIMBUS_AMOUNT;
		clouds_stratus_amount           = WEATHER_D0_CLOUDS_STRATUS_AMOUNT;
		break;

	case 1:
		clouds_cumulus_coverage         = vec2(WEATHER_D1_CLOUDS_CUMULUS_MIN, WEATHER_D1_CLOUDS_CUMULUS_MAX);
		clouds_altocumulus_coverage     = vec2(WEATHER_D1_CLOUDS_ALTOCUMULUS_MIN, WEATHER_D1_CLOUDS_ALTOCUMULUS_MAX);
		clouds_cirrus_coverage          = vec2(WEATHER_D1_CLOUDS_CIRRUS, WEATHER_D1_CLOUDS_CC);
		clouds_cumulus_congestus_amount = WEATHER_D1_CLOUDS_CUMULUS_CONGESTUS_AMOUNT;
		clouds_cumulonimbus_amount      = WEATHER_D1_CLOUDS_CUMULONIMBUS_AMOUNT;
		clouds_stratus_amount           = WEATHER_D1_CLOUDS_STRATUS_AMOUNT;
		break;

	case 2:
		clouds_cumulus_coverage         = vec2(WEATHER_D2_CLOUDS_CUMULUS_MIN, WEATHER_D2_CLOUDS_CUMULUS_MAX);
		clouds_altocumulus_coverage     = vec2(WEATHER_D2_CLOUDS_ALTOCUMULUS_MIN, WEATHER_D2_CLOUDS_ALTOCUMULUS_MAX);
		clouds_cirrus_coverage          = vec2(WEATHER_D2_CLOUDS_CIRRUS, WEATHER_D2_CLOUDS_CC);
		clouds_cumulus_congestus_amount = WEATHER_D2_CLOUDS_CUMULUS_CONGESTUS_AMOUNT;
		clouds_cumulonimbus_amount      = WEATHER_D2_CLOUDS_CUMULONIMBUS_AMOUNT;
		clouds_stratus_amount           = WEATHER_D2_CLOUDS_STRATUS_AMOUNT;
		break;

	case 3:
		clouds_cumulus_coverage         = vec2(WEATHER_D3_CLOUDS_CUMULUS_MIN, WEATHER_D3_CLOUDS_CUMULUS_MAX);
		clouds_altocumulus_coverage     = vec2(WEATHER_D3_CLOUDS_ALTOCUMULUS_MIN, WEATHER_D3_CLOUDS_ALTOCUMULUS_MAX);
		clouds_cirrus_coverage          = vec2(WEATHER_D3_CLOUDS_CIRRUS, WEATHER_D3_CLOUDS_CC);
		clouds_cumulus_congestus_amount = WEATHER_D3_CLOUDS_CUMULUS_CONGESTUS_AMOUNT;
		clouds_cumulonimbus_amount      = WEATHER_D3_CLOUDS_CUMULONIMBUS_AMOUNT;
		clouds_stratus_amount           = WEATHER_D3_CLOUDS_STRATUS_AMOUNT;
		break;

	case 4:
		clouds_cumulus_coverage         = vec2(WEATHER_D4_CLOUDS_CUMULUS_MIN, WEATHER_D4_CLOUDS_CUMULUS_MAX);
		clouds_altocumulus_coverage     = vec2(WEATHER_D4_CLOUDS_ALTOCUMULUS_MIN, WEATHER_D4_CLOUDS_ALTOCUMULUS_MAX);
		clouds_cirrus_coverage          = vec2(WEATHER_D4_CLOUDS_CIRRUS, WEATHER_D4_CLOUDS_CC);
		clouds_cumulus_congestus_amount = WEATHER_D4_CLOUDS_CUMULUS_CONGESTUS_AMOUNT;
		clouds_cumulonimbus_amount      = WEATHER_D4_CLOUDS_CUMULONIMBUS_AMOUNT;
		clouds_stratus_amount           = WEATHER_D4_CLOUDS_STRATUS_AMOUNT;
		break;

	case 5:
		clouds_cumulus_coverage         = vec2(WEATHER_D5_CLOUDS_CUMULUS_MIN, WEATHER_D5_CLOUDS_CUMULUS_MAX);
		clouds_altocumulus_coverage     = vec2(WEATHER_D5_CLOUDS_ALTOCUMULUS_MIN, WEATHER_D5_CLOUDS_ALTOCUMULUS_MAX);
		clouds_cirrus_coverage          = vec2(WEATHER_D5_CLOUDS_CIRRUS, WEATHER_D5_CLOUDS_CC);
		clouds_cumulus_congestus_amount = WEATHER_D5_CLOUDS_CUMULUS_CONGESTUS_AMOUNT;
		clouds_cumulonimbus_amount      = WEATHER_D5_CLOUDS_CUMULONIMBUS_AMOUNT;
		clouds_stratus_amount           = WEATHER_D5_CLOUDS_STRATUS_AMOUNT;
		break;

	case 6:
		clouds_cumulus_coverage         = vec2(WEATHER_D6_CLOUDS_CUMULUS_MIN, WEATHER_D6_CLOUDS_CUMULUS_MAX);
		clouds_altocumulus_coverage     = vec2(WEATHER_D6_CLOUDS_ALTOCUMULUS_MIN, WEATHER_D6_CLOUDS_ALTOCUMULUS_MAX);
		clouds_cirrus_coverage          = vec2(WEATHER_D6_CLOUDS_CIRRUS, WEATHER_D6_CLOUDS_CC);
		clouds_cumulus_congestus_amount = WEATHER_D6_CLOUDS_CUMULUS_CONGESTUS_AMOUNT;
		clouds_cumulonimbus_amount      = WEATHER_D6_CLOUDS_CUMULONIMBUS_AMOUNT;
		clouds_stratus_amount           = WEATHER_D6_CLOUDS_STRATUS_AMOUNT;
		break;

	case 7:
		clouds_cumulus_coverage         = vec2(WEATHER_D7_CLOUDS_CUMULUS_MIN, WEATHER_D7_CLOUDS_CUMULUS_MAX);
		clouds_altocumulus_coverage     = vec2(WEATHER_D7_CLOUDS_ALTOCUMULUS_MIN, WEATHER_D7_CLOUDS_ALTOCUMULUS_MAX);
		clouds_cirrus_coverage          = vec2(WEATHER_D7_CLOUDS_CIRRUS, WEATHER_D7_CLOUDS_CC);
		clouds_cumulus_congestus_amount = WEATHER_D7_CLOUDS_CUMULUS_CONGESTUS_AMOUNT;
		clouds_cumulonimbus_amount      = WEATHER_D7_CLOUDS_CUMULONIMBUS_AMOUNT;
		clouds_stratus_amount           = WEATHER_D7_CLOUDS_STRATUS_AMOUNT;
		break;

	case 8:
		clouds_cumulus_coverage         = vec2(WEATHER_D8_CLOUDS_CUMULUS_MIN, WEATHER_D8_CLOUDS_CUMULUS_MAX);
		clouds_altocumulus_coverage     = vec2(WEATHER_D8_CLOUDS_ALTOCUMULUS_MIN, WEATHER_D8_CLOUDS_ALTOCUMULUS_MAX);
		clouds_cirrus_coverage          = vec2(WEATHER_D8_CLOUDS_CIRRUS, WEATHER_D8_CLOUDS_CC);
		clouds_cumulus_congestus_amount = WEATHER_D8_CLOUDS_CUMULUS_CONGESTUS_AMOUNT;
		clouds_cumulonimbus_amount      = WEATHER_D8_CLOUDS_CUMULONIMBUS_AMOUNT;
		clouds_stratus_amount           = WEATHER_D8_CLOUDS_STRATUS_AMOUNT;
		break;

	case 9:
		clouds_cumulus_coverage         = vec2(WEATHER_D9_CLOUDS_CUMULUS_MIN, WEATHER_D9_CLOUDS_CUMULUS_MAX);
		clouds_altocumulus_coverage     = vec2(WEATHER_D9_CLOUDS_ALTOCUMULUS_MIN, WEATHER_D9_CLOUDS_ALTOCUMULUS_MAX);
		clouds_cirrus_coverage          = vec2(WEATHER_D9_CLOUDS_CIRRUS, WEATHER_D9_CLOUDS_CC);
		clouds_cumulus_congestus_amount = WEATHER_D9_CLOUDS_CUMULUS_CONGESTUS_AMOUNT;
		clouds_cumulonimbus_amount      = WEATHER_D9_CLOUDS_CUMULONIMBUS_AMOUNT;
		clouds_stratus_amount           = WEATHER_D9_CLOUDS_STRATUS_AMOUNT;
		break;

	case 10:
		clouds_cumulus_coverage         = vec2(WEATHER_D10_CLOUDS_CUMULUS_MIN, WEATHER_D10_CLOUDS_CUMULUS_MAX);
		clouds_altocumulus_coverage     = vec2(WEATHER_D10_CLOUDS_ALTOCUMULUS_MIN, WEATHER_D10_CLOUDS_ALTOCUMULUS_MAX);
		clouds_cirrus_coverage          = vec2(WEATHER_D10_CLOUDS_CIRRUS, WEATHER_D10_CLOUDS_CC);
		clouds_cumulus_congestus_amount = WEATHER_D10_CLOUDS_CUMULUS_CONGESTUS_AMOUNT;
		clouds_cumulonimbus_amount      = WEATHER_D10_CLOUDS_CUMULONIMBUS_AMOUNT;
		clouds_stratus_amount           = WEATHER_D10_CLOUDS_STRATUS_AMOUNT;
		break;

	case 11:
		clouds_cumulus_coverage         = vec2(WEATHER_D11_CLOUDS_CUMULUS_MIN, WEATHER_D11_CLOUDS_CUMULUS_MAX);
		clouds_altocumulus_coverage     = vec2(WEATHER_D11_CLOUDS_ALTOCUMULUS_MIN, WEATHER_D11_CLOUDS_ALTOCUMULUS_MAX);
		clouds_cirrus_coverage          = vec2(WEATHER_D11_CLOUDS_CIRRUS, WEATHER_D11_CLOUDS_CC);
		clouds_cumulus_congestus_amount = WEATHER_D11_CLOUDS_CUMULUS_CONGESTUS_AMOUNT;
		clouds_cumulonimbus_amount      = WEATHER_D11_CLOUDS_CUMULONIMBUS_AMOUNT;
		clouds_stratus_amount           = WEATHER_D11_CLOUDS_STRATUS_AMOUNT;
		break;
	}
}

void clouds_weather_variation(
	out vec2 clouds_cumulus_coverage,
	out vec2 clouds_altocumulus_coverage,
	out vec2 clouds_cirrus_coverage,
	out float clouds_cumulus_congestus_amount,
	out float clouds_cumulonimbus_amount,
	out float clouds_stratus_amount
) {
	// Daily weather variation

#ifdef CLOUDS_DAILY_WEATHER
	vec2 coverage_cu_0, coverage_cu_1;
	vec2 coverage_ac_0, coverage_ac_1;
	vec2 coverage_ci_0, coverage_ci_1;
	float cu_con_0, cu_con_1;
	float cb_0, cb_1;
	float stratus_0, stratus_1;

	daily_weather_clouds(worldDay + 0, coverage_cu_0, coverage_ac_0, coverage_ci_0, cu_con_0, cb_0, stratus_0);
	daily_weather_clouds(worldDay + 1, coverage_cu_1, coverage_ac_1, coverage_ci_1, cu_con_1, cb_1, stratus_1);

	float mix_factor = weather_mix_factor();

	clouds_cumulus_coverage         = mix(coverage_cu_0, coverage_cu_1, mix_factor);
	clouds_altocumulus_coverage     = mix(coverage_ac_0, coverage_ac_1, mix_factor);
	clouds_cirrus_coverage          = mix(coverage_ci_0, coverage_ci_1, mix_factor);
	clouds_cumulus_congestus_amount = mix(cu_con_0, cu_con_1, mix_factor);
	clouds_cumulonimbus_amount      = mix(cb_0, cb_1, mix_factor);
	clouds_stratus_amount           = mix(stratus_0, stratus_1, mix_factor);
#else
	clouds_cumulus_coverage         = vec2(0.4, 0.55);
	clouds_altocumulus_coverage     = vec2(0.3, 0.5);
	clouds_cirrus_coverage          = vec2(0.4, 0.5);
	clouds_cumulus_congestus_amount = 0.0;
	clouds_cumulonimbus_amount      = 0.0;
	clouds_stratus_amount           = 0.0;
#endif

	// Weather influence

	clouds_cumulus_coverage = mix(clouds_cumulus_coverage, vec2(0.6, 0.8), wetness);
	clouds_altocumulus_coverage = mix(clouds_altocumulus_coverage, vec2(0.4, 0.9), wetness * 0.75);
	clouds_cirrus_coverage = mix(clouds_cirrus_coverage, vec2(0.7, 0.0), wetness * 0.50);
	clouds_cumulus_congestus_amount *= 1.0 - wetness;
	clouds_cumulonimbus_amount *= mix(clouds_cumulonimbus_amount, 1.5 * wetness, wetness); // mix(clamp01(1.0 - 1.75 * wetness) ...
	clouds_stratus_amount = clamp01(clouds_stratus_amount + 0.7 * wetness);

	// User config values

	clouds_cumulus_coverage *= CLOUDS_CUMULUS_COVERAGE;
	clouds_altocumulus_coverage *= CLOUDS_ALTOCUMULUS_COVERAGE;
	clouds_cirrus_coverage *= vec2(CLOUDS_CIRRUS_COVERAGE, CLOUDS_CC_COVERAGE);
	clouds_cumulus_congestus_amount *= CLOUDS_CUMULUS_CONGESTUS_COVERAGE;
	clouds_cumulonimbus_amount *= CLOUDS_CUMULONIMBUS_COVERAGE;

}
#endif

// Overworld fog

#ifdef WEATHER_FOG
uniform float desert_sandstorm;

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

	// Rain
	rayleigh = mix(rayleigh, rayleigh_rain, rainStrength * biome_may_rain);

	// Daily weather
	float fogginess = daily_weather_blend(daily_weather_fogginess);
	rayleigh *= 1.0 + 2.0 * fogginess;

	return mat2x3(rayleigh, rayleigh);
}

mat2x3 air_fog_mie_coeff() {
	// Increased mie density during late sunset / blue hour
	float blue_hour = linear_step(0.05, 1.0, exp(-190.0 * sqr(sun_dir.y + 0.07283)));

	float mie_coeff = AIR_FOG_MIE_DENSITY_MORNING  * time_sunrise
	                + AIR_FOG_MIE_DENSITY_NOON     * time_noon
	                + AIR_FOG_MIE_DENSITY_EVENING  * time_sunset
	                + AIR_FOG_MIE_DENSITY_MIDNIGHT * time_midnight
	                + AIR_FOG_MIE_DENSITY_BLUE_HOUR * blue_hour;

	mie_coeff = mix(mie_coeff, AIR_FOG_MIE_DENSITY_RAIN, rainStrength * biome_may_rain);
	mie_coeff = mix(mie_coeff, AIR_FOG_MIE_DENSITY_SNOW, rainStrength * biome_may_snow);

	float mie_albedo = mix(0.9, 0.5, rainStrength * biome_may_rain);

	vec3 scattering_coeff = vec3(mie_coeff * mie_albedo);
	vec3 extinction_coeff = vec3(mie_coeff);

#ifdef DESERT_SANDSTORM
	const float desert_sandstorm_density    = 0.2;
	const float desert_sandstorm_scattering = 0.5;
	const vec3  desert_sandstorm_extinction = vec3(0.2, 0.27, 0.45);

	scattering_coeff += desert_sandstorm * (desert_sandstorm_density * desert_sandstorm_scattering);
	extinction_coeff += desert_sandstorm * (desert_sandstorm_density * desert_sandstorm_extinction);
#endif

	return mat2x3(scattering_coeff, extinction_coeff);
}
#endif

// Aurora

#ifdef WEATHER_AURORA
// 0.0 - no aurora
// 1.0 - full aurora
float get_aurora_amount() {
	float night = smoothstep(0.0, 0.2, -sun_dir.y);

#if   AURORA_NORMAL == AURORA_NEVER
	float aurora_normal = 0.0;
#elif AURORA_NORMAL == AURORA_RARELY
	float aurora_normal = float(lowbias32(uint(worldDay)) % 5 == 1);
#elif AURORA_NORMAL == AURORA_ALWAYS
	float aurora_normal = 1.0;
#endif

#if   AURORA_SNOW == AURORA_NEVER
	float aurora_snow = 0.0;
#elif AURORA_SNOW == AURORA_RARELY
	float aurora_snow = float(lowbias32(uint(worldDay)) % 5 == 1);
#elif AURORA_SNOW == AURORA_ALWAYS
	float aurora_snow = 1.0;
#endif

	return night * mix(aurora_normal, aurora_snow, biome_may_snow);
}

// [0] - bottom color
// [1] - top color
mat2x3 get_aurora_colors() {
	const mat2x3[] aurora_colors = mat2x3[](
		mat2x3( // 0 [D]
			vec3(0.00, 1.00, 0.25), // green
			vec3(0.50, 0.70, 1.00)  // blue
		)
		, mat2x3( // 1
			vec3(0.00, 1.00, 0.25), // green
			vec3(0.50, 0.70, 1.00)  // blue
		)
		, mat2x3( // 2
			vec3(1.00, 0.00, 0.00), // red
			vec3(1.00, 0.50, 0.70)  // purple
		)
		, mat2x3( // 3
			vec3(1.00, 0.25, 1.00), // magenta
			vec3(0.25, 0.25, 1.00)  // deep blue
		)
		, mat2x3( // 4
			vec3(1.00, 0.50, 1.00), // purple
			vec3(0.50, 0.70, 1.00)  // blue
		)
		, mat2x3( // 5 [D]
			vec3(1.00, 0.50, 1.00), // purple
			vec3(0.50, 0.70, 1.00)  // blue
		)
		, mat2x3( // 6
			vec3(1.00, 0.10, 0.00), // red
			vec3(1.00, 1.00, 0.25)  // yellow
		)
		, mat2x3( // 7
			vec3(1.00, 1.00, 1.00), // white
			vec3(1.00, 0.00, 0.00)  // red
		)
		, mat2x3( // 8
			vec3(1.00, 1.00, 0.00), // yellow
			vec3(0.10, 0.50, 1.00)  // blue
		)
		, mat2x3( // 9
			vec3(1.00, 0.25, 1.00), // magenta
			vec3(0.00, 1.00, 0.25)  // green
		)
		, mat2x3( // 10
			vec3(1.00, 0.70, 1.00) * 1.2, // pink
			vec3(0.90, 0.30, 0.90)  // purple
		)
		, mat2x3( // 11
			vec3(0.00, 1.00, 0.25), // green
			vec3(0.90, 0.30, 0.90)  // purple
		)
		, mat2x3( // 12
			vec3(2.00, 0.80, 0.00), // orange
			vec3(1.00, 0.50, 0.00)  // orange
		)
	);

	if(AURORA_COLOR == 0) {
		uint day_index = uint(worldDay);
			 day_index = lowbias32(day_index) % aurora_colors.length();
		return aurora_colors[day_index];
	} else {
		return aurora_colors[uint(AURORA_COLOR)];
	}

}
#endif

#endif // INCLUDE_MISC_WEATHER
