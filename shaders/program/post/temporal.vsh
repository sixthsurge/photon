/*
--------------------------------------------------------------------------------

  Photon Shaders by SixthSurge

  program/post/temporal.vsh:
  Calculate auto exposure

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

out vec2 uv;

flat out float exposure;

#if DEBUG_VIEW == DEBUG_VIEW_HISTOGRAM
flat out vec4[HISTOGRAM_BINS / 4] histogramPdf;
flat out float histogramSelectedBin;
#endif

uniform sampler2D colortex0; // Scene color
uniform sampler2D colortex5; // Scene history

uniform vec2 viewSize;
uniform vec2 texelSize;

uniform float frameTime;
uniform float screenBrightness;

#include "/include/utility/color.glsl"

#define getExposureFromEv100(ev100) exp2(-(ev100))
#define getExposureFromLuminance(l) calibration / (l)
#define getLuminanceFromExposure(e) calibration / (e)

const float K = 12.5; // Light-meter calibration constant
const float sensitivity = 100.0; // ISO
const float calibration = exp2(AUTO_EXPOSURE_BIAS) * K / sensitivity / 1.2;

const float minLuminance = getLuminanceFromExposure(getExposureFromEv100(AUTO_EXPOSURE_MIN));
const float maxLuminance = getLuminanceFromExposure(getExposureFromEv100(AUTO_EXPOSURE_MAX));
const float minLogLuminance = log2(minLuminance);
const float maxLogLuminance = log2(maxLuminance);

#ifdef MANUAL_EXPOSURE_USE_SCREEN_BRIGHTNESS
float manualExposureValue = mix(minLuminance, maxLuminance, screenBrightness);
#else
const float manualExposureValue = MANUAL_EXPOSURE_VALUE;
#endif

float getBinFromLuminance(float luminance) {
	const float binCount = HISTOGRAM_BINS;
	const float rcpLogLuminanceRange = 1.0 / (maxLogLuminance - minLogLuminance);
	const float scaledMinLogLuminance = minLogLuminance * rcpLogLuminanceRange;

	if (luminance <= minLuminance) return 0.0; // Avoid taking log of 0

	float logLuminance = clamp01(log2(luminance) * rcpLogLuminanceRange - scaledMinLogLuminance);

	return min(binCount * logLuminance, binCount - 1.0);
}

float getLuminanceFromBin(int bin) {
	const float logLuminanceRange = maxLogLuminance - minLogLuminance;

	float logLuminance = bin * rcp(float(HISTOGRAM_BINS));

	return exp2(logLuminance * logLuminanceRange + minLogLuminance);
}

void buildHistogram(out float[HISTOGRAM_BINS] pdf) {
	// Initialize PDF to 0
	for (int i = 0; i < HISTOGRAM_BINS; ++i) pdf[i] = 0.0;

	const ivec2 tiles = ivec2(32, 18);
	const vec2 tileSize = rcp(vec2(tiles));

	float lod = ceil(log2(maxOf(viewSize * tileSize)));

	// Sample into histogram
	for (int y = 0; y < tiles.y; ++y) {
		for (int x = 0; x < tiles.x; ++x) {
			vec2 coord = vec2(x, y) * tileSize + (0.5 * tileSize);

			vec3 rgb = textureLod(colortex0, coord * taauRenderScale, lod).rgb;
			float luminance = dot(rgb, luminanceWeightsAp1);

			float bin = getBinFromLuminance(luminance);

			uint bin0 = uint(bin);
			uint bin1 = bin0 + 1;

			float weight1 = fract(bin);
			float weight0 = 1.0 - weight1;

			pdf[bin0] += weight0;
			pdf[bin1] += weight1;
		}
	}

	// Normalize PDF
	float tileArea = tileSize.x * tileSize.y;
	for (int i = 0; i < HISTOGRAM_BINS; ++i) pdf[i] *= tileArea;
}

float getMedianLuminance(float[HISTOGRAM_BINS] pdf) {
	float cdf = 0.0;

	for (int i = 0; i < HISTOGRAM_BINS; ++i) {
		cdf += pdf[i];
		if (cdf > HISTOGRAM_TARGET) return getLuminanceFromBin(i);
	}

	return 0.0; // ??
}

void main() {
	uv = gl_MultiTexCoord0.xy;

	// Auto exposure

#if AUTO_EXPOSURE == AUTO_EXPOSURE_OFF
	exposure = getExposureFromEv100(manualExposureValue);
#else
	float previousExposure = texelFetch(colortex5, ivec2(0), 0).a;

#if   AUTO_EXPOSURE == AUTO_EXPOSURE_SIMPLE
	float lod = ceil(log2(maxOf(viewSize)));
	vec3 rgb = textureLod(colortex0, vec2(0.5 * taauRenderScale), int(lod)).rgb;
	float luminance = clamp(getLuminance(rgb), minLuminance, maxLuminance);
#elif AUTO_EXPOSURE == AUTO_EXPOSURE_HISTOGRAM
	float[HISTOGRAM_BINS] pdf;
	buildHistogram(pdf);

	float luminance = getMedianLuminance(pdf);
#endif

	float targetExposure = getExposureFromLuminance(luminance);

	if (isnan(previousExposure) || isinf(previousExposure)) previousExposure = targetExposure;

	float adjustmentRate = targetExposure < previousExposure ? AUTO_EXPOSURE_RATE_DIM_TO_BRIGHT : AUTO_EXPOSURE_RATE_BRIGHT_TO_DIM;
	float blendWeight = exp(-adjustmentRate * frameTime);

	exposure = mix(targetExposure, previousExposure, blendWeight);
#endif

#if AUTO_EXPOSURE == AUTO_EXPOSURE_HISTOGRAM && DEBUG_VIEW == DEBUG_VIEW_HISTOGRAM
	for (int i = 0; i < HISTOGRAM_BINS; ++i) histogramPdf[i >> 2][i & 3] = pdf[i];
	histogramSelectedBin = getBinFromLuminance(luminance);
#endif

	gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 0.0, 1.0);
}
