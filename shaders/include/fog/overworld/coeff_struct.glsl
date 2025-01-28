#if !defined INCLUDE_FOG_AIR_FOG_COEFF_STRUCT
#define INCLUDE_FOG_AIR_FOG_COEFF_STRUCT

struct AirFogCoefficients {
	vec3 rayleigh;
	vec3 mie_scattering;
	vec3 mie_extinction;
};

#endif // INCLUDE_FOG_AIR_FOG_COEFF_STRUCT
