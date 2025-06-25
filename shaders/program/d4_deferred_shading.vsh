/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/d4_deferred_shading:
  Shade terrain and entities, draw sky

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

out vec2 uv;

flat out vec3 ambient_color;
flat out vec3 light_color;

#if defined WORLD_OVERWORLD
flat out vec3 sun_color;
flat out vec3 moon_color;

#include "/include/fog/overworld/parameters.glsl"
flat out OverworldFogParameters fog_params;

#if defined SH_SKYLIGHT
flat out vec3 sky_sh[9];
flat out vec3 skylight_up;
#endif

flat out float rainbow_amount;
#endif

// ------------
//   Uniforms
// ------------

uniform sampler3D depthtex0; // Atmosphere scattering LUT

uniform sampler2D colortex4; // Sky map, lighting colors, sky SH

uniform int worldTime;
uniform int worldDay;
uniform int moonPhase;
uniform float sunAngle;
uniform float rainStrength;
uniform float wetness;

uniform int frameCounter;
uniform float frameTimeCounter;

uniform int isEyeInWater;
uniform float blindness;
uniform float nightVision;
uniform float darknessFactor;

uniform vec3 light_dir;
uniform vec3 sun_dir;
uniform vec3 moon_dir;

uniform float biome_cave;
uniform float biome_may_rain;
uniform float biome_may_snow;
uniform float biome_snowy;
uniform float biome_temperate;
uniform float biome_arid;
uniform float biome_taiga;
uniform float biome_jungle;
uniform float biome_swamp;
uniform float biome_temperature;
uniform float biome_humidity;
uniform float desert_sandstorm;

uniform float world_age;
uniform float time_sunrise;
uniform float time_noon;
uniform float time_sunset;
uniform float time_midnight;

// ------------
//   Includes
// ------------

#define ATMOSPHERE_SCATTERING_LUT depthtex0
#define WEATHER_AURORA

#if defined WORLD_OVERWORLD
#include "/include/lighting/colors/light_color.glsl"
#include "/include/sky/atmosphere.glsl"
#include "/include/sky/projection.glsl"
#include "/include/weather/fog.glsl"
#include "/include/weather/rainbow.glsl"
#endif

#include "/include/utility/random.glsl"
#include "/include/utility/sampling.glsl"
#include "/include/utility/spherical_harmonics.glsl"

void main() {
	uv = gl_MultiTexCoord0.xy;

	light_color   = texelFetch(colortex4, ivec2(191, 0), 0).rgb;
	ambient_color = texelFetch(colortex4, ivec2(191, 1), 0).rgb;

#if defined WORLD_OVERWORLD
	Weather weather = get_weather();

	sun_color = get_sun_exposure() * get_sun_tint();
	moon_color = get_moon_exposure() * get_moon_tint();
	fog_params = get_fog_parameters(weather);

	#ifdef SH_SKYLIGHT
	// Sample sky SH
	sky_sh[0]   = texelFetch(colortex4, ivec2(191, 2), 0).rgb;
	sky_sh[1]   = texelFetch(colortex4, ivec2(191, 3), 0).rgb;
	sky_sh[2]   = texelFetch(colortex4, ivec2(191, 4), 0).rgb;
	sky_sh[3]   = texelFetch(colortex4, ivec2(191, 5), 0).rgb;
	sky_sh[4]   = texelFetch(colortex4, ivec2(191, 6), 0).rgb;
	sky_sh[5]   = texelFetch(colortex4, ivec2(191, 7), 0).rgb;
	sky_sh[6]   = texelFetch(colortex4, ivec2(191, 8), 0).rgb;
	sky_sh[7]   = texelFetch(colortex4, ivec2(191, 9), 0).rgb;
	sky_sh[8]   = texelFetch(colortex4, ivec2(191, 10), 0).rgb;
	skylight_up = texelFetch(colortex4, ivec2(191, 11), 0).rgb;
	#endif

	rainbow_amount = get_rainbow_amount(weather);
#endif

	vec2 vertex_pos = gl_Vertex.xy * taau_render_scale;
	gl_Position = vec4(vertex_pos * 2.0 - 1.0, 0.0, 1.0);
}
