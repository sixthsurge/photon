#ifndef INCLUDE_LIGHT_LPV_VOXELIZATION
#define INCLUDE_LIGHT_LPV_VOXELIZATION

const ivec3 voxel_volume_size = ivec3(VOXEL_VOLUME_SIZE);

vec3 scene_to_voxel_space(vec3 scene_pos) {
	return scene_pos + fract(cameraPosition) + (0.5 * vec3(voxel_volume_size));
}

vec3 voxel_to_scene_space(vec3 voxel_pos) {
	return voxel_pos - fract(cameraPosition) - (0.5 * vec3(voxel_volume_size));
}

bool is_inside_voxel_volume(vec3 voxel_pos) {
	voxel_pos *= rcp(vec3(voxel_volume_size));
	return clamp01(voxel_pos) == voxel_pos;
}

#ifdef PROGRAM_SHADOW
void update_voxel_map(uint block_id) {
	vec3 model_pos = gl_Vertex.xyz + at_midBlock * rcp(64.0);
	vec3 view_pos  = transform(gl_ModelViewMatrix, model_pos);
	vec3 scene_pos = transform(shadowModelViewInverse, view_pos);
	vec3 voxel_pos = scene_to_voxel_space(scene_pos);

	bool is_terrain = any(equal(ivec4(renderStage), ivec4(MC_RENDER_STAGE_TERRAIN_SOLID, MC_RENDER_STAGE_TERRAIN_TRANSLUCENT, MC_RENDER_STAGE_TERRAIN_CUTOUT, MC_RENDER_STAGE_TERRAIN_CUTOUT_MIPPED)));
	bool is_water = block_id == 1;

	// Prevent blocks that aren't part of another category in shaders.properties from being treated as air
	block_id = max(block_id, 1u);

	if (is_terrain && is_inside_voxel_volume(voxel_pos) && !is_water) {
		imageStore(voxel_img, ivec3(voxel_pos), uvec4(block_id, 0u, 0u, 0u));
	}
}
#endif

#endif // INCLUDE_LIGHT_LPV_VOXELIZATION
