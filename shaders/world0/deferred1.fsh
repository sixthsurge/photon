#version 400 compatibility

/*
--------------------------------------------------------------------------------

  Photon Shaders by SixthSurge

  world0/deferred1.fsh:
  Render clouds

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

/* DRAWBUFFERS:5 */
layout (location = 0) out vec4 clouds;

in vec2 uv;

flat in vec3 base_light_color;
flat in vec3 sky_color;
flat in vec3 sun_color;
flat in vec3 moon_color;

flat in vec2 clouds_coverage_cu;
flat in vec2 clouds_coverage_ac;
flat in vec2 clouds_coverage_cc;
flat in vec2 clouds_coverage_ci;

uniform sampler2D depthtex1;

uniform sampler2D noisetex;

uniform sampler3D depthtex0; // atmospheric scattering LUT

uniform sampler3D colortex6; // 3D worley noise
uniform sampler3D colortex7; // 3D curl noise

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;

uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;

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

uniform vec3 sun_dir;
uniform vec3 moon_dir;

uniform vec2 view_res;
uniform vec2 view_pixel_size;
uniform vec2 taa_offset;

uniform float world_age;

uniform float biome_cave;

uniform float time_sunrise;
uniform float time_sunset;

uniform vec3 clouds_light_dir;

#define ATMOSPHERE_SCATTERING_LUT depthtex0
#define MIE_PHASE_CLAMP

#include "/include/utility/checkerboard.glsl"
#include "/include/utility/random.glsl"
#include "/include/utility/space_conversion.glsl"

#include "/include/atmosphere.glsl"
#include "/include/clouds.glsl"

#if   CLOUDS_TEMPORAL_UPSCALING == 1
	#define checkerboard_offsets ivec2[1](ivec2(0))
#elif CLOUDS_TEMPORAL_USPCALING == 2
	#define checkerboard_offsets checkerboard_offsets_2x2
#elif CLOUDS_TEMPORAL_UPSCALING == 3
	#define checkerboard_offsets checkerboard_offsets_3x3
#elif CLOUDS_TEMPORAL_UPSCALING == 4
	#define checkerboard_offsets checkerboard_offsets_4x4
#endif

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
	ivec2 checkerboard_pos = CLOUDS_TEMPORAL_UPSCALING * texel + checkerboard_offsets[frameCounter % checkerboard_area];

	vec2 new_uv = vec2(checkerboard_pos) / vec2(view_res) * rcp(float(taau_render_scale));

	// Skip rendering clouds if they are occluded by terrain
	float depth_max = depth_max_4x4(depthtex1);
	if (depth_max < 1.0) { clouds = vec4(0.0, 0.0, 0.0, 1.0); return; }

	vec3 view_pos = screen_to_view_space(vec3(new_uv, 1.0), false);
	vec3 ray_dir = mat3(gbufferModelViewInverse) * normalize(view_pos);

	vec3 clear_sky = atmosphere_scattering(ray_dir, sun_dir) * sun_color
	               + atmosphere_scattering(ray_dir, moon_dir) * moon_color;

	float dither = texelFetch(noisetex, ivec2(checkerboard_pos & 511), 0).b;
	      dither = r1(frameCounter / checkerboard_area, dither);

	clouds = draw_clouds_cu(ray_dir, clear_sky, dither);
}
