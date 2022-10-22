/*
--------------------------------------------------------------------------------

  Photon Shaders by SixthSurge

  program/gbuffer/solid.vsh:
  Handle terrain, entities, the hand, beacon beams and spider eyes

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

out vec2 texCoord;
out vec2 lmCoord;

#ifdef PROGRAM_TERRAIN
out float vanillaAo;
#endif

flat out uint blockId;
flat out vec4 tint;
flat out mat3 tbnMatrix;

#ifdef POM
flat out vec2 atlasTileOffset;
flat out vec2 atlasTileScale;
#endif

attribute vec4 at_tangent;
attribute vec3 mc_Entity;
attribute vec2 mc_midTexCoord;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform float near;
uniform float far;

uniform vec2 taaOffset;

#include "/include/utility/spaceConversion.glsl"

void main() {
	texCoord = gl_MultiTexCoord0.xy;
	lmCoord  = clamp01(gl_MultiTexCoord1.xy * rcp(240.0));
	tint     = gl_Color;
	blockId  = uint(max0(mc_Entity.x - 10000.0));

	tbnMatrix[2] = mat3(gbufferModelViewInverse) * normalize(gl_NormalMatrix * gl_Normal);
#ifdef MC_NORMAL_MAP
	tbnMatrix[0] = mat3(gbufferModelViewInverse) * normalize(gl_NormalMatrix * at_tangent.xyz);
	tbnMatrix[1] = cross(tbnMatrix[0], tbnMatrix[2]) * sign(at_tangent.w);
#endif

#ifdef PROGRAM_TERRAIN
	vanillaAo = gl_Color.a < 0.1 ? 1.0 : gl_Color.a; // fixes models where vanilla ao breaks (eg lecterns)
	tint.a = 1.0;
#endif

	vec3 viewPos = transform(gl_ModelViewMatrix, gl_Vertex.xyz);
	vec4 clipPos = project(gl_ProjectionMatrix, viewPos);

#if   defined TAA && defined TAAU
	clipPos.xy  = clipPos.xy * taauRenderScale + clipPos.w * (taauRenderScale - 1.0);
	clipPos.xy += taaOffset * clipPos.w;
#elif defined TAA
	clipPos.xy += taaOffset * clipPos.w * 0.75;
#endif

	gl_Position = clipPos;
}
