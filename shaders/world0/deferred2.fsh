#version 400 compatibility

/*
--------------------------------------------------------------------------------

  Photon Shaders by SixthSurge

  world0/deferred2.fsh:
  Calculate ambient occlusion

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

/* DRAWBUFFERS:6 */
layout (location = 0) out vec4 ao;

in vec2 uv;

uniform sampler2D noisetex;

uniform sampler2D colortex1; // Gbuffer 0
uniform sampler2D colortex2; // Gbuffer 1
uniform sampler2D colortex6; // Ambient occlusion history
uniform sampler2D colortex7; // Clouds history, pixel age

// TEMPORARY
uniform sampler2D colortex5; // Scene history

uniform sampler2D depthtex1;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform float near;
uniform float far;

uniform int frameCounter;

uniform vec3 lightDir;

uniform vec2 viewSize;
uniform vec2 texelSize;
uniform vec2 taaOffset;

#define TEMPORAL_REPROJECTION
#define WORLD_OVERWORLD

#include "/include/utility/bicubic.glsl"
#include "/include/utility/dithering.glsl"
#include "/include/utility/encoding.glsl"
#include "/include/utility/fastMath.glsl"
#include "/include/utility/random.glsl"
#include "/include/utility/spaceConversion.glsl"

#include "/include/gtao.glsl"

const float gtaoRenderScale = 0.5;

// from https://iquilezles.org/www/articles/texture/texture.htm
vec4 textureSmooth(sampler2D sampler, vec2 coord) {
	vec2 res = vec2(textureSize(sampler, 0));

	coord = coord * res + 0.5;

	vec2 i, f = modf(coord, i);
	f = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	coord = i + f;

	coord = (coord - 0.5) / res;
	return texture(sampler, coord);
}

void main() {
	ivec2 texel     = ivec2(gl_FragCoord.xy);
	ivec2 viewTexel = ivec2(gl_FragCoord.xy * (taauRenderScale / gtaoRenderScale));

	float depth = texelFetch(depthtex1, viewTexel, 0).x;

#ifdef NORMAL_MAPPING
	vec4 gbuffer1 = texelFetch(colortex2, viewTexel, 0);
#else
	vec4 gbuffer0 = texelFetch(colortex1, viewTexel, 0);
#endif

	vec2 dither = vec2(texelFetch(noisetex, texel & 511, 0).b, texelFetch(noisetex, (texel + 249) & 511, 0).b);

	if (isSky(depth)) { ao = vec4(1.0); return; }

	depth += 0.38 * float(isHand(depth)); // Hand lighting fix from Capt Tatsu

	vec3 screenPos = vec3(uv, depth);
	vec3 viewPos = screenToViewSpace(screenPos, true);
	vec3 scenePos = viewToSceneSpace(viewPos);

#ifdef NORMAL_MAPPING
	vec3 worldNormal = decodeUnitVector(gbuffer1.xy);
#else
	vec3 worldNormal = decodeUnitVector(unpackUnorm2x8(gbuffer0.z));
#endif

	vec3 viewNormal = mat3(gbufferModelView) * worldNormal;

	dither = R2(frameCounter, dither);

#ifdef GTAO
	ao = calculateGtao(screenPos, viewPos, viewNormal, dither);
#else
	ao = vec4(1.0);
#endif

	// Temporal accumulation

	const float maxAccumulatedFrames       = 10.0;
	const float depthRejectionStrength     = 16.0;
	const float offcenterRejectionStrength = 0.25;

	vec3 previousScreenPos = reproject(screenPos);

	vec4 historyAo = textureCatmullRomFast(colortex6, previousScreenPos.xy * gtaoRenderScale, 0.65);
	     historyAo = (clamp01(previousScreenPos.xy) == previousScreenPos.xy) ? historyAo : ao;
		 historyAo = max0(historyAo);

	// TEMP -- Will use pixel age from colortex7
	float pixelAge = texture(colortex5, previousScreenPos.xy).a;
	      pixelAge = min(pixelAge, maxAccumulatedFrames);

	// Offcenter rejection from Jessie, which is originally by Zombye
	// Reduces blur in motion
	vec2 pixelOffset = 1.0 - abs(2.0 * fract(viewSize * gtaoRenderScale * previousScreenPos.xy) - 1.0);
	float offcenterRejection = sqrt(pixelOffset.x * pixelOffset.y) * offcenterRejectionStrength + (1.0 - offcenterRejectionStrength);

	// Depth rejection
	float viewNorm = rcpLength(viewPos);
	float NoV = abs(dot(viewNormal, viewPos)) * viewNorm; // NoV / sqrt(length(viewPos))
	float z0 = linearizeDepthFast(depth);
	float z1 = linearizeDepthFast(1.0 - historyAo.z);
	float depthWeight = exp2(-abs(z0 - z1) * depthRejectionStrength * NoV * viewNorm);

	pixelAge *= depthWeight * offcenterRejection * float(historyAo.z != 1.0);

	float historyWeight = pixelAge / (pixelAge + 1.0);

	// Reconstruct bent normal Z
	historyAo.xy = historyAo.xy * 2.0 - 1.0;
	historyAo.z  = sqrt(max0(1.0 - dot(historyAo.xy, historyAo.xy)));

	// Blend with history
	ao = mix(ao, historyAo, historyWeight);

	// Re-normalize bent normal
	ao.xy *= rcpLength(ao.xyz);
	ao.xy  = ao.xy * 0.5 + 0.5;

	// Store reversed depth for next frame (using reversed depth improves precision for fp buffers)
	ao.z = 1.0 - depth;
}
