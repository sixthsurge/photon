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

float daily_weather_fogginess(int world_day) {
	const float[] fogginess = float[12](WEATHER_D0_FOGGINESS, WEATHER_D1_FOGGINESS, WEATHER_D2_FOGGINESS, WEATHER_D3_FOGGINESS, WEATHER_D4_FOGGINESS, WEATHER_D5_FOGGINESS, WEATHER_D6_FOGGINESS, WEATHER_D7_FOGGINESS, WEATHER_D8_FOGGINESS, WEATHER_D9_FOGGINESS, WEATHER_D10_FOGGINESS, WEATHER_D11_FOGGINESS);

	return fogginess[weather_day_index(world_day)];
}

float daily_weather_overcastness(int world_day) {
#ifdef MINECRAFTY_CLOUDS
	return 0.0;
#else
	const float[] overcastness = float[12](WEATHER_D0_OVERCASTNESS, WEATHER_D1_OVERCASTNESS, WEATHER_D2_OVERCASTNESS, WEATHER_D3_OVERCASTNESS, WEATHER_D4_OVERCASTNESS, WEATHER_D5_OVERCASTNESS, WEATHER_D6_OVERCASTNESS, WEATHER_D7_OVERCASTNESS, WEATHER_D8_OVERCASTNESS, WEATHER_D9_OVERCASTNESS, WEATHER_D10_OVERCASTNESS, WEATHER_D11_OVERCASTNESS);

	return overcastness[weather_day_index(world_day)] * (1.0 - rainStrength);
#endif
}

void daily_weather_clouds(
	int world_day,
	out vec2 clouds_coverage_cu,
	out vec2 clouds_coverage_ac,
	out vec2 clouds_coverage_ci
) {
	const uint day_count = 12;

	uint day_index = weather_day_index(world_day);

	switch (day_index) {
	case 0:
		clouds_coverage_cu = vec2(WEATHER_D0_CLOUDS_CU_MIN, WEATHER_D0_CLOUDS_CU_MAX);
		clouds_coverage_ac = vec2(WEATHER_D0_CLOUDS_AC_MIN, WEATHER_D0_CLOUDS_AC_MAX);
		clouds_coverage_ci = vec2(WEATHER_D0_CLOUDS_CI, WEATHER_D0_CLOUDS_CC);
		break;

	case 1:
		clouds_coverage_cu = vec2(WEATHER_D1_CLOUDS_CU_MIN, WEATHER_D1_CLOUDS_CU_MAX);
		clouds_coverage_ac = vec2(WEATHER_D1_CLOUDS_AC_MIN, WEATHER_D1_CLOUDS_AC_MAX);
		clouds_coverage_ci = vec2(WEATHER_D1_CLOUDS_CI, WEATHER_D1_CLOUDS_CC);
		break;

	case 2:
		clouds_coverage_cu = vec2(WEATHER_D2_CLOUDS_CU_MIN, WEATHER_D2_CLOUDS_CU_MAX);
		clouds_coverage_ac = vec2(WEATHER_D2_CLOUDS_AC_MIN, WEATHER_D2_CLOUDS_AC_MAX);
		clouds_coverage_ci = vec2(WEATHER_D2_CLOUDS_CI, WEATHER_D2_CLOUDS_CC);
		break;

	case 3:
		clouds_coverage_cu = vec2(WEATHER_D3_CLOUDS_CU_MIN, WEATHER_D3_CLOUDS_CU_MAX);
		clouds_coverage_ac = vec2(WEATHER_D3_CLOUDS_AC_MIN, WEATHER_D3_CLOUDS_AC_MAX);
		clouds_coverage_ci = vec2(WEATHER_D3_CLOUDS_CI, WEATHER_D3_CLOUDS_CC);
		break;

	case 4:
		clouds_coverage_cu = vec2(WEATHER_D4_CLOUDS_CU_MIN, WEATHER_D4_CLOUDS_CU_MAX);
		clouds_coverage_ac = vec2(WEATHER_D4_CLOUDS_AC_MIN, WEATHER_D4_CLOUDS_AC_MAX);
		clouds_coverage_ci = vec2(WEATHER_D4_CLOUDS_CI, WEATHER_D4_CLOUDS_CC);
		break;

	case 5:
		clouds_coverage_cu = vec2(WEATHER_D5_CLOUDS_CU_MIN, WEATHER_D5_CLOUDS_CU_MAX);
		clouds_coverage_ac = vec2(WEATHER_D5_CLOUDS_AC_MIN, WEATHER_D5_CLOUDS_AC_MAX);
		clouds_coverage_ci = vec2(WEATHER_D5_CLOUDS_CI, WEATHER_D5_CLOUDS_CC);
		break;

	case 6:
		clouds_coverage_cu = vec2(WEATHER_D6_CLOUDS_CU_MIN, WEATHER_D6_CLOUDS_CU_MAX);
		clouds_coverage_ac = vec2(WEATHER_D6_CLOUDS_AC_MIN, WEATHER_D6_CLOUDS_AC_MAX);
		clouds_coverage_ci = vec2(WEATHER_D6_CLOUDS_CI, WEATHER_D6_CLOUDS_CC);
		break;

	case 7:
		clouds_coverage_cu = vec2(WEATHER_D7_CLOUDS_CU_MIN, WEATHER_D7_CLOUDS_CU_MAX);
		clouds_coverage_ac = vec2(WEATHER_D7_CLOUDS_AC_MIN, WEATHER_D7_CLOUDS_AC_MAX);
		clouds_coverage_ci = vec2(WEATHER_D7_CLOUDS_CI, WEATHER_D7_CLOUDS_CC);
		break;

	case 8:
		clouds_coverage_cu = vec2(WEATHER_D8_CLOUDS_CU_MIN, WEATHER_D8_CLOUDS_CU_MAX);
		clouds_coverage_ac = vec2(WEATHER_D8_CLOUDS_AC_MIN, WEATHER_D8_CLOUDS_AC_MAX);
		clouds_coverage_ci = vec2(WEATHER_D8_CLOUDS_CI, WEATHER_D8_CLOUDS_CC);
		break;

	case 9:
		clouds_coverage_cu = vec2(WEATHER_D9_CLOUDS_CU_MIN, WEATHER_D9_CLOUDS_CU_MAX);
		clouds_coverage_ac = vec2(WEATHER_D9_CLOUDS_AC_MIN, WEATHER_D9_CLOUDS_AC_MAX);
		clouds_coverage_ci = vec2(WEATHER_D9_CLOUDS_CI, WEATHER_D9_CLOUDS_CC);
		break;

	case 10:
		clouds_coverage_cu = vec2(WEATHER_D10_CLOUDS_CU_MIN, WEATHER_D10_CLOUDS_CU_MAX);
		clouds_coverage_ac = vec2(WEATHER_D10_CLOUDS_AC_MIN, WEATHER_D10_CLOUDS_AC_MAX);
		clouds_coverage_ci = vec2(WEATHER_D10_CLOUDS_CI, WEATHER_D10_CLOUDS_CC);
		break;

	case 11:
		clouds_coverage_cu = vec2(WEATHER_D11_CLOUDS_CU_MIN, WEATHER_D11_CLOUDS_CU_MAX);
		clouds_coverage_ac = vec2(WEATHER_D11_CLOUDS_AC_MIN, WEATHER_D11_CLOUDS_AC_MAX);
		clouds_coverage_ci = vec2(WEATHER_D11_CLOUDS_CI, WEATHER_D11_CLOUDS_CC);
		break;
	}
}

// Clouds

#ifdef WEATHER_CLOUDS
void clouds_weather_variation(
	out vec2 clouds_coverage_cu,
	out vec2 clouds_coverage_ac,
	out vec2 clouds_coverage_ci
) {
	// Daily weather variation

#ifdef CLOUDS_DAILY_WEATHER
	vec2 coverage_cu_0, coverage_cu_1;
	vec2 coverage_ac_0, coverage_ac_1;
	vec2 coverage_ci_0, coverage_ci_1;

	daily_weather_clouds(worldDay + 0, coverage_cu_0, coverage_ac_0, coverage_ci_0);
	daily_weather_clouds(worldDay + 1, coverage_cu_1, coverage_ac_1, coverage_ci_1);

	float mix_factor = weather_mix_factor();

	clouds_coverage_cu = mix(coverage_cu_0, coverage_cu_1, mix_factor);
	clouds_coverage_ac = mix(coverage_ac_0, coverage_ac_1, mix_factor);
	clouds_coverage_ci = mix(coverage_ci_0, coverage_ci_1, mix_factor);
#else
	clouds_coverage_cu = vec2(0.4, 0.55);
	clouds_coverage_ac = vec2(0.3, 0.5);
	clouds_coverage_ci = vec2(0.4, 0.5);
#endif

	// Weather influence

	clouds_coverage_cu = mix(clouds_coverage_cu, vec2(0.6, 0.8), wetness);
	clouds_coverage_ac = mix(clouds_coverage_ac, vec2(0.4, 0.9), wetness * 0.75);
	clouds_coverage_ci = mix(clouds_coverage_ci, vec2(0.7, 0.0), wetness * 0.50);

	// User config values

	clouds_coverage_cu *= CLOUDS_CU_COVERAGE;
	clouds_coverage_ac *= CLOUDS_AC_COVERAGE;
	clouds_coverage_ci *= vec2(CLOUDS_CI_COVERAGE, CLOUDS_CC_COVERAGE);
}
#endif

// Overworld fog

#ifdef WEATHER_FOG
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
	float blue_hour = linear_step(0.05, 1.0, exp(-190.0 * sqr(sun_dir.y + 0.07283)));

	float mie_coeff = AIR_FOG_MIE_DENSITY_MORNING  * time_sunrise
	                + AIR_FOG_MIE_DENSITY_NOON     * time_noon
	                + AIR_FOG_MIE_DENSITY_EVENING  * time_sunset
	                + AIR_FOG_MIE_DENSITY_MIDNIGHT * time_midnight
	                + AIR_FOG_MIE_DENSITY_BLUE_HOUR * blue_hour;

	mie_coeff = mix(mie_coeff, AIR_FOG_MIE_DENSITY_RAIN, rainStrength * biome_may_rain);
	mie_coeff = mix(mie_coeff, AIR_FOG_MIE_DENSITY_SNOW, rainStrength * biome_may_snow);
	mie_coeff = max(mie_coeff, mix(mie_coeff, 0.005, daily_weather_blend(daily_weather_fogginess)));

	float mie_albedo = mix(0.9, 0.5, rainStrength * biome_may_rain);

	return mat2x3(vec3(mie_coeff * mie_albedo), vec3(mie_coeff));
}
#endif

#endif // INCLUDE_MISC_WEATHER
