#version 410 compatibility

/*
 * Program description:
 * Render clouds
 */

#include "/include/global.glsl"

//--// Outputs //-------------------------------------------------------------//

/* RENDERTARGETS: 5 */
layout (location = 0) out vec4 cloudData;

//--// Inputs //--------------------------------------------------------------//

in vec2 coord;

flat in float cloudsCirrusCoverage;
flat in float cloudsCumulusCoverage;

//--// Uniforms //------------------------------------------------------------//

uniform sampler2D noisetex;

uniform sampler2D depthtex1;

uniform sampler3D depthtex0; // 3D worley noise
uniform sampler3D depthtex2; // 3D curl noise

//--// Camera uniforms

uniform float near;
uniform float far;

uniform float eyeAltitude;

uniform vec3 cameraPosition;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

//--// Time uniforms

uniform int frameCounter;

uniform float frameTimeCounter;

uniform float rainStrength;

//--// Custom uniforms

uniform bool cloudsMoonlit;

uniform float worldAge;

uniform vec2 viewSize;
uniform vec2 viewTexelSize;

uniform vec2 taaOffset;

uniform vec3 sunDir;
uniform vec3 moonDir;

//--// Includes //------------------------------------------------------------//

#include "/include/atmospherics/clouds.glsl"

#include "/include/utility/checkerboard.glsl"
#include "/include/utility/dithering.glsl"
#include "/include/utility/random.glsl"
#include "/include/utility/spaceConversion.glsl"

//--// Functions //-----------------------------------------------------------//

#if   CLOUDS_UPSCALING_FACTOR == 1
	const vec2 cloudsRenderScale = vec2(1.0);
	#define checkerboardOffsets ivec2[1](ivec2(0))
#elif CLOUDS_UPSCALING_FACTOR == 2
	const vec2 cloudsRenderScale = vec2(0.5, 1.0);
	#define checkerboardOffsets checkerboardOffsets2x1
#elif CLOUDS_UPSCALING_FACTOR == 4
	const vec2 cloudsRenderScale = vec2(0.5);
	#define checkerboardOffsets checkerboardOffsets2x2
#elif CLOUDS_UPSCALING_FACTOR == 8
	const vec2 cloudsRenderScale = vec2(0.25, 0.5);
	#define checkerboardOffsets checkerboardOffsets4x2
#elif CLOUDS_UPSCALING_FACTOR == 16
	const vec2 cloudsRenderScale = vec2(0.25);
	#define checkerboardOffsets checkerboardOffsets4x4
#endif

float depthMax2x2(sampler2D depthSampler) {
	vec2 samplePos = coord * (renderScale * rcp(cloudsRenderScale));
	vec4 depthSamples0 = textureGather(depthSampler, samplePos);
	return maxOf(depthSamples0);
}

float depthMax4x2(sampler2D depthSampler) {
	vec2 samplePos = coord * (renderScale * rcp(cloudsRenderScale));

	vec4 depthSamples0 = textureGather(depthSampler, samplePos + vec2( 2.0 * viewTexelSize.x, viewTexelSize.y));
	vec4 depthSamples1 = textureGather(depthSampler, samplePos + vec2(-2.0 * viewTexelSize.x, viewTexelSize.y));

	return max(maxOf(depthSamples0), maxOf(depthSamples1));
}

float depthMax4x4(sampler2D depthSampler) {
	vec2 samplePos = coord * (renderScale * rcp(cloudsRenderScale));

	vec4 depthSamples0 = textureGather(depthSampler, samplePos + vec2( 2.0 * viewTexelSize.x,  2.0 * viewTexelSize.y));
	vec4 depthSamples1 = textureGather(depthSampler, samplePos + vec2(-2.0 * viewTexelSize.x,  2.0 * viewTexelSize.y));
	vec4 depthSamples2 = textureGather(depthSampler, samplePos + vec2( 2.0 * viewTexelSize.x, -2.0 * viewTexelSize.y));
	vec4 depthSamples3 = textureGather(depthSampler, samplePos + vec2(-2.0 * viewTexelSize.x, -2.0 * viewTexelSize.y));

	return max(
		max(maxOf(depthSamples0), maxOf(depthSamples1)),
		max(maxOf(depthSamples2), maxOf(depthSamples3))
	);
}

void main() {
	ivec2 texel = ivec2(gl_FragCoord.xy);
	ivec2 viewTexel = texel * ivec2(rcp(cloudsRenderScale)) + checkerboardOffsets[frameCounter & (CLOUDS_UPSCALING_FACTOR - 1)];

	if (clamp(viewTexel, ivec2(0), ivec2(viewSize) + 1) != viewTexel) discard;

	// Get maximum depth from area covered by this fragment
#if   CLOUDS_UPSCALING_FACTOR == 1
	float depth = texelFetch(depthtex1, viewTexel, 0).x;
#elif CLOUDS_UPSCALING_FACTOR == 2 || CLOUDS_UPSCALING_FACTOR == 4
	float depth = depthMax2x2(depthtex1);
#elif CLOUDS_UPSCALING_FACTOR == 8
	float depth = depthMax4x2(depthtex1);
#elif CLOUDS_UPSCALING_FACTOR == 16
	float depth = depthMax4x4(depthtex1);
#endif

	vec3 screenPos = vec3(viewTexel * viewTexelSize, depth);
	vec3 viewPos = screenToViewSpace(screenPos, false);

	Ray ray;
	ray.origin = vec3(0.0, CLOUDS_SCALE * (eyeAltitude - SEA_LEVEL) + planetRadius, 0.0) + CLOUDS_SCALE * gbufferModelViewInverse[3].xyz;
	ray.dir    = mat3(gbufferModelViewInverse) * normalize(viewPos);

	vec3 lightDir = cloudsMoonlit ? moonDir : sunDir;

	float dither = interleavedGradientNoise(vec2(viewTexel), frameCounter / CLOUDS_UPSCALING_FACTOR);

	cloudData = drawClouds(ray, lightDir, dither, depth < 1.0 ? length(viewPos) : -1.0);

	// Scale scattering and apparent distance to fit in a normalized integer format
	cloudData.xy *= 1e-2;
	cloudData.w  *= 1e-6;
}
