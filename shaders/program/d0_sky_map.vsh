/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/d0_sky_map:
  Render omnidirectional sky map for reflections and SH lighting

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

out vec2 uv;

flat out vec3 ambient_color;
flat out vec3 light_color;

#if defined WORLD_OVERWORLD
flat out vec3 sun_color;
flat out vec3 moon_color;
flat out vec3 sky_color;

#include "/include/misc/weather_struct.glsl"
flat out DailyWeatherVariation daily_weather_variation;
#endif

// ------------
//   Uniforms
// ------------

uniform sampler3D depthtex0; // atmospheric scattering LUT

uniform float blindness;
uniform float eyeAltitude;
uniform float rainStrength;
uniform float wetness;

uniform int worldTime;
uniform int worldDay;
uniform float sunAngle;

uniform int frameCounter;
uniform float frameTimeCounter;

uniform int isEyeInWater;

uniform vec3 fogColor;

uniform vec3 light_dir;
uniform vec3 sun_dir;
uniform vec3 moon_dir;

uniform float world_age;
uniform float eye_skylight;

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
#include "/include/lighting/colors/light_color.glsl"
#include "/include/lighting/colors/weather_color.glsl"
#include "/include/misc/weather.glsl"
#endif

#if defined WORLD_NETHER
#include "/include/lighting/colors/nether_color.glsl"
#endif

#if defined WORLD_END
#include "/include/lighting/colors/end_color.glsl"
#endif

#if defined WORLD_OVERWORLD
vec3 get_ambient_color() {
	sun_color  = get_sun_exposure() * get_sun_tint();
	moon_color = get_moon_exposure() * get_moon_tint();

	const vec3 sky_dir = normalize(vec3(0.0, 1.0, -0.8)); // don't point direcly upwards to avoid the sun halo when the sun path rotation is 0
	sky_color = atmosphere_scattering(sky_dir, sun_color, sun_dir, moon_color, moon_dir, false);
	sky_color = tau * sky_color * 1.13;
	sky_color = mix(sky_color, tau * get_weather_color(), rainStrength);

	return sky_color;
}
#endif

void main() {
	uv = gl_MultiTexCoord0.xy;

	light_color   = get_light_color();
	ambient_color = get_ambient_color();

#if defined WORLD_OVERWORLD
	daily_weather_variation = get_daily_weather_variation();

	sky_color += daily_weather_variation.aurora_amount * AURORA_CLOUD_LIGHTING * mix(
		daily_weather_variation.aurora_colors[0], 
		daily_weather_variation.aurora_colors[1], 
		0.25
	);
#endif

	gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 0.0, 1.0);
}

