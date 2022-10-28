/*
--------------------------------------------------------------------------------

  Photon Shaders by SixthSurge

  program/gbuffer/basic.fsh:
  Handle lines

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

/* RENDERTARGETS: 1 */
layout (location = 0) out vec4 gbufferData;

flat in vec2 lmCoord;
flat in vec3 tint;

uniform vec2 texelSize;

#include "/include/utility/encoding.glsl"

const vec3 normal = vec3(0.0, 1.0, 0.0);

void main() {
#if defined TAA && defined TAAU
	vec2 uv = gl_FragCoord.xy * texelSize * rcp(taauRenderScale);
	if (clamp01(uv) != uv) discard;
#endif

	gbufferData.x = packUnorm2x8(tint.rg);
	gbufferData.y = packUnorm2x8(tint.b, 254.0 / 255.0);
	gbufferData.z = packUnorm2x8(encodeUnitVector(normal));
	gbufferData.w = packUnorm2x8(lmCoord);
}
