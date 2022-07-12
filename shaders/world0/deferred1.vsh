#version 410 compatibility
#include "/include/global.glsl"

//--// Outputs //-------------------------------------------------------------//

out vec2 coord;

flat out vec3 weather;

//--// Uniforms //------------------------------------------------------------//

uniform sampler2D colortex4; // Sky capture, color palette and weather properties

//--// Camera uniforms

uniform vec3 cameraPosition;

//--// Time uniforms

uniform int worldDay;
uniform int worldTime;

uniform float frameTimeCounter;

uniform float wetness;
uniform float rainStrength;

uniform float biomeTemperature;
uniform float biomeHumidity;
uniform float biomeMayRain;

uniform float timeSunset;
uniform float timeNoon;
uniform float timeSunrise;
uniform float timeMidnight;

uniform vec3 lightDir;

//--// Includes //------------------------------------------------------------//

#include "/include/atmospherics/weather.glsl"

//--// Program //-------------------------------------------------------------//

void main() {
	coord = gl_MultiTexCoord0.xy;

	weather = getWeather();

	gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 0.0, 1.0);
}
