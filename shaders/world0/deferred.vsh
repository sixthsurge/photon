#version 410 compatibility

/*
 * Program description:
 * Calculate lighting color palette and dynamic weather properties
 */

#include "/include/global.glsl"

//--// Outputs //-------------------------------------------------------------//

out vec2 coord;

flat out vec3 cloudsDirectIrradiance;

flat out vec3 ambientIrradiance;
flat out vec3 directIrradiance;
flat out vec3 skyIrradiance;

flat out float airRayleighDensity;
flat out float airMieDensity;
flat out float cloudsCirrusCoverage;
flat out float cloudsCumulusCoverage;

//--// Uniforms //------------------------------------------------------------//

uniform sampler3D colortex2; // Atmosphere scattering LUT

//--// Camera uniforms

uniform ivec2 eyeBrightnessSmooth;

//--// Time uniforms

uniform int worldDay;
uniform int worldTime;

uniform float wetness;

uniform float sunAngle;

//--// Custom uniforms

uniform bool cloudsMoonlit;

uniform float timeSunset;
uniform float timeNoon;
uniform float timeSunrise;
uniform float timeMidight;

uniform vec3 lightDir;
uniform vec3 sunDir;
uniform vec3 moonDir;

//--// Includes //------------------------------------------------------------//

#define WORLD_OVERWORLD

#define ATMOSPHERE_SCATTERING_LUT colortex2

#include "/include/atmospherics/palette.glsl"
#include "/include/atmospherics/weather.glsl"

//--// Functions //-----------------------------------------------------------//

void main() {
	coord = gl_MultiTexCoord0.xy;

	weatherSetup();
	paletteSetup();

	vec3 rayOrigin = vec3(0.0, planetRadius + CLOUDS_CUMULUS_ALTITUDE, 0.0);
	vec3 rayDir = cloudsMoonlit ? moonDir : sunDir;

	cloudsDirectIrradiance  = cloudsMoonlit ? moonIrradiance : sunIrradiance;
	cloudsDirectIrradiance *= getAtmosphereTransmittance(rayOrigin, rayDir);
	cloudsDirectIrradiance *= 1.0 - pulse(float(worldTime), 12850.0, 50.0) - pulse(float(worldTime), 23150.0, 50.0);

	gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 0.0, 1.0);
}
