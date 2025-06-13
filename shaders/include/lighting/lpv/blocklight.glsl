#if !defined INCLUDE_LIGHTING_LPV_BLOCKLIGHT
#define INCLUDE_LIGHTING_LPV_BLOCKLIGHT

#include "voxelization.glsl"

vec3 read_lpv_linear(vec3 pos) {
	if ((frameCounter & 1) == 0) {
		return texture(light_sampler_a, pos).rgb;
	} else {
		return texture(light_sampler_b, pos).rgb;
	}
}

float lpv_distance_fade(vec3 scene_pos) {
	float distance_fade  = 2.0 * max_of(abs(scene_pos / vec3(voxel_volume_size)));
		  distance_fade  = linear_step(0.75, 1.0, distance_fade);

	return distance_fade;
}

vec3 get_lpv_blocklight(vec3 scene_pos, vec3 normal, vec3 mc_blocklight, float ao) {
	vec3 voxel_pos = scene_to_voxel_space(scene_pos);

	if (is_inside_voxel_volume(voxel_pos)) {
#ifndef NO_NORMAL
		vec3 sample_pos = clamp01((voxel_pos + normal * 0.5) / vec3(voxel_volume_size));
		vec3 lpv_blocklight = sqrt(read_lpv_linear(sample_pos)) * ao;
#else
		vec3 sample_pos = clamp01(voxel_pos / vec3(voxel_volume_size));
		vec3 lpv_blocklight = sqrt(read_lpv_linear(sample_pos));
#endif

		lpv_blocklight *= 1.25 * BLOCKLIGHT_I;

#ifdef COLORED_LIGHTS_VANILLA_LIGHTMAP_CONTRIBUTION
		float vanilla_lightmap_contribution = exp2(-4.0 * dot(lpv_blocklight, luminance_weights_rec2020));
		lpv_blocklight += mc_blocklight * vanilla_lightmap_contribution;
#endif

		// Darkness effect
		float darkness_factor = mix(1.0, dampen(abs(cos(2.0 * frameTimeCounter))) * 0.67 + 0.2, darknessFactor) * 0.75 + 0.25;
		lpv_blocklight *= darkness_factor;

		float distance_fade = lpv_distance_fade(scene_pos);

		return mix(lpv_blocklight, mc_blocklight, distance_fade);
	} else {
		return mc_blocklight;
	}
}

#endif // INCLUDE_LIGHTING_LPV_BLOCKLIGHT
