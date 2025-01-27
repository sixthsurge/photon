/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/gbuffers_damagedblock:
  Handle block breaking overlay

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

layout (location = 0) out vec4 damage_overlay;

#ifdef USE_SEPARATE_ENTITY_DRAWS
/* RENDERTARGETS: 0 */
#else
/* RENDERTARGETS: 3 */
#endif

in vec2 uv;

// ------------
//   Uniforms
// ------------

uniform sampler2D gtexture;

uniform vec2 taa_offset;
uniform vec2 view_pixel_size;

const float lod_bias = log2(taau_render_scale);

#include "/include/utility/color.glsl"

void main() {
#if defined TAA && defined TAAU
	vec2 coord = gl_FragCoord.xy * view_pixel_size * rcp(taau_render_scale);
	if (clamp01(coord) != coord) discard;
#endif

	damage_overlay = texture(gtexture, uv, lod_bias);
	if (damage_overlay.a < 0.1) discard;

#ifdef USE_SEPARATE_ENTITY_DRAWS
	damage_overlay.rgb = 0.5 * srgb_eotf_inv(2.0 * damage_overlay.rgb) * rec709_to_rec2020;
	damage_overlay.a   = 1.0;
#else
	// Old overlay handling
	// alpha of 1 <=> block breaking overlay
	damage_overlay.a = 1.0 / 255.0;
#endif
}

