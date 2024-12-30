/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/c4_taa_exposure:
  TAA and auto exposure

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"


out vec2 uv;

flat out float exposure;

#if DEBUG_VIEW == DEBUG_VIEW_HISTOGRAM
flat out vec4[HISTOGRAM_BINS / 4] histogram_pdf;
flat out float histogram_selected_bin;
#endif

uniform sampler2D colortex0; // Scene color
uniform sampler2D colortex5; // Scene history

uniform float frameTime;
uniform float screenBrightness;

uniform vec2 view_res;
uniform vec2 view_pixel_size;
uniform vec2 taa_offset;

#include "/include/utility/color.glsl"

#define get_exposure_from_ev_100(ev100) exp2(-(ev100))
#define get_exposure_from_luminance(l) calibration / (l)
#define get_luminance_from_exposure(e) calibration / (e)

const float K = 12.5; // Light-meter calibration constant
const float sensitivity = 100.0; // ISO
const float calibration = exp2(AUTO_EXPOSURE_BIAS) * K / sensitivity / 1.2;

const float min_luminance = get_luminance_from_exposure(get_exposure_from_ev_100(AUTO_EXPOSURE_MIN));
const float max_luminance = get_luminance_from_exposure(get_exposure_from_ev_100(AUTO_EXPOSURE_MAX));
const float min_log_luminance = log2(min_luminance);
const float max_log_luminance = log2(max_luminance);

#ifdef MANUAL_EXPOSURE_USE_SCREEN_BRIGHTNESS
float manual_exposure_value = mix(min_luminance, max_luminance, screenBrightness);
#else
const float manual_exposure_value = MANUAL_EXPOSURE_VALUE;
#endif

float get_bin_from_luminance(float luminance) {
	const float bin_count = HISTOGRAM_BINS;
	const float rcp_log_luminance_range = 1.0 / (max_log_luminance - min_log_luminance);
	const float scaled_min_log_luminance = min_log_luminance * rcp_log_luminance_range;

	if (luminance <= min_luminance) return 0.0; // Avoid taking log of 0

	float log_luminance = clamp01(log2(luminance) * rcp_log_luminance_range - scaled_min_log_luminance);

	return min(bin_count * log_luminance, bin_count - 1.0);
}

float get_luminance_from_bin(int bin) {
	const float log_luminance_range = max_log_luminance - min_log_luminance;

	float log_luminance = bin * rcp(float(HISTOGRAM_BINS));

	return exp2(log_luminance * log_luminance_range + min_log_luminance);
}

void build_histogram(out float[HISTOGRAM_BINS] pdf) {
	// Initialize PDF to 0
	for (int i = 0; i < HISTOGRAM_BINS; ++i) pdf[i] = 0.0;

	const ivec2 tiles = ivec2(32, 18);
	const vec2 tile_size = rcp(vec2(tiles));

	float lod = ceil(log2(max_of(view_res * tile_size)));

	// Sample into histogram
	for (int y = 0; y < tiles.y; ++y) {
		for (int x = 0; x < tiles.x; ++x) {
			vec2 coord = vec2(x, y) * tile_size + (0.5 * tile_size);

			vec3 rgb = textureLod(colortex0, coord * taau_render_scale, lod).rgb;
			float luminance = dot(rgb, luminance_weights_ap1);

			float bin = get_bin_from_luminance(luminance);

			uint bin0 = uint(bin);
			uint bin1 = bin0 + 1;

			float weight1 = fract(bin);
			float weight0 = 1.0 - weight1;

			pdf[bin0] += weight0;
			pdf[bin1] += weight1;
		}
	}

	// Normalize PDF
	float tile_area = tile_size.x * tile_size.y;
	for (int i = 0; i < HISTOGRAM_BINS; ++i) pdf[i] *= tile_area;
}

float get_median_luminance(float[HISTOGRAM_BINS] pdf) {
	float cdf = 0.0;

	for (int i = 0; i < HISTOGRAM_BINS; ++i) {
		cdf += pdf[i];
		if (cdf > HISTOGRAM_TARGET) return get_luminance_from_bin(i);
	}

	return 0.0; // ??
}

void main() {
	uv = gl_MultiTexCoord0.xy;

	// Auto exposure

#if AUTO_EXPOSURE == AUTO_EXPOSURE_OFF
	exposure = get_exposure_from_ev_100(manual_exposure_value);
#else
	float previous_exposure = texelFetch(colortex5, ivec2(0), 0).a;

#if   AUTO_EXPOSURE == AUTO_EXPOSURE_SIMPLE
	float lod = ceil(log2(max_of(view_res)));
	vec3 rgb = textureLod(colortex0, vec2(0.5 * taau_render_scale), int(lod)).rgb;
	float luminance = clamp(dot(rgb, luminance_weights), min_luminance, max_luminance);
#elif AUTO_EXPOSURE == AUTO_EXPOSURE_HISTOGRAM
	float[HISTOGRAM_BINS] pdf;
	build_histogram(pdf);

	float luminance = get_median_luminance(pdf);
#endif

	float target_exposure = get_exposure_from_luminance(luminance);

	if (isnan(previous_exposure) || isinf(previous_exposure)) previous_exposure = target_exposure;

	float adjustment_rate = target_exposure < previous_exposure ? AUTO_EXPOSURE_RATE_DIM_TO_BRIGHT : AUTO_EXPOSURE_RATE_BRIGHT_TO_DIM;
	float blend_weight = exp(-adjustment_rate * frameTime);

	exposure = mix(target_exposure, previous_exposure, blend_weight);
#endif

#if AUTO_EXPOSURE == AUTO_EXPOSURE_HISTOGRAM && DEBUG_VIEW == DEBUG_VIEW_HISTOGRAM
	for (int i = 0; i < HISTOGRAM_BINS; ++i) histogram_pdf[i >> 2][i & 3] = pdf[i];
	histogram_selected_bin = get_bin_from_luminance(luminance);
#endif

	gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 0.0, 1.0);
}

