/*
 * Program description:
 * Apply bloom, color grading, tone mapping, convert to rec. 709
 */

#include "/include/global.glsl"

//--// Outputs //-------------------------------------------------------------//

/* RENDERTARGETS: 2 */
layout (location = 0) out vec3 fragColor;

#ifdef BLOOMY_FOG
/* RENDERTARGETS: 2,14 */
layout (location = 1) out vec4 bloomyFog;
#endif

//--// Inputs //--------------------------------------------------------------//

in vec2 coord;

flat in float globalExposure;
flat in mat3 whiteBalanceMatrix;

//--// Uniforms //------------------------------------------------------------//

uniform usampler2D colortex1; // Scene data
uniform sampler2D colortex2;  // Bloom tiles
uniform sampler2D colortex5;  // Bloomy fog amount
uniform sampler2D colortex8;  // Scene history and exposure
uniform sampler2D colortex14; // Bloomy fog color

uniform sampler2D depthtex0;

//--// Camera uniforms

uniform int isEyeInWater;

uniform ivec2 eyeBrightness;
uniform ivec2 eyeBrightnessSmooth;

uniform float near;
uniform float far;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;

//--// Time uniforms

uniform float frameTime;

uniform float rainStrength;

//--// Custom uniforms

uniform vec2 taaOffset;

uniform vec2 viewSize;
uniform vec2 windowSize;
uniform vec2 windowTexelSize;

//--// Includes //------------------------------------------------------------//

#define TEMPORAL_REPROJECTION

#include "/include/fragment/aces/aces.glsl"

#include "/include/utility/bicubic.glsl"
#include "/include/utility/color.glsl"
#include "/include/utility/fastMath.glsl"
#include "/include/utility/spaceConversion.glsl"

//--// Functions //-----------------------------------------------------------//

vec3 getBloom(out vec3 fogBloom) {
	vec3 tileSum = vec3(0.0);

	float weight = 1.0;
	float weightSum = 0.0;

#if defined BLOOMY_FOG || defined BLOOMY_RAIN
	const float fogBloomRadius = 1.5;

	fogBloom = vec3(0.0); // large-scale bloom for bloomy fog
	float fogBloomWeight = 1.0;
	float fogBloomWeightSum = 0.0;
#endif

	for (int i = 1; i < BLOOM_TILES; ++i) {
		float tileSize = exp2(-i);

		vec2 padAmount = 2.0 * windowTexelSize * rcp(tileSize);

		vec2 tileCoord = mix(padAmount, 1.0 - padAmount, coord) * tileSize + tileSize;

		vec3 tile = BLOOM_UPSAMPLING_FILTER(colortex2, tileCoord).rgb;

		tileSum += tile * weight;
		weightSum += weight;

		weight *= BLOOM_RADIUS;

#if defined BLOOMY_FOG || defined BLOOMY_RAIN
		fogBloom += tile * fogBloomWeight;

		fogBloomWeightSum += fogBloomWeight;
		fogBloomWeight *= fogBloomRadius;
#endif
	}

#if defined BLOOMY_FOG || defined BLOOMY_RAIN
	fogBloom *= rcp(fogBloomWeightSum);
#endif

	return tileSum / weightSum;
}

vec4 getBloomyFog(vec3 fogBloom) {
#if   defined WORLD_OVERWORLD
	// Apply bloomy fog only in darker areas
	float luminance = getLuminance(fragColor);

	float bloomyFogStrength = 0.4 - 0.3 * linearStep(0.05, 1.0, luminance);
	float bloomyFogDensity  = 0.01;
#elif defined WORLD_NETHER

#elif defined WORLD_END

#endif

	float depth = texture(depthtex0, coord * renderScale).x;
	float viewerDistance = length(screenToViewSpace(vec3(coord, depth), false));

	float fogAmount = (1.0 - exp(-bloomyFogDensity * viewerDistance)) * bloomyFogStrength * BLOOMY_FOG_INTENSITY;
	if (linearizeDepth(depth) < MC_HAND_DEPTH) fogAmount = 0.0;

	vec2 previousScreenPos = reproject(vec3(coord, depth)).xy;
	vec4 previousBloomyFog = texture(colortex14, previousScreenPos);

	const vec2 updateSpeed = vec2(25.0, 12.0); // fog amount, fog bloom

	// Offcenter rejection from Jessie, which is originally from Zombye
	// Reduces blur in motion
	vec2 pixelOffset = 1.0 - abs(2.0 * fract(windowSize * previousScreenPos) - 1.0);
	float offcenterRejection = sqrt(pixelOffset.x * pixelOffset.y) * 0.5 + 0.5;

	vec2 blendWeight  = exp(-frameTime * updateSpeed) * offcenterRejection;
		 blendWeight *= float(clamp01(previousScreenPos) == previousScreenPos);
	     blendWeight *= 1.0 - float(any(isnan(previousBloomyFog)));

	fogAmount = mix(fogAmount, previousBloomyFog.w,   blendWeight.x);
	fogBloom  = mix(fogBloom,  previousBloomyFog.rgb, blendWeight.y);

	return vec4(fogBloom, fogAmount);
}

vec3 tonemapAces(vec3 rgb) {
	rgb *= 2.4; // Match the exposure to the RRT
	rgb = acesRrt(rgb);
	rgb = acesOdt(rgb);

	return rgb;
}

vec3 tonemapAcesFit(vec3 rgb) {
	rgb *= 2.4; // Match the exposure to the RRT
	rgb = rrtSweeteners(rgb * ap1ToAp0);
	rgb = rrtAndOdtFit(rgb);

	// Global desaturation
	vec3 grayscale = vec3(getLuminance(rgb));
	rgb = mix(grayscale, rgb, odtSatFactor);

	return rgb;
}

vec3 tonemapHejlBurgess(vec3 rgb) {
	rgb = (rgb * (6.2 * rgb + 0.5)) / (rgb * (6.2 * rgb + 1.7) + 0.06);
	return srgbToLinear(rgb); // Revert built-in sRGB conversion
}

vec3 tonemapReinhardJodie(vec3 rgb) {
	vec3 reinhard = rgb / (rgb + 1.0);
	return mix(rgb / (getLuminance(rgb) + 1.0), reinhard, reinhard);
}

// Source: http://www.diva-portal.org/smash/get/diva2:24136/FULLTEXT01.pdf
vec3 purkinjeShift(vec3 rgb, float intensity) {
	const vec3 rodResponse = vec3(7.15e-5, 4.81e-1, 3.28e-1) * r709ToAp1Unlit;
	vec3 xyz = rgb * ap1ToXyz;

	vec3 scotopicLuminance = xyz * (1.33 * (1.0 + (xyz.y + xyz.z) / xyz.x) - 1.68);

	float purkinje = dot(rodResponse, scotopicLuminance * xyzToAp1);

	rgb = mix(rgb, purkinje * vec3(0.5, 0.7, 1.0), exp2(-rcp(intensity) * purkinje));

	return max0(rgb);
}

vec3 adjustContrast(vec3 rgb, const float contrast) {
	const float logMidpoint = 0.18;
	const float eps = 1e-6; // avoid taking log of 0

	rgb = log2(rgb + eps);
	rgb = contrast * (rgb - logMidpoint) + logMidpoint;
	rgb = exp2(rgb) - eps;

	return max0(rgb);
}

vec3 adjustSaturation(vec3 rgb, float saturation) {
	vec3 greyscale = vec3(getLuminance(rgb));
	return mix(greyscale, rgb, saturation);
}

// Vibrance filter from Belmu
vec3 adjustVibrance(vec3 rgb, const float vibrance) {
	float minComponent = minOf(rgb);
	float maxComponent = maxOf(rgb);
	float lightness    = 0.5 * (minComponent + maxComponent);
	float saturation   = (1.0 - clamp01(maxComponent - minComponent)) * clamp01(1.0 - maxComponent) * getLuminance(rgb) * 5.0;

	// vibrance
	rgb = mix(rgb, mix(vec3(lightness), rgb, vibrance), saturation);
	// negative vibrance
	rgb = mix(rgb, vec3(lightness), min((1.0 - lightness) * (1.0 - vibrance) * 0.5 * abs(vibrance), 1.0));

	return rgb;
}

void main() {
	ivec2 texel = ivec2(gl_FragCoord.xy);

	uvec2 sceneData = texelFetch(colortex1, ivec2(texel * renderScale), 0).xy;
	fragColor       = texelFetch(colortex8, texel, 0).rgb;

	float blocklight = unpackUnorm4x8(sceneData.y).z;

#ifdef BLOOM
	vec3 fogBloom;
	vec3 bloom = getBloom(fogBloom);

#ifdef BLOOMY_FOG
	bloomyFog = getBloomyFog(fogBloom);
	fragColor = mix(fragColor, bloomyFog.rgb, bloomyFog.a);
#endif

	fragColor = mix(fragColor, bloom, BLOOM_INTENSITY);
#endif

#if defined PURKINJE_SHIFT && defined WORLD_OVERWORLD
	// Reduce purkinje shift intensity around blocklight sources to preserve their colour
	float purkinjeIntensity = 0.1 - 0.1 * cube(blocklight);
	fragColor = purkinjeShift(fragColor, purkinjeIntensity);
#endif

#ifdef CAMERA_LOCAL_EXPOSURE
	fragColor *= getLocalExposure(depth);
#else
	fragColor *= globalExposure;
#endif

#ifdef GRADE
	fragColor *= GRADE_BRIGHTNESS;
	fragColor  = adjustVibrance(fragColor, GRADE_VIBRANCE);
	fragColor  = adjustSaturation(fragColor, GRADE_SATURATION);
	fragColor  = adjustContrast(fragColor, GRADE_CONTRAST);
	fragColor *= whiteBalanceMatrix;
#endif

	fragColor = tonemap(fragColor);
	fragColor = fragColor * ap1ToR709;
}
