/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/post/fxaa.fsh
  FXAA v3.11 from http://blog.simonrodriguez.fr/articles/2016/07/implementing_fxaa.html

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

layout (location = 0) out vec3 scene_color;

/* RENDERTARGETS: 0 */

in vec2 uv;

uniform sampler2D colortex0;

uniform vec2 view_pixel_size;

const int max_iterations = 12;
const float[12] quality = float[12](1.0, 1.0, 1.0, 1.0, 1.0, 1.5, 2.0, 2.0, 2.0, 2.0, 4.0, 8.0);

const float edge_threshold_min = 0.0312;
const float edge_threshold_max = 0.125;
const float subpixel_quality  = 0.75;

float get_luma(vec3 rgb) {
	const vec3 luminance_weights_r_709 = vec3(0.2126, 0.7152, 0.0722);
	return sqrt(dot(rgb, luminance_weights_r_709));
}

float min_of(float a, float b, float c, float d, float e) {
	return min(a, min(b, min(c, min(d, e))));
}

float max_of(float a, float b, float c, float d, float e) {
	return max(a, max(b, max(c, max(d, e))));
}

void main() {
	ivec2 texel = ivec2(gl_FragCoord.xy);

	// Detecting where to apply AA

	// Fetch 3x3 neighborhood
	// a b c
	// d e f
	// g h i
	vec3 a = texelFetch(colortex0, texel + ivec2(-1,  1), 0).rgb;
	vec3 b = texelFetch(colortex0, texel + ivec2( 0,  1), 0).rgb;
	vec3 c = texelFetch(colortex0, texel + ivec2( 1,  1), 0).rgb;
	vec3 d = texelFetch(colortex0, texel + ivec2(-1,  0), 0).rgb;
	vec3 e = texelFetch(colortex0, texel, 0).rgb;
	vec3 f = texelFetch(colortex0, texel + ivec2( 1,  0), 0).rgb;
	vec3 g = texelFetch(colortex0, texel + ivec2(-1, -1), 0).rgb;
	vec3 h = texelFetch(colortex0, texel + ivec2( 0, -1), 0).rgb;
	vec3 i = texelFetch(colortex0, texel + ivec2( 1, -1), 0).rgb;

	// Luma at the current fragment
	float luma = get_luma(e);

	// Luma at the four direct neighbors of the current fragment
	float luma_u = get_luma(b);
	float luma_l = get_luma(d);
	float luma_r = get_luma(f);
	float luma_d = get_luma(h);

	// Maximum and minimum luma around the current fragment
	float luma_min = min_of(luma, luma_d, luma_u, luma_l, luma_r);
	float luma_max = max_of(luma, luma_d, luma_u, luma_l, luma_r);

	// Compute the delta
	float luma_range = luma_max - luma_min;

	// If the luma variation is lower that a threshold (or if we are in a really dark area), we are not on an edge, don't perform any AA.
	if (luma_range < max(edge_threshold_min, luma_max * edge_threshold_max)) { scene_color = e; return; }

	// Estimating gradient and choosing edge direction

	// Get the lumas of the four remaining corners
	float luma_ul = get_luma(a);
	float luma_ur = get_luma(c);
	float luma_dl = get_luma(g);
	float luma_dr = get_luma(i);

	// Combine the four edges lumas (using intermediary variables for future computations with the same values)
	float luma_horizontal = luma_d + luma_u;
	float luma_vertical   = luma_l + luma_r;

	// Same for the corners
	float luma_left_corners  = luma_dl + luma_ul;
	float luma_down_corners  = luma_dl + luma_dr;
	float luma_right_corners = luma_dr + luma_ur;
	float luma_up_corners    = luma_ul + luma_ur;

	// Compute an estimation of the gradient along the horizontal and vertical axis.
	float edge_horizontal = abs(-2.0 * luma_l + luma_left_corners)  + abs(-2.0 * luma + luma_vertical)   * 2.0  + abs(-2.0 * luma_r + luma_right_corners);
	float edge_vertical   = abs(-2.0 * luma_u + luma_up_corners)    + abs(-2.0 * luma + luma_horizontal) * 2.0  + abs(-2.0 * luma_d + luma_down_corners);

	// Is the local edge horizontal or vertical?
	bool is_horizontal = edge_horizontal >= edge_vertical;

	// Choosing edge orientation

	// Select the two neighboring texels lumas in the opposite direction to the local edge
	float luma1 = is_horizontal ? luma_d : luma_l;
	float luma2 = is_horizontal ? luma_u : luma_r;

	// Compute gradients in this direction
	float gradient1 = luma1 - luma;
	float gradient2 = luma2 - luma;

	// Which direction is the steepest?
	bool is_1_steepest = abs(gradient1) >= abs(gradient2);

	// Gradient in the corresponding direction, normalized
	float gradient_scaled = 0.25 * max(abs(gradient1), abs(gradient2));

	// Choose the step size (one pixel) according to the edge direction
	float step_length = is_horizontal ? view_pixel_size.y : view_pixel_size.x;

	// Average luma in the correct direction
	float luma_local_average;
	if (is_1_steepest) {
		// Switch the direction
		step_length = -step_length;
		luma_local_average = 0.5 * (luma1 + luma);
	} else {
		luma_local_average = 0.5 * (luma2 + luma);
	}

	// Shift UV in the correct direction by half a pixel
	vec2 current_uv = uv;
	if (is_horizontal) {
		current_uv.y += step_length * 0.5;
	} else {
		current_uv.x += step_length * 0.5;
	}

	// First iteration exploration

	// Compute offste (for each iteration step) in the right direction
	vec2 offset = is_horizontal ? vec2(view_pixel_size.x, 0.0) : vec2(0.0, view_pixel_size.y);

	// Compute UVs to explore on each side of the edge, orthogonally. "quality" allows us to step faster
	vec2 uv1 = current_uv - offset;
	vec2 uv2 = current_uv + offset;

	// Read the lumas at both current extremities of the exploration segment, and compute the delta wrt the local average luma
	float luma_end_1 = get_luma(textureLod(colortex0, uv1, 0).rgb);
	float luma_end_2 = get_luma(textureLod(colortex0, uv2, 0).rgb);
	luma_end_1 -= luma_local_average;
	luma_end_2 -= luma_local_average;

	// If the luma deltas at the current extremities are larger than the local gradient, we have reached the side of the edge
	bool reached1 = abs(luma_end_1) >= gradient_scaled;
	bool reached2 = abs(luma_end_2) >= gradient_scaled;
	bool reached_both = reached1 && reached2;

	// If the side is not reached, we continue to explore in this direction
	if (!reached1) uv1 -= offset;
	if (!reached2) uv2 += offset;

	// Iterating

	// If both sides have not been reached, continue to explore
	if (!reached_both) {
		for (int i = 2; i < max_iterations; ++i) {
			// If needed, read luma in 1st direction, compute delta
			if (!reached1) {
				luma_end_1  = get_luma(textureLod(colortex0, uv1, 0).rgb);
				luma_end_1 -= luma_local_average;
			}
			// If needed, read luma in the opposite direction, compute delta
			if (!reached2) {
				luma_end_2  = get_luma(textureLod(colortex0, uv2, 0).rgb);
				luma_end_2 -= luma_local_average;
			}

			// If the luma deltas at the current extremities is larger than the local gradient, we have reached the side of the edge
			reached1 = abs(luma_end_1) >= gradient_scaled;
			reached2 = abs(luma_end_2) >= gradient_scaled;
			reached_both = reached1 && reached2;

			// If the side is not reached, we continue to explore in this direction, with a variable quality
			if (!reached1) uv1 -= offset * quality[i];
			if (!reached2) uv2 += offset * quality[i];

			// If both sides have been reached, stop the exploration
			if (reached_both) break;
		}
	}

	// Estimating offset

	// Compute the distance to each extremity of the edge
	float distance1 = is_horizontal ? (uv.x - uv1.x) : (uv.y - uv1.y);
	float distance2 = is_horizontal ? (uv2.x - uv.x) : (uv2.y - uv.y);

	// In which direction is the extremity of the edge closer?
	bool is_direction_1 = distance1 < distance2;
	float distance_final = min(distance1, distance2);

	// Length of the edge
	float edge_thickness = distance1 + distance2;

	// UV offset: read in the direction of the closest side of the edge
	float pixel_offset = -distance_final / edge_thickness + 0.5;

	// Is the luma at center smaller than the local average?
	bool is_luma_center_smaller = luma < luma_local_average;

	// If the luma at center is smaller than at its neighbour, the delta luma at each end should be positive (same variation)
	bool correct_variation = ((is_direction_1 ? luma_end_1 : luma_end_2) < 0.0) != is_luma_center_smaller;

	// If the luma variation is incorrect, do not offset
	float final_offset = correct_variation ? pixel_offset : 0.0;

	// Subpixel antialiasing

	// Full weighted average of the luma over the 3x3 neighborhood
	float luma_average = rcp(12.0) * (2.0 * (luma_horizontal + luma_vertical) + luma_left_corners + luma_right_corners);

	// Ratio of the delta between the global average and the center luma, over the luma range in the 3x3 neighborhood
	float sub_pixel_offset_1 = clamp01(abs(luma_average - luma) / luma_range);
	float sub_pixel_offset_2 = (-2.0 * sub_pixel_offset_1 + 3.0) * sub_pixel_offset_1 * sub_pixel_offset_1;

	// Compute a sub-pixel offset based on this delta.
	float sub_pixel_offset_final = sub_pixel_offset_2 * sub_pixel_offset_2 * subpixel_quality;

	// Pick the biggest of the two offsets.
	final_offset = max(final_offset, sub_pixel_offset_final);

	// Final read

	// Compute the final UV uvinates
	vec2 final_uv = uv;
	if (is_horizontal) {
		final_uv.y += final_offset * step_length;
	} else {
		final_uv.x += final_offset * step_length;
	}

	// Return the color at the new UV uvinates
	scene_color = textureLod(colortex0, final_uv, 0).rgb;
}

#ifndef FXAA 
	#error "This program should be disabled if FXAA is disabled"
#endif
