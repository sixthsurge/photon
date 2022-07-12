/*
 * Program description:
 * Apply bloom, color grading, tone mapping, convert to rec. 709
 */

#include "/include/global.glsl"

//--// Outputs //-------------------------------------------------------------//

/* RENDERTARGETS: 2 */
layout (location = 0) out vec3 fragColor;

//--// Inputs //--------------------------------------------------------------//

in vec2 coord;

flat in float globalExposure;
flat in mat3 whiteBalanceMatrix;

//--// Uniforms //------------------------------------------------------------//

uniform usampler2D colortex1; // Scene data
uniform sampler2D colortex5;  // Bloomy fog amount
uniform sampler2D colortex8;  // Scene history and exposure
uniform sampler2D colortex14; // Temporally stable linear depth
uniform sampler2D colortex15; // Bloom tiles

//--// Camera uniforms

uniform int isEyeInWater;

uniform ivec2 eyeBrightness;
uniform ivec2 eyeBrightnessSmooth;

uniform float near;
uniform float far;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

//--// Time uniforms

uniform float frameTime;

uniform float rainStrength;
uniform float wetness;

//--// Custom uniforms

uniform float eyeSkylight;

uniform vec2 taaOffset;

uniform vec2 viewSize;
uniform vec2 windowSize;
uniform vec2 windowTexelSize;

//--// Includes //------------------------------------------------------------//

#include "/include/fragment/aces/aces.glsl"

#include "/include/utility/bicubic.glsl"
#include "/include/utility/color.glsl"
#include "/include/utility/fastMath.glsl"
#include "/include/utility/spaceConversion.glsl"

//--// Program //-------------------------------------------------------------//

#define getExposureFromEv100(ev100) exp2(-(ev100)) / 1.2
#define getExposureFromLuminance(l) calibration / (l)
#define getLuminanceFromExposure(e) calibration / (e)

const float K = 12.5; // Light-meter calibration constant
const float sensitivity = 100.0; // ISO
const float calibration = exp2(CAMERA_EXPOSURE_BIAS) * K / sensitivity / 1.2;

const float minLuminance = getLuminanceFromExposure(getExposureFromEv100(CAMERA_EXPOSURE_MIN));
const float maxLuminance = getLuminanceFromExposure(getExposureFromEv100(CAMERA_EXPOSURE_MAX));
const float minLogLuminance = log2(minLuminance);
const float maxLogLuminance = log2(maxLuminance);

vec3 getBloom(out vec3 fogBloom) {
	vec3 tileSum = vec3(0.0);

	float weight = 1.0;
	float weightSum = 0.0;

#if defined BLOOMY_FOG || defined BLOOMY_RAIN
	const float fogBloomRadius = 2.0;

	fogBloom = vec3(0.0); // large-scale bloom for bloomy fog
	float fogBloomWeight = 1.0;
	float fogBloomWeightSum = 0.0;
#endif

	for (int i = 1; i < BLOOM_TILES; ++i) {
		vec2 tileSize = exp2(-i) * vec2(2.0, 1.0);
		vec2 tileOffset = vec2(0.0, tileSize.y);

		vec2 padAmount = 2.0 * rcp(vec2(960.0, 1080.0)) * rcp(tileSize);

		vec2 tileCoord = mix(padAmount, 1.0 - padAmount, coord) * tileSize + tileOffset;

		vec3 tile = BLOOM_UPSAMPLING_FILTER(colortex15, tileCoord).rgb;

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

float getBloomyFog(float linearZ) {
#if   defined WORLD_OVERWORLD
	// apply bloomy fog only in darker areas
	float luminance = getLuminance(fragColor);
	float bloomyFogStrength = 0.8 - 0.6 * linearStep(0.05, 1.0, luminance) + 0.4 * wetness * eyeSkylight;
	float bloomyFogDensity  = 0.009;

	//
#elif defined WORLD_NETHER

#elif defined WORLD_END

#endif

	float depth = reverseLinearDepth(linearZ);
	float viewerDistance = length(screenToViewSpace(vec3(coord, depth), false));

	return bloomyFogStrength * BLOOMY_FOG_INTENSITY * (1.0 - exp(-bloomyFogDensity * viewerDistance));
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
vec3 purkinjeShift(vec3 rgb, float purkinjeIntensity) {
	if (purkinjeIntensity == 0.0) return rgb;

	const vec3 rodResponse = vec3(7.15e-5, 4.81e-1, 3.28e-1) * r709ToAp1Unlit;
	vec3 xyz = rgb * ap1ToXyz;

	vec3 scotopicLuminance = xyz * (1.33 * (1.0 + (xyz.y + xyz.z) / xyz.x) - 1.68);

	float purkinje = dot(rodResponse, scotopicLuminance * xyzToAp1);

	rgb = mix(rgb, purkinje * vec3(0.5, 0.7, 1.0), exp2(-rcp(purkinjeIntensity) * purkinje));

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
	float linearZ   = texelFetch(colortex14, texel, 0).x;

	uint blockId     = uint(unpackUnorm4x8(sceneData.x).w * 255.0);
	float blocklight = unpackUnorm4x8(sceneData.y).z;

#ifdef BLOOM
	vec3 fogBloom;
	vec3 bloom = getBloom(fogBloom);

#ifdef BLOOMY_FOG
	float bloomyFog = getBloomyFog(linearZ);
	fragColor = mix(fragColor, fogBloom, bloomyFog);
#endif

	// bloomy rain/snow particles
	if (blockId == 253 || blockId == 254) fragColor = mix(fragColor, fogBloom, 0.5);

	fragColor = mix(fragColor, bloom, BLOOM_INTENSITY);
#endif

#if defined WORLD_OVERWORLD
	// Reduce purkinje shift intensity around blocklight sources to preserve their colour
	float purkinjeIntensity = PURKINJE_SHIFT_INTENSITY * (0.1 - 0.1 * cube(blocklight));
	fragColor = purkinjeShift(fragColor, purkinjeIntensity);
#endif

//#ifdef CAMERA_LOCAL_EXPOSURE
//	fragColor *= getLocalExposure(linearZ);
//#else
	fragColor *= globalExposure;
//#endif

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
