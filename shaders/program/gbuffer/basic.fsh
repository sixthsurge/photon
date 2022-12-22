/*
--------------------------------------------------------------------------------

  Photon Shaders by SixthSurge

  program/gbuffer/basic.fsh:
  Handle lines

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

/* RENDERTARGETS: 1 */
layout (location = 0) out vec4 gbuffer_data;

flat in vec2 light_access;
flat in vec3 tint;

uniform vec2 view_pixel_size;

#include "/include/utility/encoding.glsl"

const vec3 normal = vec3(0.0, 1.0, 0.0);

void main() {
#if defined TAA && defined TAAU
	vec2 uv = gl_FragCoord.xy * view_pixel_size * rcp(taau_render_scale);
	if (clamp01(uv) != uv) discard;
#endif

	gbuffer_data.x = pack_unorm_2x8(tint.rg);
	gbuffer_data.y = pack_unorm_2x8(tint.b, 254.0 / 255.0);
	gbuffer_data.z = pack_unorm_2x8(encode_unit_vector(normal));
	gbuffer_data.w = pack_unorm_2x8(light_access);
}
