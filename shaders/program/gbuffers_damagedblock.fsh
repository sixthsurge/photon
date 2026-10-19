/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/gbuffers_damagedblock:
  Handle block breaking overlay

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

layout(location = 0) out vec4 damage_overlay;

#ifdef USE_SEPARATE_ENTITY_DRAWS
#if MC_VERSION >= 260300
/* RENDERTARGETS: 3 */
#else
/* RENDERTARGETS: 0 */
#endif
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
    if (clamp01(coord) != coord) {
        discard;
    }
#endif

    damage_overlay = texture(gtexture, uv, lod_bias);

#if defined COLORWHEEL
	vec2 lmcoord;
	float ao;
	vec4 overlayColor;

	clrwl_computeFragment(damage_overlay, damage_overlay, lmcoord, ao, overlayColor);
	damage_overlay.rgb = mix(damage_overlay.rgb, overlayColor.rgb, overlayColor.a);
#endif

    if (damage_overlay.a < 0.1) {
        discard;
    }

#if ((defined USE_SEPARATE_ENTITY_DRAWS) && MC_VERSION < 260300)
    damage_overlay.rgb
        = 0.5 * srgb_eotf_inv(2.0 * damage_overlay.rgb) * rec709_to_rec2020;
    damage_overlay.a = 1.0;
#else
    // Old overlay handling
    // alpha of 1 <=> block breaking overlay
    damage_overlay.a = 1.0 / 255.0;
#endif
}
