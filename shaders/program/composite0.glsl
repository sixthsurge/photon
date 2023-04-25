/*
--------------------------------------------------------------------------------

  Photon Shaders by SixthSurge

  program/composite0.glsl:
  Render volumetric fog

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"


//----------------------------------------------------------------------------//
#if defined vsh

out vec2 uv;

flat out vec3 ambient_color;
flat out vec3 light_color;

#if defined WORLD_OVERWORLD
flat out mat2x3 air_fog_coeff[2];
#endif

// ------------
//   Uniforms
// ------------

uniform float eyeAltitude;
uniform float blindness;
uniform float rainStrength;
uniform float sunAngle;
uniform float frameTimeCounter;

uniform int isEyeInWater;
uniform int worldTime;
uniform int worldDay;
uniform int frameCounter;

uniform vec3 fogColor;

uniform vec3 light_dir;
uniform vec3 sun_dir;
uniform vec3 moon_dir;

uniform float eye_skylight;

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

uniform float time_sunrise;
uniform float time_noon;
uniform float time_sunset;
uniform float time_midnight;

#define WEATHER_FOG

#if defined WORLD_OVERWORLD
#include "/include/light/colors/light_color.glsl"
#include "/include/light/colors/sky_color.glsl"
#include "/include/misc/weather.glsl"
#endif

#if defined WORLD_NETHER
#include "/include/light/colors/nether_color.glsl"
#endif

void main() {
	uv = gl_MultiTexCoord0.xy;

#if defined WORLD_OVERWORLD
	float overcastness = daily_weather_blend(daily_weather_overcastness);

	light_color = get_light_color(overcastness) * (1.0 - 0.33 * overcastness);
	ambient_color = get_sky_color();

	mat2x3 rayleigh_coeff = air_fog_rayleigh_coeff(), mie_coeff = air_fog_mie_coeff();
	air_fog_coeff[0] = mat2x3(rayleigh_coeff[0], mie_coeff[0]);
	air_fog_coeff[1] = mat2x3(rayleigh_coeff[1], mie_coeff[1]);
#endif

#if defined WORLD_NETHER
	light_color   = vec3(0.0);
	ambient_color = get_nether_color();
#endif

	vec2 vertex_pos = gl_Vertex.xy * VL_RENDER_SCALE;
	gl_Position = vec4(vertex_pos * 2.0 - 1.0, 0.0, 1.0);
}

#endif
//----------------------------------------------------------------------------//



//----------------------------------------------------------------------------//
#if defined fsh

layout (location = 0) out vec3 fog_scattering;
layout (location = 1) out vec3 fog_transmittance;

/* DRAWBUFFERS:67 */

in vec2 uv;

flat in vec3 ambient_color;
flat in vec3 light_color;

#if defined WORLD_OVERWORLD
flat in mat2x3 air_fog_coeff[2];
#endif

// ------------
//   Uniforms
// ------------

uniform sampler2D noisetex;

uniform sampler2D colortex1; // gbuffer data
uniform sampler3D colortex3; // 3D worley noise

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

#ifdef WORLD_OVERWORLD
#ifdef SHADOW
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
#ifdef SHADOW_COLOR
uniform sampler2D shadowcolor0;
#endif
#endif
#endif

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;

uniform vec3 cameraPosition;

uniform float near;
uniform float far;

uniform float blindness;
uniform float eyeAltitude;
uniform float rainStrength;
uniform float wetness;

uniform float sunAngle;
uniform float frameTimeCounter;

uniform int isEyeInWater;
uniform int worldTime;
uniform int frameCounter;

uniform vec3 light_dir;
uniform vec3 sun_dir;
uniform vec3 moon_dir;

uniform vec2 view_res;
uniform vec2 view_pixel_size;
uniform vec2 taa_offset;

uniform float eye_skylight;

uniform float time_sunrise;
uniform float time_noon;
uniform float time_sunset;
uniform float time_midnight;

// ------------
//   Includes
// ------------

#if defined WORLD_OVERWORLD
#include "/include/fog/air_fog_vl.glsl"
#endif

#include "/include/fog/water_fog_vl.glsl"

#include "/include/utility/encoding.glsl"
#include "/include/utility/random.glsl"
#include "/include/utility/space_conversion.glsl"

void main() {
	ivec2 fog_texel  = ivec2(gl_FragCoord.xy);
	ivec2 view_texel = ivec2(gl_FragCoord.xy * taau_render_scale * rcp(VL_RENDER_SCALE));

	float depth         = texelFetch(depthtex0, view_texel, 0).x;
	vec4 gbuffer_data_0 = texelFetch(colortex1, view_texel, 0);

	float skylight = unpack_unorm_2x8(gbuffer_data_0.w).y;

	vec3 view_pos  = screen_to_view_space(vec3(uv, depth), true);
	vec3 scene_pos = view_to_scene_space(view_pos);
	vec3 world_pos = scene_pos + cameraPosition;

	float dither = texelFetch(noisetex, fog_texel & 511, 0).b;
	      dither = r1(frameCounter, dither);

	vec3 world_start_pos = gbufferModelViewInverse[3].xyz + cameraPosition;
	vec3 world_end_pos   = world_pos;

	switch (isEyeInWater) {
#if defined WORLD_OVERWORLD
		case 0:
			mat2x3 air_fog = raymarch_air_fog(world_start_pos, world_end_pos, depth == 1.0, skylight, dither);

			fog_scattering    = air_fog[0];
			fog_transmittance = air_fog[1];

			break;
#endif

		case 1:
			mat2x3 water_fog = raymarch_water_fog(world_start_pos, world_end_pos, depth == 1.0, dither);

			fog_scattering    = water_fog[0];
			fog_transmittance = water_fog[1];

			break;

		default:
			fog_scattering    = vec3(0.0);
			fog_transmittance = vec3(1.0);

			break;

		// Prevent potential game crash due to empty switch statement
		case -1:
			break;
	}
}

#endif
//----------------------------------------------------------------------------//
