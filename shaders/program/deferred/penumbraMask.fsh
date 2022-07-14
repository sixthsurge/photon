/*
 * Program description:
 * Calculate shadow penumbra radius and SSS depth
 */

#include "/include/global.glsl"

//--// Outputs //-------------------------------------------------------------//

/* RENDERTARGETS: 7 */
layout (location = 0) out vec2 penumbraMask;

//--// Inputs //--------------------------------------------------------------//

in vec2 coord;

//--// Uniforms //------------------------------------------------------------//

uniform sampler2D noisetex;

uniform sampler2D depthtex1;

uniform sampler2D shadowtex0;
uniform sampler2DShadow shadowtex1;

//--// Camera uniforms

uniform int isEyeInWater;

uniform float near;
uniform float far;

uniform vec3 cameraPosition;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

//--// Shadow uniforms

uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;

//--// Time uniforms

uniform int frameCounter;

//--// Custom uniforms

uniform vec2 viewSize;
uniform vec2 viewTexelSize;

uniform vec2 taaOffset;

uniform vec3 lightDir;

//--// Includes //------------------------------------------------------------//

#ifdef SHADOW_COLOR
	#undef SHADOW_COLOR
#endif

#include "/block.properties"

#include "/include/lighting/shadowMapping.glsl"

#include "/include/utility/random.glsl"
#include "/include/utility/spaceConversion.glsl"

//--// Functions //------------------------------------------------------------//

void main() {
#if SHADOW_QUALITY != SHADOW_QUALITY_FANCY
	return;
#endif

	ivec2 texel = ivec2(gl_FragCoord.xy);

	float depth = texelFetch(depthtex1, texel, 0).x;

	/* -- transformations -- */

	vec3 positionView         = screenToViewSpace(vec3(coord, depth), true);
	vec3 positionScene        = viewToSceneSpace(positionView);
	vec3 positionShadowView   = transform(shadowModelView, positionScene);
	vec3 positionShadowClip   = projectOrtho(shadowProjection, positionShadowView);
	vec3 positionShadowScreen = distortShadowSpace(positionShadowClip) * 0.5 + 0.5;

	/* -- blocker search -- */

	float dither = texelFetch(noisetex, texel & 511, 0).b;
	      dither = R1(frameCounter, dither);

	penumbraMask.x = blockerSearch(shadowtex0, positionShadowScreen, positionShadowClip, dither, penumbraMask.y);
}
