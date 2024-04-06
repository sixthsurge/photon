#if !defined INCLUDE_MISC_EDGE_HIGHLIGHT
#define INCLUDE_MISC_EDGE_HIGHLIGHT

#include "/include/utility/encoding.glsl"
#include "/include/utility/space_conversion.glsl"

// MC Dungeons-inspired edge highlight effect

bool has_edge_highlight(vec3 normal) {
	// Returns true for faces pointing along an axis
	return abs(dot(abs(normal), vec3(1.0)) - 1.0) < 0.1;
}

float edge_highlight_check(
	vec3 offset,
	vec3 center_pos,
	vec3 center_normal,
	float center_depth,
	float rcp_NoV,
	vec2 depth_gradient
) {
	// Calculate sample position in screen space
	vec3 sample_pos = scene_to_view_space(center_pos + offset);
	     sample_pos = view_to_screen_space(combined_projection_matrix, sample_pos, true);

	// Sample depth and gbuffer data
	ivec2 texel = ivec2(sample_pos.xy * view_res * taau_render_scale);
	float sample_depth = texelFetch(combined_depth_buffer, texel, 0).x;
	float sample_data  = texelFetch(colortex1, texel, 0).z;

	// Test for depth discontinuity
	sample_depth = linearize_depth_fast(sample_depth);
	float expected_depth = center_depth + dot(depth_gradient, sample_pos.xy - uv);
	float depth_edge = float(abs(sample_depth - expected_depth) > 0.25 * rcp_NoV && expected_depth < sample_depth);

	// Test for normal discontinuity
	vec3 sample_normal = decode_unit_vector(unpack_unorm_2x8(sample_data));
	float normal_edge = float(abs(dot(center_normal, sample_normal)) < 0.99 && dot(sample_normal, normalize(offset)) > 0.01);

	return (depth_edge + normal_edge) * float(clamp01(sample_pos) == sample_pos) * float(has_edge_highlight(sample_normal) || center_depth < sample_depth);
}

float get_edge_highlight(vec3 scene_pos, vec3 world_normal, float depth, uint material_mask) {
	// Size of one block pixel in world-space
	const float pixel_size = rcp(EDGE_HIGHLIGHT_SCALE);

	// Calculate tangent and bitangent
	mat3 tbn = get_tbn_matrix(world_normal) * pixel_size;

	// Calculate depth gradient using screen-space partial derivatives
	float depth_linear = linearize_depth_fast(depth);
	vec2 depth_gradient = vec2(dFdx(depth), dFdy(depth));

	float rcp_NoV = abs(rcp(dot(normalize(scene_pos), world_normal)));

	// Check for an edge in 5 directions around the sample point
	float highlight  = edge_highlight_check( tbn[0], scene_pos, world_normal, depth_linear, rcp_NoV, depth_gradient);
	      highlight += edge_highlight_check(-tbn[0], scene_pos, world_normal, depth_linear, rcp_NoV, depth_gradient);
	      highlight += edge_highlight_check( tbn[1], scene_pos, world_normal, depth_linear, rcp_NoV, depth_gradient);
	      highlight += edge_highlight_check(-tbn[1], scene_pos, world_normal, depth_linear, rcp_NoV, depth_gradient);
	      highlight += edge_highlight_check( tbn[2], scene_pos, world_normal, depth_linear, rcp_NoV, depth_gradient);

	return clamp01(float(has_edge_highlight(world_normal)) * highlight);
}

#endif // INCLUDE_MISC_EDGE_HIGHLIGHT
