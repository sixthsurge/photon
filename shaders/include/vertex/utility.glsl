#if !defined INCLUDE_VERTEX_UTILITY
#define INCLUDE_VERTEX_UTILITY

uint get_material_mask() {
#if   defined PROGRAM_GBUFFERS_TERRAIN || defined PROGRAM_GBUFFERS_WATER
	// Terrain
	return uint(max0(mc_Entity.x - 10000.0));
#elif defined PROGRAM_GBUFFERS_ENTITIES || defined PROGRAM_GBUFFERS_ENTITIES_TRANSLUCENT
	// Entities
	uint id = uint(max(entityId - 10000, 0));
#ifdef IS_IRIS
	uint item_id = uint(max(currentRenderedItemId - 10000, 0));
	id = id == 100 ? item_id : id;
#endif
	return id;
#elif defined PROGRAM_GBUFFERS_BLOCK || defined PROGRAM_GBUFFERS_BLOCK_TRANSLUCENT
	// Block entities
	return uint(max(blockEntityId - 10000, 0));
#elif (defined PROGRAM_GBUFFERS_HAND || defined PROGRAM_GBUFFERS_HAND_WATER) && defined IS_IRIS
	return uint(max(currentRenderedItemId - 10000, 0));
#elif defined PROGRAM_GBUFFERS_BEACONBEAM || defined PROGRAM_GBUFFERS_SPIDEREYES
	// Glowing stuff
	light_levels.x = 1.0;
	return 32u; // full emissive
#else
	// Other
	return 0u;
#endif
}

mat3 get_tbn_matrix() {
	mat3 tbn;
	tbn[0] = mat3(gbufferModelViewInverse) * normalize(gl_NormalMatrix * at_tangent.xyz);
	tbn[2] = mat3(gbufferModelViewInverse) * normalize(gl_NormalMatrix * gl_Normal);
	tbn[1] = cross(tbn[0], tbn[2]) * sign(at_tangent.w);
	return tbn;
}

#endif // INCLUDE_VERTEX_UTILITY
