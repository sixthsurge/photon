#if !defined INCLUDE_MISC_WEATHER
#define INCLUDE_MISC_WEATHER

#include "/include/misc/weather_struct.glsl"
#include "/include/utility/color.glsl"
#include "/include/utility/random.glsl"

#define daily_weather_blend(weather_function) mix(weather_function(worldDay), weather_function(worldDay + 1), weather_mix_factor())

uint weather_day_index(int world_day) {
	// Start at noon
	world_day -= int(worldTime <= 6000);

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

// Clouds
void daily_weather_clouds(
	int world_day,
	out vec2 clouds_cumulus_coverage,
	out vec2 clouds_altocumulus_coverage,
	out vec2 clouds_cirrus_coverage,
	out float clouds_cumulus_congestus_amount,
	out float clouds_stratus_amount
) {
	const uint day_count = 12;

	uint day_index = weather_day_index(world_day);

	switch (day_index) {
	case 0:
		clouds_cumulus_coverage         = vec2(WEATHER_D0_CLOUDS_CUMULUS_MIN, WEATHER_D0_CLOUDS_CUMULUS_MAX);
		clouds_altocumulus_coverage     = vec2(WEATHER_D0_CLOUDS_ALTOCUMULUS_MIN, WEATHER_D0_CLOUDS_ALTOCUMULUS_MAX);
		clouds_cirrus_coverage          = vec2(WEATHER_D0_CLOUDS_CIRRUS, WEATHER_D0_CLOUDS_CIRROCUMULUS);
		clouds_cumulus_congestus_amount = WEATHER_D0_CLOUDS_CUMULUS_CONGESTUS_AMOUNT;
		clouds_stratus_amount           = WEATHER_D0_CLOUDS_STRATUS_AMOUNT;
		break;

	case 1:
		clouds_cumulus_coverage         = vec2(WEATHER_D1_CLOUDS_CUMULUS_MIN, WEATHER_D1_CLOUDS_CUMULUS_MAX);
		clouds_altocumulus_coverage     = vec2(WEATHER_D1_CLOUDS_ALTOCUMULUS_MIN, WEATHER_D1_CLOUDS_ALTOCUMULUS_MAX);
		clouds_cirrus_coverage          = vec2(WEATHER_D1_CLOUDS_CIRRUS, WEATHER_D1_CLOUDS_CIRROCUMULUS);
		clouds_cumulus_congestus_amount = WEATHER_D1_CLOUDS_CUMULUS_CONGESTUS_AMOUNT;
		clouds_stratus_amount           = WEATHER_D1_CLOUDS_STRATUS_AMOUNT;
		break;

	case 2:
		clouds_cumulus_coverage         = vec2(WEATHER_D2_CLOUDS_CUMULUS_MIN, WEATHER_D2_CLOUDS_CUMULUS_MAX);
		clouds_altocumulus_coverage     = vec2(WEATHER_D2_CLOUDS_ALTOCUMULUS_MIN, WEATHER_D2_CLOUDS_ALTOCUMULUS_MAX);
		clouds_cirrus_coverage          = vec2(WEATHER_D2_CLOUDS_CIRRUS, WEATHER_D2_CLOUDS_CIRROCUMULUS);
		clouds_cumulus_congestus_amount = WEATHER_D2_CLOUDS_CUMULUS_CONGESTUS_AMOUNT;
		clouds_stratus_amount           = WEATHER_D2_CLOUDS_STRATUS_AMOUNT;
		break;

	case 3:
		clouds_cumulus_coverage         = vec2(WEATHER_D3_CLOUDS_CUMULUS_MIN, WEATHER_D3_CLOUDS_CUMULUS_MAX);
		clouds_altocumulus_coverage     = vec2(WEATHER_D3_CLOUDS_ALTOCUMULUS_MIN, WEATHER_D3_CLOUDS_ALTOCUMULUS_MAX);
		clouds_cirrus_coverage          = vec2(WEATHER_D3_CLOUDS_CIRRUS, WEATHER_D3_CLOUDS_CIRROCUMULUS);
		clouds_cumulus_congestus_amount = WEATHER_D3_CLOUDS_CUMULUS_CONGESTUS_AMOUNT;
		clouds_stratus_amount           = WEATHER_D3_CLOUDS_STRATUS_AMOUNT;
		break;

	case 4:
		clouds_cumulus_coverage         = vec2(WEATHER_D4_CLOUDS_CUMULUS_MIN, WEATHER_D4_CLOUDS_CUMULUS_MAX);
		clouds_altocumulus_coverage     = vec2(WEATHER_D4_CLOUDS_ALTOCUMULUS_MIN, WEATHER_D4_CLOUDS_ALTOCUMULUS_MAX);
		clouds_cirrus_coverage          = vec2(WEATHER_D4_CLOUDS_CIRRUS, WEATHER_D4_CLOUDS_CIRROCUMULUS);
		clouds_cumulus_congestus_amount = WEATHER_D4_CLOUDS_CUMULUS_CONGESTUS_AMOUNT;
		clouds_stratus_amount           = WEATHER_D4_CLOUDS_STRATUS_AMOUNT;
		break;

	case 5:
		clouds_cumulus_coverage         = vec2(WEATHER_D5_CLOUDS_CUMULUS_MIN, WEATHER_D5_CLOUDS_CUMULUS_MAX);
		clouds_altocumulus_coverage     = vec2(WEATHER_D5_CLOUDS_ALTOCUMULUS_MIN, WEATHER_D5_CLOUDS_ALTOCUMULUS_MAX);
		clouds_cirrus_coverage          = vec2(WEATHER_D5_CLOUDS_CIRRUS, WEATHER_D5_CLOUDS_CIRROCUMULUS);
		clouds_cumulus_congestus_amount = WEATHER_D5_CLOUDS_CUMULUS_CONGESTUS_AMOUNT;
		clouds_stratus_amount           = WEATHER_D5_CLOUDS_STRATUS_AMOUNT;
		break;

	case 6:
		clouds_cumulus_coverage         = vec2(WEATHER_D6_CLOUDS_CUMULUS_MIN, WEATHER_D6_CLOUDS_CUMULUS_MAX);
		clouds_altocumulus_coverage     = vec2(WEATHER_D6_CLOUDS_ALTOCUMULUS_MIN, WEATHER_D6_CLOUDS_ALTOCUMULUS_MAX);
		clouds_cirrus_coverage          = vec2(WEATHER_D6_CLOUDS_CIRRUS, WEATHER_D6_CLOUDS_CIRROCUMULUS);
		clouds_cumulus_congestus_amount = WEATHER_D6_CLOUDS_CUMULUS_CONGESTUS_AMOUNT;
		clouds_stratus_amount           = WEATHER_D6_CLOUDS_STRATUS_AMOUNT;
		break;

	case 7:
		clouds_cumulus_coverage         = vec2(WEATHER_D7_CLOUDS_CUMULUS_MIN, WEATHER_D7_CLOUDS_CUMULUS_MAX);
		clouds_altocumulus_coverage     = vec2(WEATHER_D7_CLOUDS_ALTOCUMULUS_MIN, WEATHER_D7_CLOUDS_ALTOCUMULUS_MAX);
		clouds_cirrus_coverage          = vec2(WEATHER_D7_CLOUDS_CIRRUS, WEATHER_D7_CLOUDS_CIRROCUMULUS);
		clouds_cumulus_congestus_amount = WEATHER_D7_CLOUDS_CUMULUS_CONGESTUS_AMOUNT;
		clouds_stratus_amount           = WEATHER_D7_CLOUDS_STRATUS_AMOUNT;
		break;

	case 8:
		clouds_cumulus_coverage         = vec2(WEATHER_D8_CLOUDS_CUMULUS_MIN, WEATHER_D8_CLOUDS_CUMULUS_MAX);
		clouds_altocumulus_coverage     = vec2(WEATHER_D8_CLOUDS_ALTOCUMULUS_MIN, WEATHER_D8_CLOUDS_ALTOCUMULUS_MAX);
		clouds_cirrus_coverage          = vec2(WEATHER_D8_CLOUDS_CIRRUS, WEATHER_D8_CLOUDS_CIRROCUMULUS);
		clouds_cumulus_congestus_amount = WEATHER_D8_CLOUDS_CUMULUS_CONGESTUS_AMOUNT;
		clouds_stratus_amount           = WEATHER_D8_CLOUDS_STRATUS_AMOUNT;
		break;

	case 9:
		clouds_cumulus_coverage         = vec2(WEATHER_D9_CLOUDS_CUMULUS_MIN, WEATHER_D9_CLOUDS_CUMULUS_MAX);
		clouds_altocumulus_coverage     = vec2(WEATHER_D9_CLOUDS_ALTOCUMULUS_MIN, WEATHER_D9_CLOUDS_ALTOCUMULUS_MAX);
		clouds_cirrus_coverage          = vec2(WEATHER_D9_CLOUDS_CIRRUS, WEATHER_D9_CLOUDS_CIRROCUMULUS);
		clouds_cumulus_congestus_amount = WEATHER_D9_CLOUDS_CUMULUS_CONGESTUS_AMOUNT;
		clouds_stratus_amount           = WEATHER_D9_CLOUDS_STRATUS_AMOUNT;
		break;

	case 10:
		clouds_cumulus_coverage         = vec2(WEATHER_D10_CLOUDS_CUMULUS_MIN, WEATHER_D10_CLOUDS_CUMULUS_MAX);
		clouds_altocumulus_coverage     = vec2(WEATHER_D10_CLOUDS_ALTOCUMULUS_MIN, WEATHER_D10_CLOUDS_ALTOCUMULUS_MAX);
		clouds_cirrus_coverage          = vec2(WEATHER_D10_CLOUDS_CIRRUS, WEATHER_D10_CLOUDS_CIRROCUMULUS);
		clouds_cumulus_congestus_amount = WEATHER_D10_CLOUDS_CUMULUS_CONGESTUS_AMOUNT;
		clouds_stratus_amount           = WEATHER_D10_CLOUDS_STRATUS_AMOUNT;
		break;

	case 11:
		clouds_cumulus_coverage         = vec2(WEATHER_D11_CLOUDS_CUMULUS_MIN, WEATHER_D11_CLOUDS_CUMULUS_MAX);
		clouds_altocumulus_coverage     = vec2(WEATHER_D11_CLOUDS_ALTOCUMULUS_MIN, WEATHER_D11_CLOUDS_ALTOCUMULUS_MAX);
		clouds_cirrus_coverage          = vec2(WEATHER_D11_CLOUDS_CIRRUS, WEATHER_D11_CLOUDS_CIRROCUMULUS);
		clouds_cumulus_congestus_amount = WEATHER_D11_CLOUDS_CUMULUS_CONGESTUS_AMOUNT;
		clouds_stratus_amount           = WEATHER_D11_CLOUDS_STRATUS_AMOUNT;
		break;
	}
}

void clouds_weather_variation(
	out vec2 clouds_cumulus_coverage,
	out vec2 clouds_altocumulus_coverage,
	out vec2 clouds_cirrus_coverage,
	out float clouds_cumulus_congestus_amount,
	out float clouds_stratus_amount
) {
	// Daily weather variation

#ifdef CLOUDS_DAILY_WEATHER
	vec2 coverage_cu_0, coverage_cu_1;
	vec2 coverage_ac_0, coverage_ac_1;
	vec2 coverage_ci_0, coverage_ci_1;
	float cu_con_0, cu_con_1;
	float stratus_0, stratus_1;

	daily_weather_clouds(worldDay + 0, coverage_cu_0, coverage_ac_0, coverage_ci_0, cu_con_0, stratus_0);
	daily_weather_clouds(worldDay + 1, coverage_cu_1, coverage_ac_1, coverage_ci_1, cu_con_1, stratus_1);

	float mix_factor = weather_mix_factor();

	clouds_cumulus_coverage         = mix(coverage_cu_0, coverage_cu_1, mix_factor);
	clouds_altocumulus_coverage     = mix(coverage_ac_0, coverage_ac_1, mix_factor);
	clouds_cirrus_coverage          = mix(coverage_ci_0, coverage_ci_1, mix_factor);
	clouds_cumulus_congestus_amount = mix(cu_con_0, cu_con_1, mix_factor);
	clouds_stratus_amount           = mix(stratus_0, stratus_1, mix_factor);
#else
	clouds_cumulus_coverage         = vec2(0.4, 0.55);
	clouds_altocumulus_coverage     = vec2(0.3, 0.5);
	clouds_cirrus_coverage          = vec2(0.4, 0.5);
	clouds_cumulus_congestus_amount = 0.0;
	clouds_stratus_amount           = 0.0;
#endif

	// Weather influence

	clouds_cumulus_coverage = mix(clouds_cumulus_coverage, vec2(0.6, 0.8), wetness);
	clouds_altocumulus_coverage = mix(clouds_altocumulus_coverage, vec2(0.4, 0.9), wetness * 0.75);
	clouds_cirrus_coverage.x = mix(clouds_cirrus_coverage.x, 0.7, wetness * 0.50);
	clouds_cumulus_congestus_amount *= 1.0 - wetness;
	clouds_stratus_amount = clamp01(clouds_stratus_amount + 0.7 * wetness);

	// User config values

	clouds_cumulus_coverage *= CLOUDS_CUMULUS_COVERAGE;
	clouds_altocumulus_coverage *= CLOUDS_ALTOCUMULUS_COVERAGE;
	clouds_cirrus_coverage *= CLOUDS_CIRRUS_COVERAGE;
}

// [0] - bottom color
// [1] - top color
mat2x3 get_aurora_colors() {
	const mat2x3[] aurora_colors = mat2x3[](
		mat2x3(
			vec3(0.00, 1.00, 0.25), // green
			vec3(0.50, 0.70, 1.00)  // blue
		)
		, mat2x3(
			vec3(0.00, 1.00, 0.25), // green
			vec3(0.50, 0.70, 1.00)  // blue
		)
		, mat2x3(
			vec3(1.00, 0.00, 0.00), // red
			vec3(1.00, 0.50, 0.70)  // purple
		)
		, mat2x3(
			vec3(1.00, 0.25, 1.00), // magenta
			vec3(0.25, 0.25, 1.00)  // deep blue
		)
		, mat2x3(
			vec3(1.00, 0.50, 1.00), // purple
			vec3(0.50, 0.70, 1.00)  // blue
		)
		, mat2x3(
			vec3(1.00, 0.50, 1.00), // purple
			vec3(0.50, 0.70, 1.00)  // blue
		)
		, mat2x3(
			vec3(1.00, 0.10, 0.00), // red
			vec3(1.00, 1.00, 0.25)  // yellow
		)
		, mat2x3(
			vec3(1.00, 1.00, 1.00), // white
			vec3(1.00, 0.00, 0.00)  // red
		)
		, mat2x3(
			vec3(1.00, 1.00, 0.00), // yellow
			vec3(0.10, 0.50, 1.00)  // blue
		)
		, mat2x3(
			vec3(1.00, 0.25, 1.00), // magenta
			vec3(0.00, 1.00, 0.25)  // green
		)
		, mat2x3(
			vec3(1.00, 0.70, 1.00) * 1.2, // pink
			vec3(0.90, 0.30, 0.90)  // purple
		)
		, mat2x3(
			vec3(0.00, 1.00, 0.25), // green
			vec3(0.90, 0.30, 0.90)  // purple
		)
		, mat2x3(
			vec3(2.00, 0.80, 0.00), // orange
			vec3(1.00, 0.50, 0.00)  // orange
		)
	);

	uint day_index = uint(worldDay);
	     day_index = lowbias32(day_index) % aurora_colors.length();

	return aurora_colors[day_index];
}

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

// 0.0 - no aurora
// 1.0 - full NLC
float get_nlc_amount() {
	float intensity = hash1(fract(float(worldDay) * golden_ratio));
	intensity = linear_step(CLOUDS_NOCTILUCENT_RARITY, 1.0, intensity);

	return dampen(intensity) * CLOUDS_NOCTILUCENT_INTENSITY;
}

DailyWeatherVariation get_daily_weather_variation() {
	DailyWeatherVariation daily_weather_variation;

	clouds_weather_variation(
		daily_weather_variation.clouds_cumulus_coverage,
		daily_weather_variation.clouds_altocumulus_coverage,
		daily_weather_variation.clouds_cirrus_coverage,
		daily_weather_variation.clouds_cumulus_congestus_amount,
		daily_weather_variation.clouds_stratus_amount
	);

	daily_weather_variation.fogginess = daily_weather_blend(daily_weather_fogginess);
	daily_weather_variation.nlc_amount = get_nlc_amount();
	daily_weather_variation.aurora_amount = get_aurora_amount();
	daily_weather_variation.aurora_colors = get_aurora_colors();

	return daily_weather_variation;
}

#endif // INCLUDE_MISC_WEATHEcolorR
