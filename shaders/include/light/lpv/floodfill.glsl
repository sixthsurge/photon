#if !defined INCLUDE_LIGHT_LPV_FLOODFILL
#define INCLUDE_LIGHT_LPV_FLOODFILL

#include "voxelization.glsl"

bool is_emitter(uint block_id) {
	return 32u <= block_id && block_id < 64u;
}

bool is_translucent(uint block_id) {
	return 64u <= block_id && block_id < 80u;
}

bool is_transparent(uint block_id) {
	return block_id == 0u  || // Air
	       block_id == 2u  || // Small plants
	       block_id == 3u  || // Tall plants (lower half)
		   block_id == 4u  || // Tall plants (upper half)
	       block_id == 5u  || // Leaves
	       block_id == 14u || // Strong SSS
	       block_id == 15u || // Weak SSS
	       block_id == 41u || // Brewing stand
	       block_id == 48u || // Sea pickle
	       block_id == 49u || // Nether mushrooms
	       block_id == 80u;   // Miscellaneous transparent
}

vec3 get_emitted_light(uint block_id) {
	if (is_emitter(block_id)) {
		return light_data.light_color[int(block_id) - 32].rgb;
	} else {
		return vec3(0.0);
	}
}

vec3 get_tint(uint block_id) {
	if (is_translucent(block_id)) {
		return light_data.tint_color[int(block_id) - 64].rgb;
	} else {
		return vec3(is_transparent(block_id));
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

	return texelFetch(light_sampler, pos, 0).rgb +
	       texelFetch(light_sampler, clamp_to_voxel_volume(pos + face_offsets[0]), 0).xyz +
	       texelFetch(light_sampler, clamp_to_voxel_volume(pos + face_offsets[1]), 0).xyz +
	       texelFetch(light_sampler, clamp_to_voxel_volume(pos + face_offsets[2]), 0).xyz +
	       texelFetch(light_sampler, clamp_to_voxel_volume(pos + face_offsets[3]), 0).xyz +
	       texelFetch(light_sampler, clamp_to_voxel_volume(pos + face_offsets[4]), 0).xyz +
	       texelFetch(light_sampler, clamp_to_voxel_volume(pos + face_offsets[5]), 0).xyz;
}

void update_lpv(writeonly image3D light_img, sampler3D light_sampler) {
	ivec3 pos = ivec3(gl_GlobalInvocationID);
	ivec3 previous_pos = ivec3(vec3(pos) - floor(previousCameraPosition) + floor(cameraPosition));

	uint block_id      = texelFetch(voxel_sampler, pos, 0).x;
	vec3 light_avg     = gather_light(light_sampler, previous_pos) * rcp(7.0);
	vec3 emitted_light = sqr(get_emitted_light(block_id));
	vec3 tint          = sqr(get_tint(block_id));

	vec3 light = emitted_light + light_avg * tint;

	imageStore(light_img, pos, vec4(light, 0.0));
}

#endif // INCLUDE_LIGHT_LPV_FLOODFILL
