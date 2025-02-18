#if !defined INCLUDE_SKY_CLOUDS
#define INCLUDE_SKY_CLOUDS

#include "clouds/altocumulus.glsl"
#include "clouds/cumulus.glsl"
#include "clouds/cumulus_congestus.glsl"
#include "clouds/cirrus.glsl"
#include "clouds/noctilucent.glsl"

bool clouds_early_exit(
	CloudsResult result,
	float r,
	float layer_radius
) {
	bool has_congestus = clouds_params.cumulus_congestus_blend > eps;

	return result.transmittance < 1e-3 && r < layer_radius 
		&& (result.apparent_distance < clouds_cumulus_congestus_distance || !has_congestus);
}

CloudsResult draw_clouds(
	vec3 air_viewer_pos,
	vec3 ray_dir,
	vec3 clear_sky,
	float distance_to_terrain,
	float dither
) {
	CloudsResult result = clouds_not_hit;
	float r = length(air_viewer_pos);

#ifdef CLOUDS_CUMULUS
	result = draw_cumulus_clouds(air_viewer_pos, ray_dir, clear_sky, distance_to_terrain, dither);
	if (clouds_early_exit(result, r, clouds_cumulus_radius)) {
		return result;
	}
#endif

#ifdef CLOUDS_ALTOCUMULUS
	CloudsResult result_ac = draw_altocumulus_clouds(air_viewer_pos, ray_dir, clear_sky, distance_to_terrain, dither);
	result = blend_layers(result, result_ac);
	if (clouds_early_exit(result, r, clouds_altocumulus_radius)) {
		return result;
	}
#endif

#ifdef CLOUDS_CUMULUS_CONGESTUS
	if (clouds_params.cumulus_congestus_blend > eps) {
		CloudsResult result_cu_con = draw_cumulus_congestus_clouds(air_viewer_pos, ray_dir, clear_sky, distance_to_terrain, dither);

		// fade existing clouds into congestus
		float distance_fade = mix(
			1.0, 
			result_cu_con.transmittance, 
			linear_step(
				0.75, 
				1.0, 
				result.apparent_distance * rcp(clouds_cumulus_congestus_distance)
			)
		);
		result.scattering *= distance_fade;
		result.transmittance += (1.0 - result.transmittance) * (1.0 - distance_fade);
		result.apparent_distance = mix(result_cu_con.apparent_distance, result.apparent_distance, distance_fade);

		result = blend_layers(result, result_cu_con);
		if (result.transmittance < 1e-3) return result;
	}
#endif

#ifdef CLOUDS_CIRRUS
	CloudsResult result_ci = draw_cirrus_clouds(air_viewer_pos, ray_dir, clear_sky, distance_to_terrain, dither);
	result = blend_layers(result, result_ci);
	if (result.transmittance < 1e-3) return result;
#endif
	
#ifdef CLOUDS_NOCTILUCENT
	vec4 result_nlc = draw_noctilucent_clouds(air_viewer_pos, ray_dir, clear_sky);
	result.scattering.rgb += result_nlc.xyz * result.transmittance;
	result.transmittance *= result_nlc.w;
#endif

	return result;
}

#endif // INCLUDE_SKY_CLOUDS
