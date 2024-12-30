/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/gbuffers_armor_glint:
  Handle enchantment glint

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

layout (location = 0) out vec3 colortex0_out;
layout (location = 1) out vec4 colortex3_out;

/* RENDERTARGETS: 0,3 */

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

	vec3 armor_glint = texture(gtexture, uv, lod_bias).rgb;

	colortex0_out = srgb_eotf_inv(armor_glint) * rec709_to_working_color;

	// Old overlay handling
	// alpha of 0 <=> enchantment glint
	colortex3_out.rgb = armor_glint;
	colortex3_out.a = 0.0 / 255.0;
}
