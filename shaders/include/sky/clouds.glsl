#if !defined INCLUDE_SKY_CLOUDS
#define INCLUDE_SKY_CLOUDS

#include "clouds/altocumulus.glsl"
#include "clouds/cumulus.glsl"
#include "clouds/cumulus_congestus.glsl"
#include "clouds/cirrus.glsl"
#include "clouds/noctilucent.glsl"

CloudsResult draw_clouds(
	vec3 air_viewer_pos,
	vec3 ray_dir,
	vec3 clear_sky,
	float distance_to_terrain,
	float dither
) {
	CloudsResult result = clouds_not_hit;
	float r = length(air_viewer_pos);

	if (daily_weather_variation.clouds_cumulus_congestus_amount < 0.5) {
#ifdef CLOUDS_CUMULUS
		result = draw_cumulus_clouds(air_viewer_pos, ray_dir, clear_sky, distance_to_terrain, dither);
		if (result.transmittance < 1e-3 && r < clouds_cumulus_radius) return result;
#endif
	} else {
#ifdef CLOUDS_CUMULUS_CONGESTUS
		result = draw_cumulus_congestus_clouds(air_viewer_pos, ray_dir, clear_sky, distance_to_terrain, dither);
		if (result.transmittance < 1e-3) return result; // Always show cumulus congestus on top
#endif
	}

#ifdef CLOUDS_ALTOCUMULUS
	CloudsResult result_ac = draw_altocumulus_clouds(air_viewer_pos, ray_dir, clear_sky, distance_to_terrain, dither);
	result = blend_layers(result, result_ac);
	if (result.transmittance < 1e-3 && r < clouds_altocumulus_radius) return result;
#endif

#ifdef CLOUDS_CIRRUS
	CloudsResult result_ci = draw_cirrus_clouds(air_viewer_pos, ray_dir, clear_sky, distance_to_terrain, dither);
	result = blend_layers(result, result_ci);
#endif
	
#ifdef CLOUDS_NOCTILUCENT
	vec4 result_nlc = draw_noctilucent_clouds(air_viewer_pos, ray_dir, clear_sky);
	result.scattering += result_nlc.xyz * result.transmittance;
	result.transmittance *= result_nlc.w;
#endif

	return result;
}

#endif // INCLUDE_SKY_CLOUDS
