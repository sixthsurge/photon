/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/d1_clouds:
  Render clouds and aurora

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

layout (location = 0) out vec4 clouds;
layout (location = 1) out vec2 clouds_data;

/* RENDERTARGETS: 9,10 */

in vec2 uv;

#if defined WORLD_OVERWORLD
flat in vec3 sun_color;
flat in vec3 moon_color;
flat in vec3 sky_color;

flat in float aurora_amount;
flat in mat2x3 aurora_colors;

#include "/include/sky/clouds/parameters.glsl"
flat in CloudsParameters clouds_params;
#endif

// ------------
//   Uniforms
// ------------

uniform sampler3D colortex6; // 3D bubbly worley noise
#define SAMPLER_WORLEY_BUBBLY colortex6
uniform sampler3D colortex7; // 3D swirley worley noise
#define SAMPLER_WORLEY_SWIRLEY colortex7

uniform sampler2D colortex8; // cloud shadow map

uniform sampler3D depthtex0; // atmospheric scattering LUT
uniform sampler2D depthtex1;

uniform sampler2D noisetex;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform float near;
uniform float far;

uniform int worldTime;
uniform float sunAngle;

uniform int frameCounter;
uniform float frameTimeCounter;

uniform int isEyeInWater;
uniform float eyeAltitude;
uniform float rainStrength;
uniform float wetness;

uniform vec3 light_dir;
uniform vec3 sun_dir;
uniform vec3 moon_dir;

uniform vec2 view_res;
uniform vec2 view_pixel_size;
uniform vec2 taa_offset;

uniform float world_age;

uniform float time_sunrise;
uniform float time_noon;
uniform float time_sunset;
uniform float time_midnight;

uniform float biome_cave;
uniform float biome_temperate;
uniform float biome_arid;
uniform float biome_snowy;
uniform float biome_taiga;
uniform float biome_jungle;
uniform float biome_swamp;
uniform float biome_may_rain;
uniform float biome_may_snow;
uniform float biome_temperature;
uniform float biome_humidity;

// ------------
//   Includes
// ------------

#define ATMOSPHERE_SCATTERING_LUT depthtex0
#define MIE_PHASE_CLAMP

#ifdef CLOUDS_CUMULUS_PRECOMPUTE_LOCAL_COVERAGE
	#define CLOUDS_USE_LOCAL_COVERAGE_MAP
#endif

#if defined WORLD_OVERWORLD
#include "/include/sky/atmosphere.glsl"
#include "/include/sky/aurora.glsl"
#include "/include/sky/clouds.glsl"

#if defined CREPUSCULAR_RAYS && !defined BLOCKY_CLOUDS
#include "/include/sky/crepuscular_rays.glsl"
#endif
#endif

#include "/include/misc/distant_horizons.glsl"
#include "/include/utility/checkerboard.glsl"
#include "/include/utility/random.glsl"
#include "/include/utility/space_conversion.glsl"

const int checkerboard_area = CLOUDS_TEMPORAL_UPSCALING * CLOUDS_TEMPORAL_UPSCALING;

float depth_max_4x4(sampler2D depth_sampler) {
	vec4 depth_samples_0 = textureGather(depth_sampler, uv * taau_render_scale + vec2( 2.0 * view_pixel_size.x,  2.0 * view_pixel_size.y));
	vec4 depth_samples_1 = textureGather(depth_sampler, uv * taau_render_scale + vec2(-2.0 * view_pixel_size.x,  2.0 * view_pixel_size.y));
	vec4 depth_samples_2 = textureGather(depth_sampler, uv * taau_render_scale + vec2( 2.0 * view_pixel_size.x, -2.0 * view_pixel_size.y));
	vec4 depth_samples_3 = textureGather(depth_sampler, uv * taau_render_scale + vec2(-2.0 * view_pixel_size.x, -2.0 * view_pixel_size.y));

	return max(
		max(max_of(depth_samples_0), max_of(depth_samples_1)),
		max(max_of(depth_samples_2), max_of(depth_samples_3))
	);
}

void main() {
	ivec2 texel = ivec2(gl_FragCoord.xy);

	clouds = vec4(0.0, 0.0, 0.0, 1.0);

#if defined WORLD_OVERWORLD
	ivec2 checkerboard_pos = CLOUDS_TEMPORAL_UPSCALING * texel + clouds_checkerboard_offsets[frameCounter % checkerboard_area];

	vec2 new_uv = vec2(checkerboard_pos) / vec2(view_res) * rcp(float(taau_render_scale));

	// Get maximum depth from area covered by this fragment
	float depth_max = depth_max_4x4(depthtex1);

	vec3 screen_pos = vec3(new_uv, depth_max);
	vec3 view_pos = screen_to_view_space(screen_pos, false);

	// Distant Horizons support
#ifdef DISTANT_HORIZONS
	float depth_dh = depth_max_4x4(dhDepthTex);
	bool is_dh_terrain = is_distant_horizons_terrain(depth_max, depth_dh);

	if (is_dh_terrain) {
		screen_pos = vec3(new_uv, depth_dh);
		view_pos = screen_to_view_space(screen_pos, false, true);
	}
#else
	const bool is_dh_terrain = false;
#endif

	vec3 ray_origin = vec3(0.0, CLOUDS_SCALE * (eyeAltitude - SEA_LEVEL) + planet_radius, 0.0) + CLOUDS_SCALE * gbufferModelViewInverse[3].xyz;
	vec3 ray_dir    = mat3(gbufferModelViewInverse) * normalize(view_pos);

	float distance_to_terrain = (depth_max == 1.0 && !is_dh_terrain)
		? -1.0
		: length(view_pos) * CLOUDS_SCALE;

	vec3 clear_sky = atmosphere_scattering(ray_dir, sun_color, sun_dir, moon_color, moon_dir, /* use_klein_nishina_phase */ false);

	float dither = texelFetch(noisetex, ivec2(checkerboard_pos & 511), 0).b;
	      dither = r1(frameCounter / checkerboard_area, dither);

#ifndef BLOCKY_CLOUDS
	CloudsResult result = draw_clouds(
		ray_origin,
		ray_dir,
		clear_sky,
		distance_to_terrain,
		dither
	);

	clouds.xyz    = result.scattering.xyz;
	clouds.w      = result.transmittance;
	clouds_data.x = result.apparent_distance * rcp(CLOUDS_SCALE);
	clouds_data.y = result.scattering.w;
#else
	clouds        = vec4(0.0, 0.0, 0.0, 1.0);
	clouds_data.x = 1e6;
	clouds_data.y = 0.0;
#endif

	// Crepuscular rays 

#if defined CREPUSCULAR_RAYS && !defined BLOCKY_CLOUDS
	vec4 crepuscular_rays = draw_crepuscular_rays(
		colortex8, 
		ray_dir, 
		distance_to_terrain > 0.0,
		dither
	);
	clouds *= crepuscular_rays.w;
	clouds.rgb += crepuscular_rays.xyz;
#endif

	// Aurora

	clouds.xyz += draw_aurora(ray_dir, dither) * clouds.w;
#endif
}

