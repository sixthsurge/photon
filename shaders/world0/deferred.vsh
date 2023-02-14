#version 400 compatibility

#include "/include/global.glsl"

out vec2 uv;

flat out vec3 sun_color;
flat out vec3 moon_color;

uniform float sunAngle;

uniform int worldTime;

uniform float rainStrength;
uniform float biome_may_snow;

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

	sun_color = get_sunlight_scale() * get_sunlight_tint();
	moon_color = get_moonlight_scale() * get_moonlight_tint();

	gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 0.0, 1.0);
}
