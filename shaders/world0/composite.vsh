#version 400 compatibility

/*
--------------------------------------------------------------------------------

  Photon Shaders by SixthSurge

  world0/composite.vsh:
  Calculate lighting colors and fog coefficients

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

out vec2 uv;

flat out vec3 light_color;
flat out vec3 sky_color;
flat out mat2x3 air_fog_coeff[2];

uniform float sunAngle;

uniform int worldTime;

uniform float rainStrength;

uniform vec3 light_dir;
uniform vec3 sun_dir;
uniform vec3 moon_dir;

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

#define WORLD_OVERWORLD
#include "/include/palette.glsl"
#include "/include/weather.glsl"

void main() {
	uv = gl_MultiTexCoord0.xy;

	light_color    = get_light_color();
	sky_color = get_sky_color();

	mat2x3 rayleigh_coeff = air_fog_rayleigh_coeff(), mie_coeff = air_fog_mie_coeff();
	air_fog_coeff[0] = mat2x3(rayleigh_coeff[0], mie_coeff[0]);
	air_fog_coeff[1] = mat2x3(rayleigh_coeff[1], mie_coeff[1]);

	vec2 vertex_pos = gl_Vertex.xy * VL_RENDER_SCALE;
	gl_Position = vec4(vertex_pos * 2.0 - 1.0, 0.0, 1.0);
}
