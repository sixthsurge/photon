#version 400 compatibility

/*
--------------------------------------------------------------------------------

  Photon Shaders by SixthSurge

  world0/deferred2.fsh:
  Calculate ambient occlusion, temporal upscaling for clouds

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

/* DRAWBUFFERS:67 */
layout (location = 0) out vec3 ao;
layout (location = 1) out vec4 clouds;

in vec2 uv;

uniform sampler2D noisetex;

uniform sampler2D colortex1; // Gbuffer 0
uniform sampler2D colortex2; // Gbuffer 1
uniform sampler2D colortex6; // Ambient occlusion history
uniform sampler2D colortex7; // Clouds history

// TEMPORARY
uniform sampler2D colortex5; // Scene history

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

uniform int frameCounter;

uniform vec3 light_dir;

uniform vec2 view_res;
uniform vec2 view_pixel_size;
uniform vec2 taa_offset;
uniform vec2 clouds_offset;

uniform bool world_age_changed;

#define TEMPORAL_REPROJECTION
#define WORLD_OVERWORLD

#include "/include/utility/bicubic.glsl"
#include "/include/utility/checkerboard.glsl"
#include "/include/utility/dithering.glsl"
#include "/include/utility/encoding.glsl"
#include "/include/utility/fast_math.glsl"
#include "/include/utility/random.glsl"
#include "/include/utility/space_conversion.glsl"

const float gtao_render_scale = 0.5;

// from https://iquilezles.org/www/articles/texture/texture.htm
vec4 smooth_filter(sampler2D sampler, vec2 coord) {
	vec2 res = vec2(textureSize(sampler, 0));

	coord = coord * res + 0.5;

	vec2 i, f = modf(coord, i);
	f = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	coord = i + f;

	coord = (coord - 0.5) / res;
	return texture(sampler, coord);
}

// ---------------------
//   ambient occlusion
// ---------------------

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
	float dither
) {
	const float step_size = GTAO_RADIUS * rcp(float(GTAO_HORIZON_STEPS));

	float max_cos_theta = -1.0;

	vec2 ray_step = (view_to_screen_space(view_pos + view_slice_dir * step_size, true) - screen_pos).xy;
	vec2 ray_pos = screen_pos.xy + ray_step * (dither + max_of(view_pixel_size) * rcp_length(ray_step));

	for (int i = 0; i < GTAO_HORIZON_STEPS; ++i, ray_pos += ray_step) {
		float depth = texelFetch(depthtex1, ivec2(clamp01(ray_pos) * view_res * taau_render_scale - 0.5), 0).x;

		if (is_sky(depth) || is_hand(depth) || depth == screen_pos.z) continue;

		vec3 offset = screen_to_view_space(vec3(ray_pos, depth), true) - view_pos;

		float len_sq = length_squared(offset);
		float norm = inversesqrt(len_sq);

		float distance_falloff = linear_step(GTAO_FALLOFF_START * GTAO_RADIUS, GTAO_RADIUS, len_sq * norm);

		float cos_theta = dot(viewer_dir, offset) * norm;
		      cos_theta = mix(cos_theta, -1.0, distance_falloff);

		max_cos_theta = max(cos_theta, max_cos_theta);
	}

	return fast_acos(clamp(max_cos_theta, -1.0, 1.0));
}

float ambient_occlusion(vec3 screen_pos, vec3 view_pos, vec3 view_normal, vec2 dither) {
	float ao = 0.0;
	// vec3 bent_normal = vec3(0.0);

	// Construct local working space
	vec3 viewer_dir   = normalize(-view_pos);
	vec3 viewer_right = normalize(cross(vec3(0.0, 1.0, 0.0), viewer_dir));
	vec3 viewer_up    = cross(viewer_dir, viewer_right);
	mat3 local_to_view = mat3(viewer_right, viewer_up, viewer_dir);

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
		max_horizon_angles.x = calculate_maximum_horizon_angle(-view_slice_dir, viewer_dir, screen_pos, view_pos, dither.y);
		max_horizon_angles.y = calculate_maximum_horizon_angle( view_slice_dir, viewer_dir, screen_pos, view_pos, dither.y);

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

// --------------------
//   clouds upscaling
// --------------------

#define CLOUDS_ACCUMULATION_LIMIT 0.9
#define CLOUDS_OFFCENTER_REJECTION 0.5

vec4 upscale_clouds(vec2 previous_uv) {
	vec3 ao_history = texture(colortex6, previous_uv * gtao_render_scale).xyz;

	ivec2 dst_texel = ivec2(gl_FragCoord.xy);
	ivec2 src_texel = clamp(dst_texel / 2, ivec2(0), ivec2(view_res) / 4 - 1);

	vec2 previous_uv_clamped = clamp(previous_uv, vec2(0.0), 1.0 - 2.0 * view_pixel_size);

	bool disocclusion = clamp01(previous_uv) != previous_uv;
	     disocclusion = disocclusion || ao_history.z > eps;
	     disocclusion = disocclusion || world_age_changed;

	vec4 current = texelFetch(colortex5, src_texel, 0);
	vec4 history = catmull_rom_filter(colortex7, previous_uv_clamped * gtao_render_scale);
	     history = max0(history); // kill any NaNs

	if (disocclusion) history = current;

	float pixel_age  = max0(ao_history.y);
	      pixel_age -= pixel_age * float(disocclusion);

	float history_weight = min(pixel_age / (pixel_age + 1.0), CLOUDS_ACCUMULATION_LIMIT);

	// Checkerboard upscaling
	ivec2 offset0 = dst_texel % ivec2(2);
	ivec2 offset1 = checkerboard_offsets_2x2[frameCounter % 4];
	if (offset0 != offset1) current = history;

	// Velocity rejection
	vec2 velocity = 0.5 * view_res * (uv - previous_uv);
	history_weight *= exp(-length(velocity)) * 0.7 + 0.3;

	// Offcenter rejection from Jessie, which is originally by Zombye
	// Reduces blur in motion
	vec2 pixel_offset = 1.0 - abs(2.0 * fract(view_res * gtao_render_scale * previous_uv) - 1.0);
	history_weight *= sqrt(pixel_offset.x * pixel_offset.y) * CLOUDS_OFFCENTER_REJECTION + (1.0 - CLOUDS_OFFCENTER_REJECTION);

	ao.y = min(pixel_age + 1.0, 256);

	return mix(current, history, history_weight);
}

void main() {
	ivec2 texel      = ivec2(gl_FragCoord.xy);
	ivec2 view_texel = ivec2(gl_FragCoord.xy * (taau_render_scale / gtao_render_scale));

	float depth = texelFetch(depthtex1, view_texel, 0).x;

#ifndef NORMAL_MAPPING
	vec4 gbuffer_data = texelFetch(colortex1, view_texel, 0);
#else
	vec4 gbuffer_data = texelFetch(colortex2, view_texel, 0);
#endif

	vec2 dither = vec2(texelFetch(noisetex, texel & 511, 0).b, texelFetch(noisetex, (texel + 249) & 511, 0).b);

	depth += 0.38 * float(is_hand(depth)); // Hand lighting fix from Capt Tatsu

	vec3 screen_pos = vec3(uv, depth);
	vec3 view_pos = screen_to_view_space(screen_pos, true);
	vec3 scene_pos = view_to_scene_space(view_pos);

	vec3 previous_screen_pos = reproject(screen_pos);

	if (depth == 1.0) {
		ao = vec3(1.0, 0.0, 0.0);
		clouds = upscale_clouds(previous_screen_pos.xy);
	} else {
		clouds = vec4(0.0, 0.0, 0.0, 1.0);

		// GTAO

	#ifdef NORMAL_MAPPING
		vec3 world_normal = decode_unit_vector(gbuffer_data.xy);
	#else
		vec3 world_normal = decode_unit_vector(unpack_unorm_2x8(gbuffer_data.z));
	#endif

		vec3 view_normal = mat3(gbufferModelView) * world_normal;

		dither = r2(frameCounter, dither);

	#ifdef GTAO
		ao.x = ambient_occlusion(screen_pos, view_pos, view_normal, dither);
	#else
		ao.x = 1.0;
	#endif

		// Temporal accumulation

		const float max_accumulated_frames       = 10.0;
		const float depth_rejection_strength     = 16.0;
		const float offcenter_rejection_strength = 0.25;

		vec3 history_ao = catmull_rom_filter_fast_rgb(colortex6, previous_screen_pos.xy * gtao_render_scale, 0.65);
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
		float z0 = linearize_depth_fast(depth);
		float z1 = linearize_depth_fast(1.0 - history_ao.z);
		float depth_weight = exp2(-abs(z0 - z1) * depth_rejection_strength * NoV * view_norm);

		pixel_age *= depth_weight * offcenter_rejection * float(history_ao.z != 1.0);

		float history_weight = pixel_age / (pixel_age + 1.0);

		ao.x = mix(ao.x, history_ao.x, history_weight);
		ao.y = pixel_age + 1.0;
		ao.z = 1.0 - depth; // Storing reversed depth improves precision for fp buffers
	}
}
