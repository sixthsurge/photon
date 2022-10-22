/*
--------------------------------------------------------------------------------

  Photon Shaders by SixthSurge

  program/post/temporal.fsh:
  Perform TAA, store auto exposure value for later

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

/* DRAWBUFFERS:5 */
layout (location = 0) out vec4 result;

in vec2 uv;

flat in float exposure;

#if AUTO_EXPOSURE == AUTO_EXPOSURE_HISTOGRAM && DEBUG_VIEW == DEBUG_VIEW_HISTOGRAM
flat in vec4[HISTOGRAM_BINS / 4] histogramPdf;
flat in float histogramSelectedBin;
#endif

uniform sampler2D colortex0; // Scene color
uniform sampler2D colortex5; // Scene history

#ifdef TAAU
uniform sampler2D colortex6; // TAA min color
uniform sampler2D colortex7; // TAA max color
#endif

uniform sampler2D depthtex0;

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

uniform vec2 viewSize;
uniform vec2 texelSize;
uniform vec2 taaOffset;

#define TEMPORAL_REPROJECTION

#include "/include/utility/bicubic.glsl"
#include "/include/utility/color.glsl"
#include "/include/utility/spaceConversion.glsl"

#define TAA_VARIANCE_CLIPPING // More aggressive neighborhood clipping method which further reduces ghosting but can introduce flickering artifacts
#define TAA_BLEND_WEIGHT 0.1 // The maximum weight given to the current frame by the TAA. Higher values result in reduced ghosting and blur but jittering is more obvious
#define TAA_OFFCENTER_REJECTION 0.25 // Reduces blur when moving quickly. Too much offcenter rejection results in aliasing and jittering in motion
#define TAAU_CONFIDENCE_REJECTION 5.0 // Controls the impact of the "confidence-of-quality" factor on temporal upscaling. Tradeoff between image clarity and time taken to converge
#define TAAU_FLICKER_REDUCTION 1.0 // Increases ghosting but reduces flickering caused by aggressive clipping

/*
(needed by vertex stage for auto exposure)
const bool colortex0MipmapEnabled = true;
*/

vec3 minOf(vec3 a, vec3 b, vec3 c, vec3 d, vec3 f) {
    return min(a, min(b, min(c, min(d, f))));
}

vec3 maxOf(vec3 a, vec3 b, vec3 c, vec3 d, vec3 f) {
    return max(a, max(b, max(c, max(d, f))));
}

// Invertible tonemapping operator (Reinhard) applied before blending the current and previous frames
// Improves the appearance of emissive objects
vec3 tonemap(vec3 rgb) {
	return rgb / (rgb + 1.0);
}

vec3 tonemapInverse(vec3 rgb) {
	return rgb / (1.0 - rgb);
}

// Estimates the closest fragment in a 5x5 radius with 5 samples in a cross pattern
// Improves reprojection for objects in motion
vec3 getClosestFragment(ivec2 texel0) {
	ivec2 texel1 = texel0 + ivec2(-2, -2);
	ivec2 texel2 = texel0 + ivec2( 2, -2);
	ivec2 texel3 = texel0 + ivec2(-2,  2);
	ivec2 texel4 = texel0 + ivec2( 2,  2);

	float depth0 = texelFetch(depthtex0, texel0, 0).x;
	float depth1 = texelFetch(depthtex0, texel1, 0).x;
	float depth2 = texelFetch(depthtex0, texel2, 0).x;
	float depth3 = texelFetch(depthtex0, texel3, 0).x;
	float depth4 = texelFetch(depthtex0, texel4, 0).x;

	vec3 pos  = depth0 < depth1 ? vec3(texel0, depth0) : vec3(texel1, depth1);
	vec3 pos1 = depth2 < depth3 ? vec3(texel2, depth2) : vec3(texel3, depth3);
	     pos  = pos.z  < pos1.z ? pos : pos1;
	     pos  = pos.z  < depth4 ? pos : vec3(texel4, depth4);

	return vec3((pos.xy + 0.5) * texelSize * rcp(taauRenderScale), pos.z);
}

// AABB clipping from "Temporal Reprojection Anti-Aliasing in INSIDE"
vec3 clipAabb(vec3 historyColor, vec3 minColor, vec3 maxColor, out bool historyClipped) {
	vec3 pClip = 0.5 * (maxColor + minColor);
	vec3 eClip = 0.5 * (maxColor - minColor);

	vec3 vClip = historyColor - pClip;
	vec3 vUnit = vClip / eClip;
	vec3 aUnit = abs(vUnit);
	float maUnit = maxOf(aUnit);
	historyClipped = maUnit > 1.0;

	return historyClipped ? pClip + vClip / maUnit : historyColor;
}

vec3 clipAabb(vec3 historyColor, vec3 minColor, vec3 maxColor) {
	bool historyClipped;
	return clipAabb(historyColor, minColor, maxColor, historyClipped);
}

// Flicker reduction using the "distance to clamp" method from "High Quality Temporal Supersampling"
// by Brian Karis. Only used for TAAU
float getFlickerReduction(vec3 historyColor, vec3 minColor, vec3 maxColor) {
	const float flickerSensitivity = 5.0;

	vec3 minOffset = (historyColor - minColor);
	vec3 maxOffset = (maxColor - historyColor);

	float distanceToClip = length(min(minOffset, maxOffset)) * flickerSensitivity * exposure;
	return clamp01(distanceToClip);
}

vec3 neighborhoodClipping(ivec2 texel, vec3 currentColor, vec3 historyColor) {
	vec3 minColor, maxColor;

	// Fetch 3x3 neighborhood
	// a b c
	// d e f
	// g h i
	vec3 a = texelFetch(colortex0, texel + ivec2(-1,  1), 0).rgb;
	vec3 b = texelFetch(colortex0, texel + ivec2( 0,  1), 0).rgb;
	vec3 c = texelFetch(colortex0, texel + ivec2( 1,  1), 0).rgb;
	vec3 d = texelFetch(colortex0, texel + ivec2(-1,  0), 0).rgb;
	vec3 e = currentColor;
	vec3 f = texelFetch(colortex0, texel + ivec2( 1,  0), 0).rgb;
	vec3 g = texelFetch(colortex0, texel + ivec2(-1, -1), 0).rgb;
	vec3 h = texelFetch(colortex0, texel + ivec2( 0, -1), 0).rgb;
	vec3 i = texelFetch(colortex0, texel + ivec2( 1, -1), 0).rgb;

	// Convert to YCoCg
	a = rgbToYcocg(a);
	b = rgbToYcocg(b);
	c = rgbToYcocg(c);
	d = rgbToYcocg(d);
	e = rgbToYcocg(e);
	f = rgbToYcocg(f);
	g = rgbToYcocg(g);
	h = rgbToYcocg(h);
	i = rgbToYcocg(i);

	// Soft minimum and maximum ("Hybrid Reconstruction Antialiasing")
	//        b         a b c
	// (min d e f + min d e f) / 2
	//        h         g h i
	minColor  = minOf(b, d, e, f, h);
	minColor += minOf(minColor, a, c, g, i);
	minColor *= 0.5;

	maxColor  = maxOf(b, d, e, f, h);
	maxColor += maxOf(maxColor, a, c, g, i);
	maxColor *= 0.5;

#ifdef TAA_VARIANCE_CLIPPING
	// Variance clipping ("An Excursion in Temporal Supersampling")
	mat2x3 moments;
	moments[0] = (1.0 / 9.0) * (a + b + c + d + e + f + g + h + i);
	moments[1] = (1.0 / 9.0) * (a * a + b * b + c * c + d * d + e * e + f * f + g * g + h * h + i * i);

	const float gamma = 1.25; // Strictness parameter, higher gamma => less ghosting but more flickering and worse image quality
	vec3 mu = moments[0];
	vec3 sigma = sqrt(moments[1] - moments[0] * moments[0]);

	minColor = max(minColor, mu - gamma * sigma);
	maxColor = min(maxColor, mu + gamma * sigma);
#endif

	// Perform AABB clipping in YCoCg space, which results in a tighter AABB because luminance (Y)
	// is separated from chrominance (CoCg) as its own axis
	historyColor = rgbToYcocg(historyColor);
	historyColor = clipAabb(historyColor, minColor, maxColor);
	historyColor = ycocgToRgb(historyColor);

	return historyColor;
}

#if AUTO_EXPOSURE == AUTO_EXPOSURE_HISTOGRAM && DEBUG_VIEW == DEBUG_VIEW_HISTOGRAM
void drawHistogram(ivec2 texel) {
	const int width  = 512;
	const int height = 256;

	const vec3 white = vec3(1.0);
	const vec3 black = vec3(0.0);
	const vec3 red   = vec3(1.0, 0.0, 0.0);

	vec2 coord = texel / vec2(width, height);

	if (all(lessThan(texel, ivec2(width, height)))) {
		int index = int(HISTOGRAM_BINS * coord.x);
		float threshold = coord.y;

		result.rgb = histogramPdf[index >> 2][index & 3] > threshold
			? black
			: white;

		float median = max0(1.0 - abs(index - histogramSelectedBin));
		result.rgb = mix(result.rgb, red, median) / exposure;
	}
}
#endif

void main() {
	ivec2 texel = ivec2(gl_FragCoord.xy * taauRenderScale);

#ifdef TAA
	vec3 closest = getClosestFragment(texel);
	vec2 velocity = closest.xy - reproject(closest).xy;
	vec2 previousUv = uv - velocity;

	vec3 historyColor = textureCatmullRomFastRgb(colortex5, previousUv, 0.6);
	     historyColor = max0(historyColor); // Eliminate NaNs in the history

	float pixelAge = texelFetch(colortex5, ivec2(previousUv * viewSize), 0).a;
	      pixelAge = max0(pixelAge * float(clamp01(previousUv) == previousUv) + 1.0);

	// Dynamic blend weight lending equal weight to all frames in the history, drastically reducing
	// time taken to converge when upscaling
	float alpha = max(1.0 / pixelAge, TAA_BLEND_WEIGHT);

#ifndef TAAU
	// Native resolution TAA
	vec3 currentColor = texelFetch(colortex0, texel, 0).rgb;
	historyColor = neighborhoodClipping(texel, currentColor, historyColor);
#else
	// Temporal upscaling
	vec2 pos = clamp01(uv + 0.5 * taaOffset * rcp(taauRenderScale)) * taauRenderScale;

	float confidence; // Confidence-of-quality factor, see "A Survey of Temporal Antialiasing Techniques" section 5.1
	vec3 currentColor = textureCatmullRom(colortex0, pos, confidence).rgb;

	// Interpolate AABB bounds across pixels
	vec3 minColor = texture(colortex6, pos).rgb;
	vec3 maxColor = texture(colortex7, pos).rgb;

	bool historyClipped;
	historyColor = rgbToYcocg(historyColor);
	historyColor = clipAabb(historyColor, minColor, maxColor, historyClipped);
	float flickerReduction = historyClipped ? 0.0 : getFlickerReduction(historyColor, minColor, maxColor);
	historyColor = ycocgToRgb(historyColor);

	alpha *= pow(confidence, TAAU_CONFIDENCE_REJECTION);
	alpha *= 1.0 - TAAU_FLICKER_REDUCTION * flickerReduction;
#endif

	// Offcenter rejection from Jessie, which is originally by Zombye
	// Reduces blur in motion
	vec2 pixelOffset = 1.0 - abs(2.0 * fract(viewSize * previousUv) - 1.0);
	float offcenterRejection = sqrt(pixelOffset.x * pixelOffset.y) * TAA_OFFCENTER_REJECTION + (1.0 - TAA_OFFCENTER_REJECTION);

	alpha  = 1.0 - alpha;
	alpha *= offcenterRejection;
	alpha  = 1.0 - alpha;

	// Tonemap before blending and reverse it after
	// Improves the appearance of emissive objects
	currentColor = mix(tonemap(historyColor), tonemap(currentColor), alpha);
	currentColor = tonemapInverse(currentColor);

	result = vec4(currentColor, pixelAge * offcenterRejection);
#else // TAA disabled
	result = texelFetch(colortex0, texel, 0);
#endif

#if AUTO_EXPOSURE != AUTO_EXPOSURE_OFF
	// Store exposure in the alpha component of the bottom left texel of the history buffer
	if (texel == ivec2(0)) result.a = exposure;

#if AUTO_EXPOSURE == AUTO_EXPOSURE_HISTOGRAM && DEBUG_VIEW == DEBUG_VIEW_HISTOGRAM
	drawHistogram(texel);
#endif
#endif
}
