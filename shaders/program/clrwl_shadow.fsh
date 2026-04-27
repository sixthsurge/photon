/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/clrwl_shadow:
  Colorwheel (Flywheel 1.0) instanced geometry - shadow fragment stage

  Outputs to shadowcolor0 in Photon's shadow color format:
    0.25 * srgb_eotf_inv(color) * rec709_to_rec2020

  This matches the output of shadow.fsh for normal geometry so that
  Photon's shadow sampling code treats both identically.

  clrwl_computeFragment is called here so Colorwheel can read back shadow
  visibility per-instance if it needs it. The overlay is applied before
  writing so translucent overlays affect shadow tinting correctly.

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

layout(location = 0) out vec3 shadowcolor0_out;

/* RENDERTARGETS: 0 */

in vec2 texcoord;
in vec4 glcolor;

// ------------
//   Uniforms
// ------------

uniform sampler2D gtexture;

#include "/include/utility/color.glsl"

void main() {
    vec4 base_color = textureLod(gtexture, texcoord, 0) * glcolor;

    // Alpha cut-out — discard fully transparent shadow casters
    if (base_color.a < 0.1) { discard; return; }

    // ----- Colorwheel overlay -----
    vec2  lmcoord_out;
    float ao_out;
    vec4  overlay_color;

    clrwl_computeFragment(base_color, base_color, lmcoord_out, ao_out, overlay_color);
    base_color.rgb = mix(base_color.rgb, overlay_color.rgb, overlay_color.a);

    // ----- Shadow color output -----
    // Matches shadow.fsh: multiply/darken fully opaque surfaces, skip for
    // translucent ones (step() zeroes the output when alpha < 1 - 1/255).
    shadowcolor0_out  = mix(vec3(1.0), base_color.rgb, base_color.a);
    shadowcolor0_out  = 0.25 * srgb_eotf_inv(shadowcolor0_out) * rec709_to_rec2020;
    shadowcolor0_out *= step(base_color.a, 1.0 - rcp(255.0));
}
