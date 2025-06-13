#if !defined INCLUDE_LIGHTING_LPV_FLOODFILL
#define INCLUDE_LIGHTING_LPV_FLOODFILL

#include "voxelization.glsl"

bool is_emitter(uint block_id) {
	return 32u <= block_id && block_id < 64u;
}

bool is_translucent(uint block_id) {
	return 64u <= block_id && block_id < 80u;
}

vec3 get_emitted_light(uint block_id) {
	if (is_emitter(block_id)) {
		return texelFetch(light_data_sampler, ivec2(int(block_id) - 32, 0), 0).rgb;
	} else {
		return vec3(0.0);
	}
}

vec3 get_tint(uint block_id, bool is_transparent) {
	if (is_translucent(block_id)) {
		return texelFetch(light_data_sampler, ivec2(int(block_id) - 64, 1), 0).rgb;
	} else {
		return vec3(is_transparent);
	}
}

ivec3 clamp_to_voxel_volume(ivec3 pos) {
	return clamp(pos, ivec3(0), voxel_volume_size - 1);
}

vec3 gather_light(sampler3D light_sampler, ivec3 pos) {
	const ivec3[6] face_offsets = ivec3[6](
		ivec3( 1,  0,  0),
		ivec3( 0,  1,  0),
		ivec3( 0,  0,  1),
		ivec3(-1,  0,  0),
		ivec3( 0, -1,  0),
		ivec3( 0,  0, -1)
	);

	if (clamp_to_voxel_volume(pos) != pos) {
		return vec3(0.0);
	}

	const float center_weight = 1.05;

	return (
		texelFetch(light_sampler, pos, 0).rgb * center_weight +
		texelFetch(light_sampler, clamp_to_voxel_volume(pos + face_offsets[0]), 0).xyz +
		texelFetch(light_sampler, clamp_to_voxel_volume(pos + face_offsets[1]), 0).xyz +
		texelFetch(light_sampler, clamp_to_voxel_volume(pos + face_offsets[2]), 0).xyz +
		texelFetch(light_sampler, clamp_to_voxel_volume(pos + face_offsets[3]), 0).xyz +
		texelFetch(light_sampler, clamp_to_voxel_volume(pos + face_offsets[4]), 0).xyz +
		texelFetch(light_sampler, clamp_to_voxel_volume(pos + face_offsets[5]), 0).xyz
	) * rcp(7.0 * center_weight);
}

void update_lpv(writeonly image3D light_img, sampler3D light_sampler) {
	vec3 current_center = get_voxel_volume_center(gbufferModelViewInverse[2].xyz);
	vec3 previous_center = get_voxel_volume_center(
		vec3(
			gbufferPreviousModelView[0].z, 
			gbufferPreviousModelView[1].z, 
			gbufferPreviousModelView[2].z
		)
	);

	ivec3 pos = ivec3(gl_GlobalInvocationID);
	ivec3 previous_pos = ivec3(vec3(pos) - floor(previousCameraPosition) + floor(cameraPosition) - current_center + previous_center);

	uint block_id       = texelFetch(voxel_sampler, pos, 0).x;
	bool transparent    = block_id == 0u || block_id >= 128u;
	block_id            = block_id & 127;
	vec3 light_avg      = gather_light(light_sampler, previous_pos);
	vec3 emitted_light  = sqr(get_emitted_light(block_id));
	vec3 tint           = sqr(get_tint(block_id, transparent));

	vec3 light = emitted_light + light_avg * tint;

	imageStore(light_img, pos, vec4(light, 0.0));
}

#endif // INCLUDE_LIGHTING_LPV_FLOODFILL
