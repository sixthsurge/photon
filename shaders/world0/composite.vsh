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

flat out vec3 lightCol;
flat out vec3 skyCol;
flat out mat2x3 fogCoeff[2];

uniform sampler2D depthtex2; // Atmospheric sun color LUT

uniform float sunAngle;

uniform int worldTime;

uniform float rainStrength;

uniform vec3 lightDir;
uniform vec3 sunDir;
uniform vec3 moonDir;

uniform float biomeTemperate;
uniform float biomeArid;
uniform float biomeSnowy;
uniform float biomeTaiga;
uniform float biomeJungle;
uniform float biomeSwamp;
uniform float biomeMayRain;
uniform float biomeTemperature;
uniform float biomeHumidity;

uniform float timeSunrise;
uniform float timeNoon;
uniform float timeSunset;
uniform float timeMidnight;

#define ATMOSPHERE_SUN_COLOR_LUT depthtex2
#define WORLD_OVERWORLD
#include "/include/palette.glsl"
#include "/include/weather.glsl"

void main() {
	uv = gl_MultiTexCoord0.xy;

	lightCol = getLightColor();
	skyCol = getSkyColor();

	mat2x3 rayleighCoeff = fogRayleighCoeff(), mieCoeff = fogMieCoeff();
	fogCoeff[0] = mat2x3(rayleighCoeff[0], mieCoeff[0]);
	fogCoeff[1] = mat2x3(rayleighCoeff[1], mieCoeff[1]);

	vec2 vertexPos = gl_Vertex.xy * FOG_RENDER_SCALE;
	gl_Position = vec4(vertexPos * 2.0 - 1.0, 0.0, 1.0);
}
