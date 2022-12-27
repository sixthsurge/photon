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

uniform bool clouds_moonlit;

#define ATMOSPHERE_SCATTERING_LUT depthtex0
#define WORLD_OVERWORLD

#include "/include/atmosphere.glsl"
#include "/include/palette.glsl"

void main() {
	uv = gl_MultiTexCoord0.xy;

	sun_color = get_sunlight_scale() * get_sunlight_tint();
	moon_color = get_moonlight_scale() * get_moonlight_tint();
	base_light_color = mix(sun_color, moon_color, float(clouds_moonlit));

	const vec3 sky_dir = normalize(vec3(0.0, 1.0, -0.8)); // don't point direcly upwards to avoid the sun halo when the sun path rotation is 0
	sky_color = atmosphere_scattering(sky_dir, sun_dir) * sun_color + atmosphere_scattering(sky_dir, moon_dir) * moon_color;
	sky_color = tau * mix(sky_color, vec3(sky_color.b) * sqrt(2.0), rcp_pi);

	vec2 vertex_pos = gl_Vertex.xy * rcp(float(CLOUDS_TEMPORAL_UPSCALING));
	gl_Position = vec4(vertex_pos * 2.0 - 1.0, 0.0, 1.0);
}
