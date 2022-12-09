#version 400 compatibility

#include "/include/global.glsl"

out vec2 uv;

flat out vec3 sunColor;
flat out vec3 moonColor;

uniform float sunAngle;

uniform int worldTime;

uniform float rainStrength;

uniform vec3 lightDir;
uniform vec3 sunDir;
uniform vec3 moonDir;

uniform float timeSunrise;
uniform float timeNoon;
uniform float timeSunset;
uniform float timeMidnight;

#define WORLD_OVERWORLD
#include "/include/palette.glsl"

void main() {
	uv = gl_MultiTexCoord0.xy;

	sunColor = getSunBrightness() * getSunTint();
	moonColor = getMoonBrightness() * getMoonTint();

	gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 0.0, 1.0);
}
