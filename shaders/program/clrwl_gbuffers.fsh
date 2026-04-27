/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/clrwl_gbuffers:
  Colorwheel (Flywheel 1.0) instanced geometry - fragment stage

  Colorwheel injects clrwl_computeFragment() at runtime. Its signature is:
    void clrwl_computeFragment(
        inout vec4 fragColor,   // base color in, modified in-place
        in    vec4 baseColor,   // original base color (same as above on entry)
        out   vec2 lmcoord,     // lightmap coords [0,1] returned by Colorwheel
        out   float ao,         // ambient occlusion [0,1] returned by Colorwheel
        out   vec4 overlayColor // tint overlay to mix on top (pre-multiplied alpha)
    );

  We write into Photon's colortex1 (gbuffer_data_0) so the deferred pipeline
  shades Colorwheel geometry identically to normal terrain/entities.

  gbuffer_data_0 layout (must match gbuffers_all_solid.fsh exactly):
    .x = pack_unorm_2x8(albedo.rg)
    .y = pack_unorm_2x8(albedo.b, material_mask / 255.0)
    .z = pack_unorm_2x8(encode_unit_vector(flat_normal))
    .w = pack_unorm_2x8(light_levels)

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

// Write into Photon's gbuffer channel — same rendertarget as gbuffers_all_solid.
layout(location = 0) out vec4 gbuffer_data_0;

/* RENDERTARGETS: 1 */

in vec2 texcoord;
in vec2 lmcoord;
in vec4 glcolor;
in vec3 world_normal;

// ------------
//   Uniforms
// ------------

uniform sampler2D gtexture;
uniform int frameCounter;

#include "/include/utility/encoding.glsl"
#include "/include/utility/dithering.glsl"

void main() {
    // ----- Base color -----
    vec4 base_color = texture(gtexture, texcoord) * glcolor;

    // Discard fully transparent fragments (alpha cut-out)
    if (base_color.a < 0.1) { discard; return; }

    // ----- Colorwheel overlay -----
    // clrwl_computeFragment is injected by Colorwheel at compile-time.
    // lmcoord_out and ao_out are written by Colorwheel; they encode the
    // per-instance lighting / AO baked by Flywheel.
    vec2  lmcoord_out;
    float ao_out;
    vec4  overlay_color;

    clrwl_computeFragment(base_color, base_color, lmcoord_out, ao_out, overlay_color);

    // Mix Colorwheel overlay on top of the base color
    base_color.rgb = mix(base_color.rgb, overlay_color.rgb, overlay_color.a);

    // Apply ambient occlusion from Colorwheel
    base_color.rgb *= ao_out;

    // ----- Light levels -----
    // Colorwheel returns lmcoord_out in raw lightmap space [0, 240].
    // Normalize to [0, 1] to match what Photon stores in the gbuffer.
    vec2 light_levels = clamp01(lmcoord_out * rcp(240.0));

    // ----- Normal -----
    // Normalize the interpolated world-space normal.
    vec3 flat_normal = normalize(world_normal);

    // ----- Material mask -----
    // Flywheel instances have no Photon material mask — use 0 (generic solid).
    // Hardcoded emission is not applied; Create machinery should not glow.
    const float material_mask_f = 0.0;

    // ----- Dither -----
    float dither = interleaved_gradient_noise(gl_FragCoord.xy, frameCounter);

    // ----- Pack into gbuffer_data_0 (same layout as gbuffers_all_solid.fsh) -----
    gbuffer_data_0.x = pack_unorm_2x8(base_color.rg);
    gbuffer_data_0.y = pack_unorm_2x8(base_color.b, material_mask_f);
    gbuffer_data_0.z = pack_unorm_2x8(encode_unit_vector(flat_normal));
    gbuffer_data_0.w = pack_unorm_2x8(dither_8bit(light_levels, dither));
}
