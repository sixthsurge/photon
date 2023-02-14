/*
--------------------------------------------------------------------------------

  Photon Shaders by SixthSurge

  program/gbuffer/basic.fsh:
  Handle lines

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

/* DRAWBUFFERS:1 */

#ifdef NORMAL_MAPPING
/* DRAWBUFFERS:12 */
#endif

#ifdef SPECULAR_MAPPING
/* DRAWBUFFERS:12 */
#endif

layout (location = 0) out vec4 gbuffer_data_0; // albedo, block ID, flat normal, light levels
layout (location = 1) out vec4 gbuffer_data_1; // detailed normal, specular map (optional)

flat in vec2 light_levels;
flat in vec3 tint;

uniform vec2 view_pixel_size;

#include "/include/utility/encoding.glsl"

const vec3 normal = vec3(0.0, 1.0, 0.0);

void main() {
#if defined TAA && defined TAAU
	vec2 coord = gl_FragCoord.xy * view_pixel_size * rcp(taau_render_scale);
	if (clamp01(coord) != coord) discard;
#endif

	vec2 encoded_normal = encode_unit_vector(normal);

	gbuffer_data_0.x = pack_unorm_2x8(tint.rg);
	gbuffer_data_0.y = pack_unorm_2x8(tint.b, 0.0);
	gbuffer_data_0.z = pack_unorm_2x8(encode_unit_vector(normal));
	gbuffer_data_0.w = pack_unorm_2x8(light_levels);

#ifdef NORMAL_MAPPING
	gbuffer_data_1.xy = encoded_normal;
#endif

#ifdef SPECULAR_MAPPING
	const vec4 specular_map = vec4(0.0);
	gbuffer_data_1.z = pack_unorm_2x8(specular_map.xy);
	gbuffer_data_1.w = pack_unorm_2x8(specular_map.zw);
#endif
}
