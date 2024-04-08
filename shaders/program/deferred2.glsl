/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/deferred2.glsl:
  Temporal upscaling for clouds
  Create combined depth buffer (DH)

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"


//----------------------------------------------------------------------------//
#if defined vsh

out vec2 uv;

void main() {
	uv = gl_MultiTexCoord0.xy;

	vec2 vertex_pos = gl_Vertex.xy * taau_render_scale;
	gl_Position = vec4(vertex_pos * 2.0 - 1.0, 0.0, 1.0);
}

#endif
//----------------------------------------------------------------------------//



//----------------------------------------------------------------------------//
#if defined fsh

layout (location = 0) out vec4 clouds_history;
layout (location = 1) out vec2 clouds_data;

/* RENDERTARGETS: 11,12 */

#ifdef DISTANT_HORIZONS
layout (location = 2) out float combined_depth;

/* RENDERTARGETS: 11,12,15 */
#endif

in vec2 uv;

// ------------
//   Uniforms
// ------------

uniform sampler2D noisetex;

uniform sampler2D colortex6;  // previous frame depth
uniform sampler2D colortex9;  // low-res clouds
uniform sampler2D colortex10; // low-res clouds apparent distance
uniform sampler2D colortex11; // clouds history
uniform sampler2D colortex12; // clouds data

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
uniform float frameTime;

uniform vec3 light_dir;

uniform vec2 view_res;
uniform vec2 view_pixel_size;
uniform vec2 taa_offset;
uniform vec2 clouds_offset;

uniform bool daylight_cycle_enabled;
uniform bool world_age_changed;

// ------------
//   Includes
// ------------

#define TEMPORAL_REPROJECTION

#include "/include/misc/distant_horizons.glsl"
#include "/include/utility/bicubic.glsl"
#include "/include/utility/checkerboard.glsl"
#include "/include/utility/dithering.glsl"
#include "/include/utility/encoding.glsl"
#include "/include/utility/fast_math.glsl"
#include "/include/utility/geometry.glsl"
#include "/include/utility/random.glsl"
#include "/include/utility/space_conversion.glsl"

vec4 min_of(vec4 a, vec4 b, vec4 c, vec4 d, vec4 e) {
	return min(a, min(b, min(c, min(d, e))));
}

vec4 max_of(vec4 a, vec4 b, vec4 c, vec4 d, vec4 e) {
	return max(a, max(b, max(c, max(d, e))));
}

vec4 smooth_filter(sampler2D sampler, vec2 coord) {
	// from https://iquilezles.org/www/articles/texture/texture.htm
	vec2 res = vec2(textureSize(sampler, 0));

	coord = coord * res + 0.5;

	vec2 i, f = modf(coord, i);
	f = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	coord = i + f;

	coord = (coord - 0.5) / res;
	return texture(sampler, coord);
}

float texture_min_4x4(sampler2D s, vec2 coord) {
	vec2 pixel_size = rcp(textureSize(s, 0).xy);

	vec4 samples_0 = textureGather(s, coord + vec2( 2.0 * pixel_size.x,  2.0 * pixel_size.y));
	vec4 samples_1 = textureGather(s, coord + vec2(-2.0 * pixel_size.x,  2.0 * pixel_size.y));
	vec4 samples_2 = textureGather(s, coord + vec2( 2.0 * pixel_size.x, -2.0 * pixel_size.y));
	vec4 samples_3 = textureGather(s, coord + vec2(-2.0 * pixel_size.x, -2.0 * pixel_size.y));

	return min(
		min(min_of(samples_0), min_of(samples_1)),
		min(min_of(samples_2), min_of(samples_3))
	);
}

vec3 reproject_clouds(vec2 uv, float distance_to_cloud) {
	const float planet_radius                 = 6371e3;
	const float clouds_cumulus_radius         = planet_radius + CLOUDS_CUMULUS_ALTITUDE;
	const float clouds_altocumulus_radius     = planet_radius + CLOUDS_ALTOCUMULUS_ALTITUDE;
	const float clouds_cirrus_radius          = planet_radius + CLOUDS_CIRRUS_ALTITUDE;
	const float clouds_cumulus_wind_angle     = CLOUDS_CUMULUS_WIND_ANGLE * degree;
	const float clouds_altocumulus_wind_angle = CLOUDS_ALTOCUMULUS_WIND_ANGLE * degree;
	const float clouds_cirrus_wind_angle      = CLOUDS_CIRRUS_WIND_ANGLE * degree;
	const vec3  clouds_cumulus_velocity       = CLOUDS_CUMULUS_WIND_SPEED * vec3(cos(clouds_cumulus_wind_angle), 0.0, sin(clouds_cumulus_wind_angle));
	const vec3  clouds_altocumulus_velocity   = CLOUDS_ALTOCUMULUS_WIND_SPEED * vec3(cos(clouds_altocumulus_wind_angle), 0.0, sin(clouds_altocumulus_wind_angle));
	const vec3  clouds_cirrus_velocity        = CLOUDS_CIRRUS_WIND_SPEED * vec3(cos(clouds_cirrus_wind_angle), 0.0, sin(clouds_cirrus_wind_angle));

	vec3 view_pos = screen_to_view_space(vec3(uv, 1.0), false, false);
	vec3 scene_pos = view_to_scene_space(view_pos);
	vec3 world_dir = normalize(scene_pos - gbufferModelViewInverse[3].xyz);

	vec3 cloud_pos = world_dir * distance_to_cloud + gbufferModelViewInverse[3].xyz;

	// Work out which layer this cloud belongs to
	vec3 velocity;
	vec3 air_cloud_pos = vec3(0.0, CLOUDS_SCALE * (eyeAltitude - SEA_LEVEL) + planet_radius, 0.0) + CLOUDS_SCALE * cloud_pos;
	float r = length(air_cloud_pos);

	if (r < clouds_altocumulus_radius) {
		velocity = clouds_cumulus_velocity;
	} else if (r < clouds_cirrus_radius) {
		velocity = clouds_altocumulus_velocity;
	} else {
		velocity = clouds_cirrus_velocity;
	}

	cloud_pos += velocity * frameTime * rcp(CLOUDS_SCALE) * float(daylight_cycle_enabled);

	return reproject_scene_space(cloud_pos, false, false);
}

void main() {
	// --------------------
	//   clouds upscaling
	// --------------------

	const int checkerboard_area = CLOUDS_TEMPORAL_UPSCALING * CLOUDS_TEMPORAL_UPSCALING;

	ivec2 dst_texel = ivec2(gl_FragCoord.xy);
	ivec2 src_texel = clamp(dst_texel / CLOUDS_TEMPORAL_UPSCALING, ivec2(0), ivec2(view_res * taau_render_scale) / CLOUDS_TEMPORAL_UPSCALING - 1);

#ifdef DISTANT_HORIZONS
	// Check for DH terrain
	float depth    = texelFetch(depthtex1, dst_texel, 0).x;
	float depth_dh = texelFetch(dhDepthTex, dst_texel, 0).x;
	bool is_dh_terrain = is_distant_horizons_terrain(depth, depth_dh);
#else
	const bool is_dh_terrain = false;
#endif

#if defined WORLD_OVERWORLD
	// Fetch 3x3 neighborhood
	vec4 a = texelFetch(colortex9, src_texel + ivec2(-1, -1), 0);
	vec4 b = texelFetch(colortex9, src_texel + ivec2( 0, -1), 0);
	vec4 c = texelFetch(colortex9, src_texel + ivec2( 1, -1), 0);
	vec4 d = texelFetch(colortex9, src_texel + ivec2(-1,  0), 0);
	vec4 e = texelFetch(colortex9, src_texel, 0);
	vec4 f = texelFetch(colortex9, src_texel + ivec2( 1,  0), 0);
	vec4 g = texelFetch(colortex9, src_texel + ivec2(-1,  1), 0);
	vec4 h = texelFetch(colortex9, src_texel + ivec2( 0,  1), 0);
	vec4 i = texelFetch(colortex9, src_texel + ivec2( 1,  1), 0);

	// Soft minimum and maximum ("Hybrid Reconstruction Antialiasing")
	//        b         a b c
	// (min d e f + min d e f) / 2
	//        h         g h i
	vec4 aabb_min  = min_of(b, d, e, f, h);
	     aabb_min += min_of(aabb_min, a, c, g, i);
	     aabb_min *= 0.5;
		 aabb_min  = max0(aabb_min);

	vec4 aabb_max  = max_of(b, d, e, f, h);
	     aabb_max += max_of(aabb_max, a, c, g, i);
	     aabb_max *= 0.5;
		 aabb_max  = max0(aabb_max);

	float apparent_distance = texelFetch(colortex10, src_texel, 0).x;

	// Find closest cloud distance in a 4x4 area, accross current and previous frame
#ifdef TAAU
	// Fix issue at the top and left side of the screen with TAAU
	vec2 uv_clamped = clamp(uv, 0.0, 0.95);
#else
	#define uv_clamped uv
#endif

	float closest_distance = min(
		texture_min_4x4(colortex10, uv_clamped * taau_render_scale),
		texture_min_4x4(colortex12, uv_clamped * taau_render_scale)
	);

	// Reproject
	vec2 previous_uv = reproject_clouds(uv, closest_distance).xy;

#ifdef TAAU
	vec2 previous_uv_clamped = clamp(previous_uv, vec2(0.0), 1.0 - 2.0 * view_pixel_size / taau_render_scale);
#else
	#define previous_uv_clamped previous_uv
#endif

	vec4 current = e;
	vec4 history = smooth_filter(colortex11, previous_uv_clamped * taau_render_scale);

	// Depth at the previous position
	float history_depth = 1.0 - min_of(textureGather(colortex6, previous_uv_clamped, 2));

	// Get distance to terrain in the previous frame
	vec3 screen_pos = vec3(previous_uv, history_depth);
	vec3 view_pos = screen_to_view_space(combined_projection_matrix_inverse, screen_pos, true);
	float distance_to_terrain = length(view_pos);

	// Work out whether the history should be invalidated
	bool disocclusion = clamp01(previous_uv) != previous_uv;
		 disocclusion = disocclusion || (history_depth < 1.0 && distance_to_terrain < closest_distance);
		 disocclusion = disocclusion || any(isnan(history));
	     disocclusion = disocclusion || world_age_changed;

	// Replace history if a disocclusion was detected
	if (disocclusion) history = current;

	// Perform neighbourhood clamping when moving quickly relative to the clouds
	float velocity = rcp(sqr(frameTime)) * length_squared(cameraPosition - previousCameraPosition);
	float velocity_factor = 75.0 * velocity / max(sqr(closest_distance), eps);
	      velocity_factor = velocity_factor / (velocity_factor + 1.0);

	history = mix(
		history,
		clamp(history, aabb_min, aabb_max),
		velocity_factor
	);

	// Get previous pixel age and apparent distance
	vec2 history_data = texture(colortex12, previous_uv_clamped * taau_render_scale).xy;
	float apparent_distance_history = history_data.x;
	      apparent_distance_history = disocclusion ? apparent_distance : apparent_distance_history;

	// Reset pixel age on disocclusion
	float pixel_age = max0(history_data.y) * float(!disocclusion);

	// Checkerboard upscaling
	ivec2 offset_0 = dst_texel % CLOUDS_TEMPORAL_UPSCALING;
	ivec2 offset_1 = clouds_checkerboard_offsets[frameCounter % checkerboard_area];
	if (offset_0 != offset_1 && !disocclusion) {
		current = history;
		apparent_distance = min(apparent_distance, apparent_distance_history);
	}

	// Reduce history weight when player is moving quickly
	float movement_rejection = exp(-16.0 * length(cameraPosition - previousCameraPosition));
	pixel_age *= movement_rejection * 0.07 + 0.93;

	float history_weight  = 1.0 - rcp(max(pixel_age - checkerboard_area, 1.0));
	      history_weight *= mix(1.0, movement_rejection, history_weight);

	// Offcenter rejection
#ifndef TAAU
	vec2 pixel_center_offset = 1.0 - abs(fract(previous_uv * view_res) * 2.0 - 1.0);
	float offcenter_rejection = sqrt(pixel_center_offset.x * pixel_center_offset.y);
          offcenter_rejection = mix(1.0, offcenter_rejection, history_weight);

	history_weight *= offcenter_rejection;
#endif
	
	clouds_history = max0(mix(current, history, history_weight));
	clouds_data.x = mix(apparent_distance, apparent_distance_history, history_weight);
	clouds_data.y = min(++pixel_age, CLOUDS_ACCUMULATION_LIMIT);
#endif

	// --------------------------------
	//   combined depth buffer for DH
	// --------------------------------

#ifdef DISTANT_HORIZONS
	float depth_linear    = screen_to_view_space_depth(gbufferProjectionInverse, depth);
	float depth_linear_dh = screen_to_view_space_depth(dhProjectionInverse, depth_dh);

	combined_depth = is_dh_terrain
		? view_to_screen_space_depth(combined_projection_matrix, depth_linear_dh)
		: view_to_screen_space_depth(combined_projection_matrix, depth_linear);

	if (depth >= 1.0 && !is_dh_terrain) {
		combined_depth = 1.0;
	}
#endif
}

#endif
//----------------------------------------------------------------------------//
