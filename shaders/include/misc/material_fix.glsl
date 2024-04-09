#if !defined INCLUDE_MISC_MATERIAL_FIX
#define INCLUDE_MISC_MATERIAL_FIX

// Change the material mask of some handheld/dropped items to help the hardcoded emission

#if defined PROGRAM_GBUFFERS_ENTITIES || defined PROGRAM_GBUFFERS_HAND
uint fix_material_mask() {
#if defined PROGRAM_GBUFFERS_ENTITIES
	if (entityId != 10100) return material_mask;
	bool is_top_face = tbn[2].y > 0.5;
#else
	bool is_top_face = (mat3(gbufferModelView) * tbn[2]).y > 0.5;
#endif

	// Warped stems
	if (19 <= material_mask && material_mask < 22) {
		bool is_lit = !is_top_face || any(lessThan(vec4(uv_local, 1.0 - uv_local), vec4(rcp(16.0) - 1e-3)));
		return is_lit ? 22u : 0u;
	}

	// Crimson stems
	if (23 <= material_mask && material_mask < 26) {
		bool is_lit = !is_top_face || any(lessThan(vec4(uv_local, 1.0 - uv_local), vec4(rcp(16.0) - 1e-3)));
		return is_lit ? 26u : 0u;
	}

	return material_mask;
}
#endif

#endif // INCLUDE_MISC_MATERIAL_FIX