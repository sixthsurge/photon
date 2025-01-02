/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/c0_vl:
  Calculate volumetric fog

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

out vec2 uv;

flat out vec3 ambient_color;
flat out vec3 light_color;

#if defined WORLD_OVERWORLD
flat out mat2x3 air_fog_coeff[2];
#endif

// ------------
//   Uniforms
// ------------

uniform sampler2D colortex4; // Sky map, lighting color palette

uniform float rainStrength;
uniform float sunAngle;

uniform int worldTime;
uniform int worldDay;

uniform vec3 sun_dir;

uniform float wetness;

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

uniform float desert_sandstorm;

#if defined WORLD_OVERWORLD
// Overworld fog coefficients

#include "/include/misc/weather.glsl"

mat2x3 air_fog_rayleigh_coeff() {
	const vec3 rayleigh_normal = from_srgb(vec3(AIR_FOG_RAYLEIGH_R,        AIR_FOG_RAYLEIGH_G,        AIR_FOG_RAYLEIGH_B       )) * AIR_FOG_RAYLEIGH_DENSITY;
	const vec3 rayleigh_rain   = from_srgb(vec3(AIR_FOG_RAYLEIGH_R_RAIN,   AIR_FOG_RAYLEIGH_G_RAIN,   AIR_FOG_RAYLEIGH_B_RAIN  )) * AIR_FOG_RAYLEIGH_DENSITY_RAIN;
	const vec3 rayleigh_arid   = from_srgb(vec3(AIR_FOG_RAYLEIGH_R_ARID,   AIR_FOG_RAYLEIGH_G_ARID,   AIR_FOG_RAYLEIGH_B_ARID  )) * AIR_FOG_RAYLEIGH_DENSITY_ARID;
	const vec3 rayleigh_snowy  = from_srgb(vec3(AIR_FOG_RAYLEIGH_R_SNOWY,  AIR_FOG_RAYLEIGH_G_SNOWY,  AIR_FOG_RAYLEIGH_B_SNOWY )) * AIR_FOG_RAYLEIGH_DENSITY_SNOWY;
	const vec3 rayleigh_taiga  = from_srgb(vec3(AIR_FOG_RAYLEIGH_R_TAIGA,  AIR_FOG_RAYLEIGH_G_TAIGA,  AIR_FOG_RAYLEIGH_B_TAIGA )) * AIR_FOG_RAYLEIGH_DENSITY_TAIGA;
	const vec3 rayleigh_jungle = from_srgb(vec3(AIR_FOG_RAYLEIGH_R_JUNGLE, AIR_FOG_RAYLEIGH_G_JUNGLE, AIR_FOG_RAYLEIGH_B_JUNGLE)) * AIR_FOG_RAYLEIGH_DENSITY_JUNGLE;
	const vec3 rayleigh_swamp  = from_srgb(vec3(AIR_FOG_RAYLEIGH_R_SWAMP,  AIR_FOG_RAYLEIGH_G_SWAMP,  AIR_FOG_RAYLEIGH_B_SWAMP )) * AIR_FOG_RAYLEIGH_DENSITY_SWAMP;

	vec3 rayleigh = rayleigh_normal * biome_temperate
	              + rayleigh_arid   * biome_arid
	              + rayleigh_snowy  * biome_snowy
		          + rayleigh_taiga  * biome_taiga
		          + rayleigh_jungle * biome_jungle
		          + rayleigh_swamp  * biome_swamp;

	// Rain
	rayleigh = mix(rayleigh, rayleigh_rain, rainStrength * biome_may_rain);

	// Daily weather
	float fogginess = daily_weather_blend(daily_weather_fogginess);
	rayleigh *= 1.0 + 2.0 * fogginess;

	return mat2x3(rayleigh, rayleigh);
}

mat2x3 air_fog_mie_coeff() {
	// Increased mie density and scattering strength during late sunset / blue hour
	float blue_hour = linear_step(0.05, 1.0, exp(-190.0 * sqr(sun_dir.y + 0.07283)));

	float mie_coeff = AIR_FOG_MIE_DENSITY_MORNING  * time_sunrise
	                + AIR_FOG_MIE_DENSITY_NOON     * time_noon
	                + AIR_FOG_MIE_DENSITY_EVENING  * time_sunset
	                + AIR_FOG_MIE_DENSITY_MIDNIGHT * time_midnight
	                + AIR_FOG_MIE_DENSITY_BLUE_HOUR * blue_hour;

	mie_coeff = mix(mie_coeff, AIR_FOG_MIE_DENSITY_RAIN, rainStrength * biome_may_rain);
	mie_coeff = mix(mie_coeff, AIR_FOG_MIE_DENSITY_SNOW, rainStrength * biome_may_snow);

	float mie_albedo = mix(0.9, 0.5, rainStrength * biome_may_rain);

	vec3 extinction_coeff = vec3(mie_coeff);
	vec3 scattering_coeff = vec3(mie_coeff * mie_albedo);

#ifdef DESERT_SANDSTORM
	const float desert_sandstorm_density    = 0.2;
	const float desert_sandstorm_scattering = 0.5;
	const vec3  desert_sandstorm_extinction = vec3(0.2, 0.27, 0.45);

	scattering_coeff += desert_sandstorm * (desert_sandstorm_density * desert_sandstorm_scattering);
	extinction_coeff += desert_sandstorm * (desert_sandstorm_density * desert_sandstorm_extinction);
#endif

	return mat2x3(scattering_coeff, extinction_coeff);
}
#endif

void main() {
	uv = gl_MultiTexCoord0.xy;

	light_color   = texelFetch(colortex4, ivec2(191, 0), 0).rgb;
	ambient_color = texelFetch(colortex4, ivec2(191, 1), 0).rgb;

#if defined WORLD_OVERWORLD
	mat2x3 rayleigh_coeff = air_fog_rayleigh_coeff(), mie_coeff = air_fog_mie_coeff();
	air_fog_coeff[0] = mat2x3(rayleigh_coeff[0], mie_coeff[0]);
	air_fog_coeff[1] = mat2x3(rayleigh_coeff[1], mie_coeff[1]);
#endif

	vec2 vertex_pos = gl_Vertex.xy;
	gl_Position = vec4(vertex_pos * 2.0 - 1.0, 0.0, 1.0);
}

