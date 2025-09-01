#include "/include/global.glsl"
#include "/include/misc/material_masks.glsl"
#include "/include/utility/encoding.glsl"

layout (location = 0) out vec4 fragment_color;
layout (location = 1) out vec4 gbuffer_data; // albedo, block ID, flat normal, light levels

void voxy_emitFragment(VoxyFragmentParameters parameters) {
	vec4 base_color = parameters.sampledColour * parameters.tinting;

	// from Cortex
	vec3 flat_normal = vec3(
		uint((parameters.face >> 1) == 2), 
		uint((parameters.face >> 1) == 0), 
		uint((parameters.face >> 1) == 1)
	) * (float(int(parameters.face) & 1) * 2.0 - 1.0);

	uint material_mask = parameters.customId - 10000u;

	gbuffer_data.x  = pack_unorm_2x8(parameters.tinting.rg);
	gbuffer_data.y  = pack_unorm_2x8(parameters.tinting.b, clamp01(float(material_mask) * rcp(255.0)));
	gbuffer_data.z  = pack_unorm_2x8(encode_unit_vector(flat_normal));
	gbuffer_data.w  = pack_unorm_2x8(parameters.lightMap);

	if (material_mask == MATERIAL_WATER) {
		fragment_color = vec4(0.0);
		return;
	} 

	// TODO:
	// Shading for non-water Voxy translucents (forward or deferred? Not sure yet)
	fragment_color = base_color;
}
