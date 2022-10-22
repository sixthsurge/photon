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

flat out vec3 lightCol;
flat out vec3 skyCol;

uniform float sunAngle;

uniform int worldTime;

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

	lightCol = getLightColor();
	skyCol = getSkyColor();

	vec2 vertexPos = gl_Vertex.xy * taauRenderScale;
	gl_Position = vec4(vertexPos * 2.0 - 1.0, 0.0, 1.0);
}
