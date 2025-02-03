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
#endif

// ------------
//   Uniforms
// ------------

uniform sampler3D depthtex0; // Atmosphere scattering LUT

uniform sampler2D colortex4; // Sky map, lighting colors
uniform sampler2D colortex9; // Skylight SH

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
#include "/include/misc/weather.glsl"
#include "/include/sky/atmosphere.glsl"
#include "/include/sky/projection.glsl"
#endif

#include "/include/utility/random.glsl"
#include "/include/utility/sampling.glsl"
#include "/include/utility/spherical_harmonics.glsl"

void main() {
	uv = gl_MultiTexCoord0.xy;

	light_color   = texelFetch(colortex4, ivec2(191, 0), 0).rgb;
	ambient_color = texelFetch(colortex4, ivec2(191, 1), 0).rgb;

#if defined WORLD_OVERWORLD
	sun_color = get_sun_exposure() * get_sun_tint();
	moon_color = get_moon_exposure() * get_moon_tint();
	fog_params = get_fog_parameters(get_weather());

	#ifdef SH_SKYLIGHT
	// Sample sky SH
	sky_sh[0]   = texelFetch(colortex9, ivec2(0, 0), 0).rgb;
	sky_sh[1]   = texelFetch(colortex9, ivec2(1, 0), 0).rgb;
	sky_sh[2]   = texelFetch(colortex9, ivec2(2, 0), 0).rgb;
	sky_sh[3]   = texelFetch(colortex9, ivec2(3, 0), 0).rgb;
	sky_sh[4]   = texelFetch(colortex9, ivec2(4, 0), 0).rgb;
	sky_sh[5]   = texelFetch(colortex9, ivec2(5, 0), 0).rgb;
	sky_sh[6]   = texelFetch(colortex9, ivec2(6, 0), 0).rgb;
	sky_sh[7]   = texelFetch(colortex9, ivec2(7, 0), 0).rgb;
	sky_sh[8]   = texelFetch(colortex9, ivec2(8, 0), 0).rgb;
	skylight_up = texelFetch(colortex9, ivec2(9, 0), 0).rgb;
	#endif
#endif

	vec2 vertex_pos = gl_Vertex.xy * taau_render_scale;
	gl_Position = vec4(vertex_pos * 2.0 - 1.0, 0.0, 1.0);
}
