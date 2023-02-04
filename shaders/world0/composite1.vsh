#version 400 compatibility

/*
--------------------------------------------------------------------------------

  Photon Shaders by SixthSurge

  world0/composite1.vsh:
  Calculate lighting colors and fog coefficients

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

out vec2 uv;

flat out vec3 light_color;
flat out vec3 sun_color;
flat out vec3 moon_color;
flat out mat3 sky_samples;

uniform float sunAngle;
uniform float rainStrength;

uniform int worldTime;

uniform vec3 light_dir;
uniform vec3 sun_dir;
uniform vec3 moon_dir;

uniform float time_sunrise;
uniform float time_noon;
uniform float time_sunset;
uniform float time_midnight;

#define WORLD_OVERWORLD
#include "/include/palette.glsl"

void main() {
	uv = gl_MultiTexCoord0.xy;

	light_color = get_light_color();

	sun_color = get_sunlight_scale() * get_sunlight_tint();
	moon_color = get_moonlight_scale() * get_moonlight_tint();

	sky_samples[0] = get_sky_color();
	sky_samples[1] = sky_samples[0];
	sky_samples[2] = sky_samples[0];

	vec2 vertex_pos = gl_Vertex.xy * taau_render_scale;
	gl_Position = vec4(vertex_pos * 2.0 - 1.0, 0.0, 1.0);
}
