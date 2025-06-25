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

flat out float aurora_amount;
flat out mat2x3 aurora_colors;

flat out float rainbow_amount;

#include "/include/sky/clouds/parameters.glsl"
flat out CloudsParameters clouds_params;

#include "/include/fog/overworld/parameters.glsl"
flat out OverworldFogParameters fog_params;
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

uniform float desert_sandstorm;

// ------------
//   Includes
// ------------

#define ATMOSPHERE_SCATTERING_LUT depthtex0

#if defined WORLD_OVERWORLD
#include "/include/sky/aurora_colors.glsl"
#include "/include/lighting/colors/light_color.glsl"
#include "/include/lighting/colors/weather_color.glsl"
#include "/include/weather/clouds.glsl"
#include "/include/weather/fog.glsl"
#include "/include/weather/rainbow.glsl"
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

	light_color = get_light_color();
	ambient_color = get_ambient_color();

#if defined WORLD_OVERWORLD
	aurora_amount = get_aurora_amount();
	aurora_colors = get_aurora_colors();

	Weather weather = get_weather();
	rainbow_amount = get_rainbow_amount(weather);
	clouds_params = get_clouds_parameters(weather);
	fog_params = get_fog_parameters(weather);

	// Aurora clouds influence
	vec3 aurora_lighting = mix(
		aurora_colors[0], 
		aurora_colors[1], 
		0.25
	) * aurora_amount;
	sky_color += AURORA_CLOUD_LIGHTING * aurora_lighting;
	ambient_color += AURORA_CLOUD_LIGHTING * aurora_lighting;
#endif

	gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 0.0, 1.0);
}

