#if !defined INCLUDE_LIGHTING_LPV_VOXELIZATION
#define INCLUDE_LIGHTING_LPV_VOXELIZATION

const ivec3 voxel_volume_size = ivec3(VOXEL_VOLUME_SIZE);

#ifdef COLORED_LIGHTS
const float voxelDistance = 32.0;
#endif

vec3 get_voxel_volume_center(vec3 look_direction) {
#if   VOXEL_VOLUME_CENTER == VOXEL_VOLUME_CENTER_AHEAD
	// Center the voxel volume in front of the player
	// Returns the integer offsets towards the center from the scene space origin

	// Fraction of the voxel volume size that is behind the player
	const float voxelization_fraction_behind_player = 0.15; // blocks

	return floor(look_direction * voxel_volume_size * (0.5 - voxelization_fraction_behind_player) * rcp(max_of(abs(look_direction))));
#else 
	// Voxel volume is centered on the player (origin in scene space)
	return vec3(0.0);
#endif
}

vec3 scene_to_voxel_space(vec3 scene_pos) {
	vec3 to_center = get_voxel_volume_center(gbufferModelViewInverse[2].xyz);
	return scene_pos + fract(cameraPosition) + (0.5 * vec3(voxel_volume_size)) + to_center;
}

vec3 voxel_to_scene_space(vec3 voxel_pos) {
	vec3 to_center = get_voxel_volume_center(gbufferModelViewInverse[2].xyz);
	return voxel_pos - fract(cameraPosition) - (0.5 * vec3(voxel_volume_size)) - to_center;
}

bool is_inside_voxel_volume(vec3 voxel_pos) {
	voxel_pos *= rcp(vec3(voxel_volume_size));
	return clamp01(voxel_pos) == voxel_pos;
}

#ifdef PROGRAM_SHADOW
bool is_voxelized(uint block_id, bool vertex_at_grid_corner) {
	bool is_terrain = any(equal(ivec4(renderStage), ivec4(MC_RENDER_STAGE_TERRAIN_SOLID, MC_RENDER_STAGE_TERRAIN_TRANSLUCENT, MC_RENDER_STAGE_TERRAIN_CUTOUT, MC_RENDER_STAGE_TERRAIN_CUTOUT_MIPPED)));

	bool is_transparent_block =
		block_id == 1u  || // Water
	    block_id == 18u || // Transparent metal objects
	    block_id == 80u;   // Miscellaneous transparent
	
	bool is_light_emitting_block = 32u <= block_id && block_id < 64u;

	return (vertex_at_grid_corner || is_light_emitting_block) && is_terrain && !is_transparent_block;
}

bvec3 disjunction(bvec3 a, bvec3 b) {
	// a || b compiles on Nvidia but apparently not with other vendors
	return bvec3(
		a.x || b.x,
		a.y || b.y,
		a.z || b.z
	);
}

// Returns true if pos is within `tolerance` of a corner of the unit cube
bool is_corner(vec3 pos, float tolerance) {
	return all(disjunction(lessThan(pos, vec3(tolerance)), greaterThan(pos, vec3(1.0 - tolerance))));
}

void update_voxel_map(uint block_id) {
	vec3 model_pos = gl_Vertex.xyz + at_midBlock * rcp(64.0);
	vec3 view_pos  = transform(gl_ModelViewMatrix, model_pos);
	vec3 scene_pos = transform(shadowModelViewInverse, view_pos);
	vec3 voxel_pos = scene_to_voxel_space(scene_pos);

	// Work out whether this vertex is in the lower corner of the block grid
	vec3 block_pos = transform(gl_ModelViewMatrix, gl_Vertex.xyz);
	     block_pos = transform(shadowModelViewInverse, block_pos);
		 block_pos = fract(block_pos + cameraPosition);
	bool vertex_at_grid_corner = is_corner(block_pos, rcp(16.0) - 1e-3);

	bool is_voxelized = is_voxelized(block_id, vertex_at_grid_corner);

	// Prevent blocks that aren't part of another category in shaders.properties from being treated as air
	block_id = max(block_id, 1u);

	// Warped and crimson stem emission
	uint is_warped_stem  = uint(19 <= block_id && block_id < 23);
	uint is_crimson_stem = uint(23 <= block_id && block_id < 27);
	block_id = block_id * (1u - is_warped_stem) + 46 * is_warped_stem;
	block_id = block_id * (1u - is_crimson_stem) + 58 * is_crimson_stem;

	// SSS blocks
	if (block_id == 5u  || // Leaves
	    block_id == 14u || // Strong SSS
	    block_id == 15u    // Weak SSS
	) {
		block_id = 79; // light gray tint
	}

	// Mark transparent light sources
	block_id = (vertex_at_grid_corner)
		? block_id
		: clamp(block_id + 128u, 0u, 255u);

	if (is_voxelized && is_inside_voxel_volume(voxel_pos)) {
		imageStore(voxel_img, ivec3(voxel_pos), uvec4(block_id, 0u, 0u, 0u));
	}
}
#endif

#endif // INCLUDE_LIGHTING_LPV_VOXELIZATION
