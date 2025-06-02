/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/c4_taa_exposure:
  TAA and auto exposure

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"


layout (location = 0) out vec3 bloom_input;
layout (location = 1) out vec4 result;

/* RENDERTARGETS: 0,5 */

in vec2 uv;

flat in float exposure;

#if DEBUG_VIEW == DEBUG_VIEW_HISTOGRAM
flat in vec4[HISTOGRAM_BINS / 4] histogram_pdf;
flat in float histogram_selected_bin;
#endif

// ------------
//   Uniforms
// ------------

uniform sampler2D colortex0; // Scene color
uniform sampler2D colortex5; // Scene history

#ifdef TAAU
uniform sampler2D colortex1; // TAA min color
uniform sampler2D colortex2; // TAA max color
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

uniform float frameTime;
uniform float near;
uniform float far;

uniform vec2 view_res;
uniform vec2 view_pixel_size;
uniform vec2 taa_offset;

#define TEMPORAL_REPROJECTION

#include "/include/misc/distant_horizons.glsl"
#include "/include/utility/bicubic.glsl"
#include "/include/utility/color.glsl"
#include "/include/utility/space_conversion.glsl"

#define TAA_VARIANCE_CLIPPING // More aggressive neighborhood clipping method which further reduces ghosting but can introduce flickering artifacts
#define TAA_OFFCENTER_REJECTION 0.25 // Reduces blur when moving quickly. Too much offcenter rejection results in aliasing and jittering in motion
#define TAAU_CONFIDENCE_REJECTION 5.0 // Controls the impact of the "confidence-of-quality" factor on temporal upscaling. Tradeoff between image clarity and time taken to converge
#define TAAU_FLICKER_REDUCTION 1.0 // Increases ghosting but reduces flickering caused by aggressive clipping

/*
(needed by vertex stage for auto exposure)
#if AUTO_EXPOSURE != AUTO_EXPOSURE_OFF
const bool colortex0MipmapEnabled = true;
#endif
 */

vec3 min_of(vec3 a, vec3 b, vec3 c, vec3 d, vec3 f) {
    return min(a, min(b, min(c, min(d, f))));
}

vec3 max_of(vec3 a, vec3 b, vec3 c, vec3 d, vec3 f) {
    return max(a, max(b, max(c, max(d, f))));
}

// Invertible tonemapping operator (Reinhard) applied before blending the current and previous frames
// Improves the appearance of emissive objects
vec3 reinhard(vec3 rgb) {
	return rgb / (rgb + 1.0);
}

vec3 reinhard_inverse(vec3 rgb) {
	return rgb / (1.0 - rgb);
}

// Estimates the closest fragment in a 5x5 radius with 5 samples in a cross pattern
// Improves reprojection for objects in motion
vec3 get_closest_fragment(sampler2D depth_sampler, ivec2 texel0) {
	ivec2 texel1 = texel0 + ivec2(-2, -2);
	ivec2 texel2 = texel0 + ivec2( 2, -2);
	ivec2 texel3 = texel0 + ivec2(-2,  2);
	ivec2 texel4 = texel0 + ivec2( 2,  2);

	float depth0 = texelFetch(depth_sampler, texel0, 0).x;
	float depth1 = texelFetch(depth_sampler, texel1, 0).x;
	float depth2 = texelFetch(depth_sampler, texel2, 0).x;
	float depth3 = texelFetch(depth_sampler, texel3, 0).x;
	float depth4 = texelFetch(depth_sampler, texel4, 0).x;

	vec3 pos  = depth0 < depth1 ? vec3(texel0, depth0) : vec3(texel1, depth1);
	vec3 pos1 = depth2 < depth3 ? vec3(texel2, depth2) : vec3(texel3, depth3);
	     pos  = pos.z  < pos1.z ? pos : pos1;
	     pos  = pos.z  < depth4 ? pos : vec3(texel4, depth4);

	return vec3((pos.xy + 0.5) * view_pixel_size * rcp(taau_render_scale), pos.z);
}

// AABB clipping from "Temporal Reprojection Anti-Aliasing in INSIDE"
vec3 clip_aabb(vec3 history_color, vec3 min_color, vec3 max_color, out bool history_clipped) {
	vec3 p_clip = 0.5 * (max_color + min_color);
	vec3 e_clip = 0.5 * (max_color - min_color);

	vec3 v_clip = history_color - p_clip;
	vec3 v_unit = v_clip / max(e_clip, 1e-3);
	vec3 a_unit = abs(v_unit);
	float ma_unit = max_of(a_unit);
	history_clipped = ma_unit > 1.0;

	return history_clipped ? p_clip + v_clip / ma_unit : history_color;
}

vec3 clip_aabb(vec3 history_color, vec3 min_color, vec3 max_color) {
	bool history_clipped;
	return clip_aabb(history_color, min_color, max_color, history_clipped);
}

// Flicker reduction using the "distance to clamp" method from "High Quality Temporal Supersampling"
// by Brian Karis. Only used for TAAU
float get_flicker_reduction(vec3 history_color, vec3 min_color, vec3 max_color) {
	const float flicker_sensitivity = 5.0;

	vec3 min_offset = (history_color - min_color);
	vec3 max_offset = (max_color - history_color);

	float distance_to_clip = length(min(min_offset, max_offset)) * flicker_sensitivity * exposure;
	return clamp01(distance_to_clip);
}

vec3 neighborhood_clipping(
	ivec2 texel,
	vec3 current_color,
	vec3 history_color,
	float distance_factor
) {
	vec3 min_color, max_color;

	// Fetch 3x3 neighborhood
	// a b c
	// d e f
	// g h i
	vec3 a = texelFetch(colortex0, texel + ivec2(-1,  1), 0).rgb;
	vec3 b = texelFetch(colortex0, texel + ivec2( 0,  1), 0).rgb;
	vec3 c = texelFetch(colortex0, texel + ivec2( 1,  1), 0).rgb;
	vec3 d = texelFetch(colortex0, texel + ivec2(-1,  0), 0).rgb;
	vec3 e = current_color;
	vec3 f = texelFetch(colortex0, texel + ivec2( 1,  0), 0).rgb;
	vec3 g = texelFetch(colortex0, texel + ivec2(-1, -1), 0).rgb;
	vec3 h = texelFetch(colortex0, texel + ivec2( 0, -1), 0).rgb;
	vec3 i = texelFetch(colortex0, texel + ivec2( 1, -1), 0).rgb;

	// Convert to YCoCg 
	// Clipping in a luminance-chrominance color space is superior because the eyes are more 
	// sensitive to luminance than chrominance so an AABB where luminance is one of the axes 
	// will result in less visible ghosting than one which is not aligned to the luminance
	a = rgb_to_ycocg(reinhard(a));
	b = rgb_to_ycocg(reinhard(b));
	c = rgb_to_ycocg(reinhard(c));
	d = rgb_to_ycocg(reinhard(d));
	e = rgb_to_ycocg(reinhard(e));
	f = rgb_to_ycocg(reinhard(f));
	g = rgb_to_ycocg(reinhard(g));
	h = rgb_to_ycocg(reinhard(h));
	i = rgb_to_ycocg(reinhard(i));

	// Soft minimum and maximum ("Hybrid Reconstruction Antialiasing")
	//        b         a b c
	// (min d e f + min d e f) / 2
	//        h         g h i
	min_color  = min_of(b, d, e, f, h);
	min_color += min_of(min_color, a, c, g, i);
	min_color *= 0.5;

	max_color  = max_of(b, d, e, f, h);
	max_color += max_of(max_color, a, c, g, i);
	max_color *= 0.5;

#ifdef TAA_VARIANCE_CLIPPING
	// Variance clipping ("An Excursion in Temporal Supersampling")
	mat2x3 moments;
	moments[0] = (1.0 / 9.0) * (a + b + c + d + e + f + g + h + i);
	moments[1] = (1.0 / 9.0) * (a * a + b * b + c * c + d * d + e * e + f * f + g * g + h * h + i * i);

	// Strictness parameter, higher gamma => more temporally stable but more ghosting
	float gamma = mix(
		0.75, 1.25,
		linear_step(0.25, 1.0, distance_factor)
	); 

	vec3 mu = moments[0];
	vec3 sigma = sqrt(moments[1] - moments[0] * moments[0]);

	min_color = max(min_color, mu - gamma * sigma);
	max_color = min(max_color, mu + gamma * sigma);
#endif

	// Perform AABB clipping in YCoCg space, which results in a tighter AABB because luminance (Y)
	// is separated from chrominance (CoCg) as its own axis
	history_color = rgb_to_ycocg(history_color);
	history_color = clip_aabb(history_color, min_color, max_color);
	history_color = ycocg_to_rgb(history_color);

	return history_color;
}

#if AUTO_EXPOSURE == AUTO_EXPOSURE_HISTOGRAM && DEBUG_VIEW == DEBUG_VIEW_HISTOGRAM
void draw_histogram(ivec2 texel) {
	const int width  = 512;
	const int height = 256;

	const vec3 white = vec3(1.0);
	const vec3 black = vec3(0.0);
	const vec3 red   = vec3(1.0, 0.0, 0.0);

	vec2 coord = texel / vec2(width, height);

	if (all(lessThan(texel, ivec2(width, height)))) {
		int index = int(HISTOGRAM_BINS * coord.x);
		float threshold = coord.y;

		result.rgb = histogram_pdf[index >> 2][index & 3] > threshold
			? black
			: white;

		float median = max0(1.0 - abs(index - histogram_selected_bin));
		result.rgb = mix(result.rgb, red, median) / exposure;
	}
}
#endif

void main() {
	ivec2 texel = ivec2(gl_FragCoord.xy * taau_render_scale);

#ifdef TAA
	#ifndef DISTANT_HORIZONS
	vec3 closest = get_closest_fragment(depthtex0, texel);

	const bool is_dh_terrain = false;
	#else
	vec3 closest    = get_closest_fragment(depthtex0, texel);
	vec3 closest_dh = get_closest_fragment(dhDepthTex, texel);

	bool is_dh_terrain = is_distant_horizons_terrain(closest.z, closest_dh.z);

	closest = is_dh_terrain
		? closest_dh
		: closest;
	#endif

	vec3 closest_view  = screen_to_view_space(closest, false, is_dh_terrain);
	vec3 closest_scene = view_to_scene_space(closest_view);

	bool hand = closest.z < hand_depth;

	vec2 velocity = closest.xy - reproject_scene_space(closest_scene, hand, is_dh_terrain).xy;
	vec2 previous_uv = uv - velocity;

	vec3 history_color = catmull_rom_filter_fast_rgb(colortex5, previous_uv, 0.6);
	     history_color = max0(history_color); // Eliminate NaNs in the history

	float pixel_age = texelFetch(colortex5, ivec2(previous_uv * view_res), 0).a;
	      pixel_age = max0(pixel_age * float(clamp01(previous_uv) == previous_uv) + 1.0);

	// Distance factor to favour responsiveness closer to the camera and image stability further 
	// away
	float distance_factor = 1.0 - exp2(-0.025 * length(closest_view));

	// Dynamic blend weight lending equal weight to all frames in the history, drastically reducing
	// time taken to converge when upscaling
	float blend_weight = mix(0.35, 0.10, distance_factor);
	float alpha = max(1.0 / pixel_age, blend_weight);

#ifndef TAAU
	// Native resolution TAA
	vec3 current_color = texelFetch(colortex0, texel, 0).rgb;

	// "Tonemapping" before applying TAA in order to perform the AA in SDR
	// This improves the result because the differences between the luminances are closer to 
	// how they will be in the final output
	current_color = reinhard(current_color);
	history_color = reinhard(history_color);

	history_color = neighborhood_clipping(texel, current_color, history_color, distance_factor);
#else
	// Temporal upscaling
	vec2 pos = clamp01(uv + 0.5 * taa_offset * rcp(taau_render_scale)) * taau_render_scale;

	float confidence; // Confidence-of-quality factor, see "A Survey of Temporal Antialiasing Techniques" section 5.1
	vec3 current_color = catmull_rom_filter(colortex0, pos, confidence).rgb;

	if (min_of(current_color) < 0.0) {
		// Fix negatives arising around very dark objects
		current_color = texture(colortex0, pos).rgb;
	}

	current_color = reinhard(current_color);
	history_color = reinhard(history_color);

	// Interpolate AABB bounds across pixels
	vec3 min_color = texture(colortex1, pos).rgb * 2.0 - 1.0;
	vec3 max_color = texture(colortex2, pos).rgb * 2.0 - 1.0;

	bool history_clipped;
	history_color = rgb_to_ycocg(history_color);
	history_color = clip_aabb(history_color, min_color, max_color, history_clipped);
	float flicker_reduction = history_clipped ? 0.0 : get_flicker_reduction(history_color, min_color, max_color);
	history_color = ycocg_to_rgb(history_color);

	alpha *= pow(confidence, TAAU_CONFIDENCE_REJECTION);
	alpha *= 1.0 - TAAU_FLICKER_REDUCTION * flicker_reduction;
#endif

	// Offcenter rejection from Jessie, which is originally by Zombye
	// Reduces blur in motion
	vec2 pixel_offset = 1.0 - abs(2.0 * fract(view_res * previous_uv) - 1.0);
	float offcenter_rejection = sqrt(pixel_offset.x * pixel_offset.y) * TAA_OFFCENTER_REJECTION + (1.0 - TAA_OFFCENTER_REJECTION);

	alpha  = 1.0 - alpha;
	alpha *= offcenter_rejection;
	alpha  = 1.0 - alpha;

	current_color = mix(history_color, current_color, alpha);
	current_color = reinhard_inverse(current_color);

	result = vec4(current_color, pixel_age * offcenter_rejection);
#else // TAA disabled
	result = texelFetch(colortex0, texel, 0);
#endif

	// Store exposure in the alpha component of the bottom left texel of the history buffer
	if (texel == ivec2(0)) result.a = exposure;

#if AUTO_EXPOSURE == AUTO_EXPOSURE_HISTOGRAM && DEBUG_VIEW == DEBUG_VIEW_HISTOGRAM
	draw_histogram(texel);
#endif

	bloom_input = result.rgb;
}

