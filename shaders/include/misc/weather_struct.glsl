#if !defined INCLUDE_MISC_WEATHER_STRUCT
#define INCLUDE_MISC_WEATHER_STRUCT

struct DailyWeatherVariation {
	vec2 clouds_cumulus_coverage;
	vec2 clouds_altocumulus_coverage;
	vec2 clouds_cirrus_coverage;

	float clouds_cumulus_congestus_amount;
	float clouds_stratus_amount;

	float fogginess;

	float aurora_amount;
	float nlc_amount;
	mat2x3 aurora_colors;
};

#endif // INCLUDE_MISC_WEATHER_STRUCT
