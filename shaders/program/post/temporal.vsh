/*
 * Program description:
 * Calculate global exposure using luminance histogram
 *
 * References:
 * http://www.alextardif.com/HistogramLuminance.html (Overview, histogram construction)
 * https://www.gamedev.net/forums/topic/670001-calculate-hdr-exposure-from-luminance-histogram/5241692/ (Histogram average)
 * https://github.com/zombye/spectrum/blob/master/shaders/program/temporal.glsl (GLSL implementation from Spectrum)
 */

#include "/include/global.glsl"

//--// Outputs //-------------------------------------------------------------//

out vec2 coord;

flat out float globalExposure;

#ifdef HISTOGRAM_VIEW
flat out vec4[HISTOGRAM_BINS / 4] histogramPdf;
flat out float histogramSelectedBin;
#endif

//--// Uniforms //------------------------------------------------------------//

uniform sampler2D colortex3; // Scene color
uniform sampler2D colortex8; // Scene history

uniform float frameTime;

uniform vec2 viewSize;
uniform vec2 viewTexelSize;

//--// Includes //------------------------------------------------------------//

#include "/include/utility/color.glsl"

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

			vec3 rgb = textureLod(colortex3, coord, lod).rgb;
			float luminance = dot(rgb, luminanceWeightsR709);

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

float calculateAverageLuminance(float[HISTOGRAM_BINS] pdf) {
	float sum = 0.0;
	for (int i = 0; i < HISTOGRAM_BINS; ++i) sum += pdf[i];

	float minSum = sum * HISTOGRAM_IGNORE_DIM;
	float maxSum = sum * (1.0 - HISTOGRAM_IGNORE_BRIGHT);

	float l = 0.0, n = 0.0;

	for (int i = 0; i < HISTOGRAM_BINS; ++i) {
		float binValue = pdf[i];

		float minSub = min(binValue, minSum);
		binValue -= minSub;
		minSum -= minSub;
		maxSum -= minSub;

		// Remove outlier at upper end
		binValue = min(binValue, maxSum);
		maxSum -= binValue;

		l += binValue * getLuminanceFromBin(i);
		n += binValue;
	}

	return l / max(n, eps);
}

void main() {
	coord = gl_MultiTexCoord0.xy;

	//--// Auto exposure

#ifdef CAMERA_MANUAL_EXPOSURE
	globalExposure = getExposureFromEv100(CAMERA_MANUAL_EXPOSURE);
#else
	float[HISTOGRAM_BINS] pdf;
	buildHistogram(pdf);

	float luminance = calculateAverageLuminance(pdf);

	float targetExposure = getExposureFromLuminance(luminance);
	float previousExposure = texelFetch(colortex8, ivec2(0), 0).a;

	if (isnan(previousExposure) || isinf(previousExposure)) previousExposure = targetExposure;

	float adjustmentRate = targetExposure < previousExposure ? CAMERA_EXPOSURE_RATE_DIM_TO_BRIGHT : CAMERA_EXPOSURE_RATE_BRIGHT_TO_DIM;
	float blendWeight = exp(-adjustmentRate * frameTime);

	globalExposure = mix(targetExposure, previousExposure, blendWeight);
#endif

#ifdef HISTOGRAM_VIEW
	for (int i = 0; i < HISTOGRAM_BINS; ++i) histogramPdf[i >> 2][i & 3] = pdf[i];
	histogramSelectedBin = getBinFromLuminance(luminance);
#endif

	gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 0.0, 1.0);
}
