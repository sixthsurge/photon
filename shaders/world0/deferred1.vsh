#version 400 compatibility

/*
--------------------------------------------------------------------------------

  Photon Shaders by SixthSurge

  world0/deferred1.vsh:
  Get lighting colors for clouds

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

out vec2 uv;

flat out vec3 base_light_color;
flat out vec3 sky_color;
flat out vec3 sun_color;
flat out vec3 moon_color;

flat out vec2 clouds_coverage_cu;
flat out vec2 clouds_coverage_ac;
flat out vec2 clouds_coverage_cc;
flat out vec2 clouds_coverage_ci;

uniform sampler3D depthtex0; // Atmospheric scattering LUT

uniform float sunAngle;

uniform int worldTime;

uniform float rainStrength;

uniform vec3 light_dir;
uniform vec3 sun_dir;
uniform vec3 moon_dir;

uniform float time_sunrise;
uniform float time_noon;
uniform float time_sunset;
uniform float time_midnight;

uniform float biome_temperate;
uniform float biome_arid;
uniform float biome_snowy;
uniform float biome_taiga;
uniform float biome_jungle;
uniform float biome_swamp;
uniform float biome_may_rain;
uniform float biome_temperature;
uniform float biome_humidity;

uniform bool clouds_moonlit;

#define ATMOSPHERE_SCATTERING_LUT depthtex0
#define WORLD_OVERWORLD

#include "/include/atmosphere.glsl"
#include "/include/weather.glsl"
#include "/include/palette.glsl"

void main() {
	uv = gl_MultiTexCoord0.xy;

	clouds_coverage_cu = vec2(0.4, 0.6);

	sun_color = get_sunlight_scale() * get_sunlight_tint();
	moon_color = get_moonlight_scale() * get_moonlight_tint();
	base_light_color = mix(sun_color, moon_color, float(clouds_moonlit)) * (1.0 - rainStrength);

	const vec3 sky_dir = normalize(vec3(0.0, 1.0, -0.8)); // don't point direcly upwards to avoid the sun halo when the sun path rotation is 0
	sky_color = atmosphere_scattering(sky_dir, sun_dir) * sun_color + atmosphere_scattering(sky_dir, moon_dir) * moon_color;
	sky_color = tau * mix(sky_color, vec3(sky_color.b) * sqrt(2.0), rcp_pi);
	sky_color = mix(sky_color, tau * get_rain_color(), rainStrength);

	vec2 vertex_pos = gl_Vertex.xy * taau_render_scale * rcp(float(CLOUDS_TEMPORAL_UPSCALING));
	gl_Position = vec4(vertex_pos * 2.0 - 1.0, 0.0, 1.0);
}
