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
uniform sampler2D colortex3;
uniform sampler2D colortex8;  // Scene history and exposure

//--// Camera uniforms

uniform int isEyeInWater;

uniform ivec2 eyeBrightness;
uniform ivec2 eyeBrightnessSmooth;

uniform float near;
uniform float far;

uniform vec3 cameraPosition;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

//--// Custom uniforms

uniform vec2 taaOffset;

uniform vec2 viewSize;
uniform vec2 windowSize;

//--// Includes //------------------------------------------------------------//

#include "/include/fragment/aces/aces.glsl"

#include "/include/utility/bicubic.glsl"
#include "/include/utility/color.glsl"
#include "/include/utility/fastMath.glsl"
#include "/include/utility/spaceConversion.glsl"

//--// Functions //-----------------------------------------------------------//

vec3 tonemapAces(vec3 rgb) {
	rgb *= 2.0; // Match the exposure to the RRT
	rgb = acesRrt(rgb);
	rgb = acesOdt(rgb);

	return rgb;
}

vec3 tonemapAcesFit(vec3 rgb) {
	rgb *= 2.0; // Match the exposure to the RRT
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

#ifdef PURKINJE_SHIFT
	// Reduce purkinje shift intensity around blocklight sources to preserve their colour
	float purkinjeIntensity = PURKINJE_SHIFT_INTENSITY - PURKINJE_SHIFT_INTENSITY * cube(blocklight);
	fragColor = purkinjeShift(fragColor, purkinjeIntensity);
#endif

#ifdef CAMERA_LOCAL_EXPOSURE
	fragColor *= getLocalExposure(depth);
#else
	fragColor *= globalExposure;
#endif

#ifdef GRADE
	fragColor = pow(fragColor, vec3(0.95));
#endif

	fragColor = tonemap(fragColor);
	fragColor = fragColor * ap1ToR709;
}
