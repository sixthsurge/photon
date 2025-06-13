/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  world0/prepare.vsh:
  Create cloud base coverage map and cloud shadow map

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

out vec2 uv;

#include "/include/sky/clouds/parameters.glsl"
flat out CloudsParameters clouds_params;

#ifndef IS_IRIS
flat out vec3 sun_dir_fixed;
flat out vec3 moon_dir_fixed;
flat out vec3 light_dir_fixed;
#endif

// ------------
//   Uniforms
// ------------

uniform int worldTime;
uniform int worldDay;

uniform float rainStrength;
uniform float wetness;
uniform float sunAngle;

uniform int frameCounter;
uniform float frameTimeCounter;

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


#include "/include/weather/clouds.glsl"

#ifndef IS_IRIS
// `sunPosition` fix by Builderb0y 
vec3 calculate_sun_direction() {
	const vec2 sun_rotation_data = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));

	float ang = fract(worldTime / 24000.0 - 0.25);
	ang = (ang + (cos(ang * 3.14159265358979) * -0.5 + 0.5 - ang) / 3.0) * 6.28318530717959; //0-2pi, rolls over from 2pi to 0 at noon.

	return normalize(vec3(-sin(ang), cos(ang) * sun_rotation_data));
}
#endif

void main() {
	uv = gl_MultiTexCoord0.xy;

	Weather weather = get_weather();
	clouds_params = get_clouds_parameters(weather);

#ifndef IS_IRIS
	sun_dir_fixed = calculate_sun_direction();
	moon_dir_fixed = -sun_dir_fixed;
	light_dir_fixed = sunAngle < 0.5 ? sun_dir_fixed : moon_dir_fixed;
#endif

	gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 0.0, 1.0);
}

#ifndef CLOUD_SHADOWS
#error "This program should be disabled if Cloud Shadows are disabled"
#endif
