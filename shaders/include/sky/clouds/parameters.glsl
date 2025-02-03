#if !defined INCLUDE_SKY_CLOUDS_PARAMETERS
#define INCLUDE_SKY_CLOUDS_PARAMETERS

struct CloudsParameters {
	float cumulus_congestus_blend; // replaces layer 0
	vec2  l0_coverage; // x = min, y = max
	float l0_cumulus_stratus_blend;
	float l0_extinction_coeff;
	float l0_scattering_coeff;
	float l0_shadow;
	float l0_wind_torn_factor;
	vec2  l1_coverage; // x = min, y = max
	float l1_cumulus_stratus_blend;
	float l1_extinction_coeff;
	float l1_scattering_coeff;
	float l1_shadow;
	float cirrus_amount;
	float cirrocumulus_amount;
	float noctilucent_amount;
	float crepuscular_rays_amount;
};

#endif // INCLUDE_SKY_CLOUDS_PARAMETERS
