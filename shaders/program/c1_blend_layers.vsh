/*c1.v
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/c1_blend_layers
  Apply volumetric fog

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

out vec2 uv;

flat out vec3 ambient_color;
flat out vec3 light_color;

#if defined WORLD_OVERWORLD
#include "/include/fog/overworld/parameters.glsl"
flat out OverworldFogParameters fog_params;

flat out float rainbow_amount;
#endif

// ------------
//   Uniforms
// ------------

uniform sampler2D colortex4; // Sky map, lighting color palette
uniform sampler2D colortex9; // Sky SH

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

uniform float world_age;
uniform float time_sunrise;
uniform float time_noon;
uniform float time_sunset;
uniform float time_midnight;

uniform float desert_sandstorm;

#if defined WORLD_OVERWORLD
#include "/include/misc/weather.glsl"
#endif

void main() {
	uv = gl_MultiTexCoord0.xy;

	light_color   = texelFetch(colortex4, ivec2(191, 0), 0).rgb;
#if defined WORLD_OVERWORLD && defined SH_SKYLIGHT
	ambient_color = texelFetch(colortex9, ivec2(9, 0), 0).rgb;
#else
	ambient_color = texelFetch(colortex4, ivec2(191, 1), 0).rgb;
#endif

	Weather weather = get_weather();

#if defined WORLD_OVERWORLD
	fog_params = get_fog_parameters(weather);
	rainbow_amount = get_rainbow_amount(weather);
#endif

	vec2 vertex_pos = gl_Vertex.xy * taau_render_scale;
	gl_Position = vec4(vertex_pos * 2.0 - 1.0, 0.0, 1.0);
}
