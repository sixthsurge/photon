/*
--------------------------------------------------------------------------------

  Photon Shaders by SixthSurge

  program/gbuffer/solid.fsh:
  Handle animated overlays (block breaking overlay and enchantment glint)

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

/* DRAWBUFFERS:3 */
layout (location = 0) out vec4 overlays;

in vec2 uv;

uniform sampler2D gtexture;

const float lodBias = log2(taauRenderScale);

void main() {
#if defined TAA && defined TAAU
	vec2 screenPos = gl_FragCoord.xy * texelSize * rcp(taauRenderScale);
	if (clamp01(screenPos) != screenPos) discard;
#endif

	overlays = texture(gtexture, uv, lodBias);
	if (overlays.a < 0.1) discard;

#if   defined PROGRAM_ARMOR_GLINT
	// alpha of 0 <=> enchantment glint
	overlays.a = 0.0;
#elif defined PROGRAM_DAMAGEDBLOCK
	// alpha of 1 <=> block breaking overlay
	overlays.a = 1.0;
#endif
}
