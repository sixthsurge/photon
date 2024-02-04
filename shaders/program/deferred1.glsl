/*
--------------------------------------------------------------------------------

  Photon Shaders by SixthSurge

  program/deferred1.glsl:
  Render volumetric clouds

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"


//----------------------------------------------------------------------------//
#if defined vsh

out vec2 uv;

#if defined WORLD_OVERWORLD
flat out vec3 sun_color;
flat out vec3 moon_color;
flat out vec3 sky_color;

flat out vec2 clouds_cumulus_coverage;
flat out vec2 clouds_altocumulus_coverage;
flat out vec2 clouds_cirrus_coverage;

flat out float clouds_cumulus_congestus_amount;
flat out float clouds_cumulonimbus_amount;
flat out float clouds_stratus_amount;

flat out float aurora_amount;
flat out mat2x3 aurora_colors;

flat out float overcastness;
#endif

// ------------
//   Uniforms
// ------------

uniform sampler3D depthtex0; // atmospheric scattering LUT

uniform int worldTime;
uniform int worldDay;
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
#define WEATHER_AURORA
#define WEATHER_CLOUDS

#if defined WORLD_OVERWORLD
#include "/include/light/colors/light_color.glsl"
#include "/include/light/colors/weather_color.glsl"
#include "/include/misc/weather.glsl"
#include "/include/sky/atmosphere.glsl"
#endif

void main() {
	uv = gl_MultiTexCoord0.xy;

#if defined WORLD_OVERWORLD
	sun_color = get_sun_exposure() * get_sun_tint();
	moon_color = get_moon_exposure() * get_moon_tint();

	overcastness = daily_weather_blend(daily_weather_overcastness);

	const vec3 sky_dir = normalize(vec3(0.0, 1.0, -0.8)); // don't point direcly upwards to avoid the sun halo when the sun path rotation is 0
	sky_color = atmosphere_scattering(sky_dir, sun_dir) * sun_color + atmosphere_scattering(sky_dir, moon_dir) * moon_color;
	sky_color = tau * mix(sky_color, vec3(sky_color.b) * sqrt(2.0), rcp_pi);
	sky_color = mix(sky_color, tau * get_weather_color(), rainStrength);

	clouds_weather_variation(
		clouds_cumulus_coverage,
		clouds_altocumulus_coverage,
		clouds_cirrus_coverage,
		clouds_cumulus_congestus_amount,
		clouds_cumulonimbus_amount,
		clouds_stratus_amount
	);

	aurora_amount = get_aurora_amount();
	aurora_colors = get_aurora_colors();

	sky_color += aurora_amount * AURORA_CLOUD_LIGHTING * mix(aurora_colors[0], aurora_colors[1], 0.25) * mix(AURORA_BRIGHTNESS, AURORA_BRIGHTNESS_SNOW, biome_may_snow);
#endif

	vec2 vertex_pos = gl_Vertex.xy * taau_render_scale * rcp(float(CLOUDS_TEMPORAL_UPSCALING));
	gl_Position = vec4(vertex_pos * 2.0 - 1.0, 0.0, 1.0);
}

#endif
//----------------------------------------------------------------------------//



//----------------------------------------------------------------------------//
#if defined fsh

layout (location = 0) out vec4 clouds;

/* DRAWBUFFERS:5 */

in vec2 uv;

#if defined WORLD_OVERWORLD
flat in vec3 sun_color;
flat in vec3 moon_color;
flat in vec3 sky_color;

flat in vec2 clouds_cumulus_coverage;
flat in vec2 clouds_altocumulus_coverage;
flat in vec2 clouds_cirrus_coverage;

flat in float clouds_cumulus_congestus_amount;
flat in float clouds_cumulonimbus_amount;
flat in float clouds_stratus_amount;

flat in float aurora_amount;
flat in mat2x3 aurora_colors;

flat in float overcastness;
#endif

// ------------
//   Uniforms
// ------------

uniform sampler3D colortex6; // 3D worley noise
uniform sampler3D colortex7; // 3D curl noise

uniform sampler3D depthtex0; // atmospheric scattering LUT
uniform sampler2D depthtex1;

uniform sampler2D noisetex;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

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

#if defined WORLD_OVERWORLD
#include "/include/sky/atmosphere.glsl"
#include "/include/sky/aurora.glsl"
#include "/include/sky/clouds.glsl"
#endif

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

	// Skip rendering if occluded by terrain
	float depth_max = depth_max_4x4(depthtex1);
	if (depth_max < 1.0) { clouds = vec4(0.0, 0.0, 0.0, 1.0); return; }

	// Clouds

	vec3 view_pos = screen_to_view_space(vec3(new_uv, 1.0), false);
	vec3 ray_dir = mat3(gbufferModelViewInverse) * normalize(view_pos);

	vec3 clear_sky = atmosphere_scattering(ray_dir, sun_color, sun_dir, moon_color, moon_dir);
	     clear_sky = mix(clear_sky, 1.1 * vec3(dot(clear_sky, luminance_weights_rec2020)), 0.75 * overcastness * time_noon * linear_step(0.0, 0.05, ray_dir.y));

	float dither = texelFetch(noisetex, ivec2(checkerboard_pos & 511), 0).b;
	      dither = r1(frameCounter / checkerboard_area, dither);

#ifndef BLOCKY_CLOUDS
	clouds = draw_clouds(ray_dir, clear_sky, dither);
#endif

	// Aurora

	clouds.xyz += draw_aurora(ray_dir, dither) * clouds.w;
#endif
}

#endif
//----------------------------------------------------------------------------//
