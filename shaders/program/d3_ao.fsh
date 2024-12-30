/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/d3_ao:
  Calculate ambient occlusion

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

layout (location = 0) out vec4 ao;

/* RENDERTARGETS: 6 */

in vec2 uv;

// ------------
//   Uniforms
// ------------

uniform sampler2D noisetex;

uniform sampler2D colortex1; // gbuffer 0
uniform sampler2D colortex2; // gbuffer 1
uniform sampler2D colortex6; // ambient occlusion history

uniform sampler2D depthtex1;

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
uniform float eyeAltitude;

uniform int frameCounter;

uniform vec3 light_dir;

uniform vec2 view_res;
uniform vec2 view_pixel_size;
uniform vec2 taa_offset;
uniform vec2 clouds_offset;

uniform bool world_age_changed;

// ------------
//   Includes
// ------------

#define TEMPORAL_REPROJECTION

#include "/include/misc/distant_horizons.glsl"
#include "/include/utility/bicubic.glsl"
#include "/include/utility/dithering.glsl"
#include "/include/utility/encoding.glsl"
#include "/include/utility/fast_math.glsl"
#include "/include/utility/random.glsl"
#include "/include/utility/space_conversion.glsl"

const float gtao_render_scale = 0.5;

#define GTAO_SLICES        2
#define GTAO_HORIZON_STEPS 3
#define GTAO_RADIUS        2.0
#define GTAO_FALLOFF_START 0.75

float integrate_arc(vec2 h, float n, float cos_n) {
	vec2 tmp = cos_n + 2.0 * h * sin(n) - cos(2.0 * h - n);
	return 0.25 * (tmp.x + tmp.y);
}

float calculate_maximum_horizon_angle(
	vec3 view_slice_dir,
	vec3 viewer_dir,
	vec3 screen_pos,
	vec3 view_pos,
	float radius,
	float dither,
    bool is_dh_terrain
) {
	float step_size = (GTAO_RADIUS * rcp(float(GTAO_HORIZON_STEPS))) * radius;

	float max_cos_theta = -1.0;

	vec2 ray_step = (view_to_screen_space(view_pos + view_slice_dir * step_size, true, is_dh_terrain) - screen_pos).xy;
	vec2 ray_pos = screen_pos.xy + ray_step * (dither + max_of(view_pixel_size) * rcp_length(ray_step));

	for (int i = 0; i < GTAO_HORIZON_STEPS; ++i, ray_pos += ray_step) {
        ivec2 texel = ivec2(clamp01(ray_pos) * view_res * taau_render_scale - 0.5);
		float depth = texelFetch(combined_depth_buffer, texel, 0).x;

		if (depth == 1.0 || depth < hand_depth || depth == screen_pos.z) continue;

		vec3 offset = screen_to_view_space(combined_projection_matrix_inverse, vec3(ray_pos, depth), true) - view_pos;

		float len_sq = length_squared(offset);
		float norm = inversesqrt(len_sq);

		float distance_falloff = linear_step(GTAO_FALLOFF_START * GTAO_RADIUS, GTAO_RADIUS, len_sq * norm * rcp(radius));

		float cos_theta = dot(viewer_dir, offset) * norm;
		      cos_theta = mix(cos_theta, -1.0, distance_falloff);

		max_cos_theta = max(cos_theta, max_cos_theta);
	}

	return fast_acos(clamp(max_cos_theta, -1.0, 1.0));
}

float ambient_occlusion(vec3 screen_pos, vec3 view_pos, vec3 view_normal, vec2 dither, bool is_dh_terrain) {
	float ao = 0.0;
	// vec3 bent_normal = vec3(0.0);

	// Construct local working space
	vec3 viewer_dir   = normalize(-view_pos);
	vec3 viewer_right = normalize(cross(vec3(0.0, 1.0, 0.0), viewer_dir));
	vec3 viewer_up    = cross(viewer_dir, viewer_right);
	mat3 local_to_view = mat3(viewer_right, viewer_up, viewer_dir);

	// Reduce AO radius very close up, makes some screen-space artifacts less obvious
	float ao_radius = max(0.25 + 0.75 * smoothstep(0.0, 81.0, length_squared(view_pos)), 0.5);

    // Increase AO radius for DH terrain (looks really good)
#ifdef DISTANT_HORIZONS
    if (is_dh_terrain) {
        ao_radius *= 3.0;
    }
#endif

	for (int i = 0; i < GTAO_SLICES; ++i) {
		float slice_angle = (i + dither.x) * (pi / float(GTAO_SLICES));

		vec3 slice_dir = vec3(cos(slice_angle), sin(slice_angle), 0.0);
		vec3 view_slice_dir = local_to_view * slice_dir;

		vec3 ortho_dir = slice_dir - dot(slice_dir, viewer_dir) * viewer_dir;
		vec3 axis = cross(slice_dir, viewer_dir);
		vec3 projected_normal = view_normal - axis * dot(view_normal, axis);

		float len_sq = dot(projected_normal, projected_normal);
		float norm = inversesqrt(len_sq);

		float sgn_gamma = sign(dot(ortho_dir, projected_normal));
		float cos_gamma = clamp01(dot(projected_normal, viewer_dir) * norm);
		float gamma = sgn_gamma * fast_acos(cos_gamma);

		vec2 max_horizon_angles;
		max_horizon_angles.x = calculate_maximum_horizon_angle(-view_slice_dir, viewer_dir, screen_pos, view_pos, ao_radius, dither.y, is_dh_terrain);
		max_horizon_angles.y = calculate_maximum_horizon_angle( view_slice_dir, viewer_dir, screen_pos, view_pos, ao_radius, dither.y, is_dh_terrain);

		max_horizon_angles = gamma + clamp(vec2(-1.0, 1.0) * max_horizon_angles - gamma, -half_pi, half_pi);
		ao += integrate_arc(max_horizon_angles, gamma, cos_gamma) * len_sq * norm;

		// float bent_angle = dot(max_horizon_angles, vec2(0.5));
		// bent_normal += viewer_dir * cos(bent_angle) + ortho_dir * sin(bent_angle);
	}

	const float albedo = 0.2; // albedo of surroundings (for multibounce approx)

	ao *= rcp(float(GTAO_SLICES));
	ao /= albedo * ao + (1.0 - albedo);

	// bent_normal = normalize(normalize(bent_normal) - 0.5 * viewer_dir);

	return ao;
}

void main() {
	ivec2 texel      = ivec2(gl_FragCoord.xy);
	ivec2 view_texel = ivec2(gl_FragCoord.xy * (taau_render_scale / gtao_render_scale));

	if (clamp(view_texel, ivec2(0), ivec2(view_res)) != view_texel) { return; }

	float depth = texelFetch(combined_depth_buffer, view_texel, 0).x;

#ifndef NORMAL_MAPPING
	vec4 gbuffer_data = texelFetch(colortex1, view_texel, 0);
#else
	vec4 gbuffer_data = texelFetch(colortex2, view_texel, 0);
#endif

	vec2 dither = vec2(texelFetch(noisetex, texel & 511, 0).b, texelFetch(noisetex, (texel + 249) & 511, 0).b);

    // Distant Horizons support

#ifdef DISTANT_HORIZONS
    float depth_mc = texelFetch(depthtex1, view_texel, 0).x;
    float depth_dh = texelFetch(dhDepthTex, view_texel, 0).x;
	bool is_dh_terrain = is_distant_horizons_terrain(depth_mc, depth_dh);
#else
    const bool is_dh_terrain = false;
#endif

	depth += 0.38 * float(depth < hand_depth); // Hand lighting fix from Capt Tatsu

	vec3 screen_pos = vec3(uv, depth);
	vec3 view_pos = screen_to_view_space(combined_projection_matrix_inverse, screen_pos, true);
	vec3 scene_pos = view_to_scene_space(view_pos);

	vec3 previous_screen_pos = reproject_scene_space(scene_pos, false, false);

	if (depth == 1.0) { ao.xyz = vec3(1.0, 0.0, 0.0); return; }

	// GTAO

#ifdef NORMAL_MAPPING
	vec3 world_normal = decode_unit_vector(gbuffer_data.xy);

	#ifdef DISTANT_HORIZONS
	if (is_dh_terrain) {
		vec4 gbuffer_data_0 = texelFetch(colortex1, view_texel, 0);
		world_normal = decode_unit_vector(unpack_unorm_2x8(gbuffer_data_0.z));
	}
	#endif
#else
	vec3 world_normal = decode_unit_vector(unpack_unorm_2x8(gbuffer_data.z));
#endif

	vec3 view_normal = mat3(gbufferModelView) * world_normal;

	dither = r2(frameCounter, dither);

#ifdef GTAO
	ao.x = ambient_occlusion(screen_pos, view_pos, view_normal, dither, is_dh_terrain);
#else
	ao.x = 1.0;
#endif

	// Temporal accumulation

	const float max_accumulated_frames       = 10.0;
	const float depth_rejection_strength     = 16.0;
	const float offcenter_rejection_strength = 0.25;

	vec3 history_ao = catmull_rom_filter_fast_rgb(colortex6, previous_screen_pos.xy, 0.65);
	     history_ao = (clamp01(previous_screen_pos.xy) == previous_screen_pos.xy) ? history_ao : vec3(ao.x, vec2(0.0));
	     history_ao = max0(history_ao);

	float pixel_age = history_ao.y;
	      pixel_age = min(pixel_age, max_accumulated_frames);

	// Offcenter rejection from Jessie, which is originally by Zombye
	// Reduces blur in motion
	vec2 pixel_offset = 1.0 - abs(2.0 * fract(view_res * gtao_render_scale * previous_screen_pos.xy) - 1.0);
	float offcenter_rejection = sqrt(pixel_offset.x * pixel_offset.y) * offcenter_rejection_strength + (1.0 - offcenter_rejection_strength);

	// Depth rejection
	float view_norm = rcp_length(view_pos);
	float NoV = abs(dot(view_normal, view_pos)) * view_norm; // NoV / sqrt(length(view_pos))
	float z0 = screen_to_view_space_depth(combined_projection_matrix_inverse, depth);
	float z1 = screen_to_view_space_depth(combined_projection_matrix_inverse, 1.0 - history_ao.z);
	float depth_weight = exp2(-abs(z0 - z1) * depth_rejection_strength * NoV * view_norm);

	pixel_age *= depth_weight * offcenter_rejection * float(history_ao.z != 1.0);

	float history_weight = pixel_age / (pixel_age + 1.0);

	ao.x = mix(ao.x, history_ao.x, history_weight);
	ao.y = pixel_age + 1.0;
	ao.z = 1.0 - depth; // Storing reversed depth improves precision for fp buffers
}

