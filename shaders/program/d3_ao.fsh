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

#if SHADER_AO == SHADER_AO_SSAO
#include "/include/lighting/ao/ssao.glsl"
#endif

#if SHADER_AO == SHADER_AO_GTAO
#include "/include/lighting/ao/gtao.glsl"
#endif

const float ao_render_scale = 0.5;

void main() {
	ivec2 texel      = ivec2(gl_FragCoord.xy);
	ivec2 view_texel = ivec2(gl_FragCoord.xy * (taau_render_scale / ao_render_scale));

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

#if   SHADER_AO == SHADER_AO_NONE
	ao.x = 1.0;
#elif SHADER_AO == SHADER_AO_SSAO
	ao.x = compute_ssao(screen_pos, view_pos, view_normal, dither);
#elif SHADER_AO == SHADER_AO_GTAO
	ao.x = compute_gtao(screen_pos, view_pos, view_normal, dither, is_dh_terrain);
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

	// Depth rejection
	float view_norm = rcp_length(view_pos);
	float NoV = abs(dot(view_normal, view_pos)) * view_norm; // NoV / sqrt(length(view_pos))
	float z0 = screen_to_view_space_depth(combined_projection_matrix_inverse, depth);
	float z1 = screen_to_view_space_depth(combined_projection_matrix_inverse, 1.0 - history_ao.z);
	float depth_weight = exp2(-abs(z0 - z1) * depth_rejection_strength * NoV * view_norm);

	// Offcenter rejection from Jessie, which is originally by Zombye
	// Reduces blur in motion
	vec2 pixel_offset = 1.0 - abs(2.0 * fract(view_res * ao_render_scale * previous_screen_pos.xy) - 1.0);
	float offcenter_rejection = sqrt(pixel_offset.x * pixel_offset.y) * offcenter_rejection_strength + (1.0 - offcenter_rejection_strength);

	pixel_age *= depth_weight * offcenter_rejection * float(history_ao.z != 1.0);

	float history_weight = pixel_age / (pixel_age + 1.0);

	ao.x = mix(ao.x, history_ao.x, history_weight);
	ao.y = pixel_age + 1.0;
	ao.z = 1.0 - depth; // Storing reversed depth improves precision for fp buffers
}

