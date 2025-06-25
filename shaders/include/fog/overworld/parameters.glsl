#if !defined INCLUDE_FOG_OVERWORLD_PARAMETERS
#define INCLUDE_FOG_OVERWORLD_PARAMETERS

struct OverworldFogParameters {
	vec3 rayleigh_scattering_coeff; 
	vec3 mie_scattering_coeff;
	vec3 mie_extinction_coeff;
};

#endif // INCLUDE_FOG_OVERWORLD_PARAMETERS
