#version 410 compatibility
#include "/include/global.glsl"

//--// Outputs //-------------------------------------------------------------//

out vec2 coord;

flat out vec3 directIrradiance;
flat out vec3 skyIrradiance;

flat out float airMieTurbidity;

//--// Uniforms //------------------------------------------------------------//

uniform sampler2D colortex4; // Sky capture, lighting color palette,

uniform int worldTime;

//--// Custom uniforms

uniform bool cloudsMoonlit;

uniform vec3 sunDir;
uniform vec3 moonDir;

//--// Includes //------------------------------------------------------------//

#include "/include/atmospherics/atmosphere.glsl"

//--// Functions //-----------------------------------------------------------//

void main() {
	coord = gl_MultiTexCoord0.xy;

	airMieTurbidity = texelFetch(colortex4, ivec2(255, 3), 0).x;
	skyIrradiance   = texelFetch(colortex4, ivec2(255, 2), 0).rgb;

	vec3 rayOrigin = vec3(0.0, planetRadius + CLOUDS_CUMULUS_ALTITUDE, 0.0);
	vec3 rayDir = cloudsMoonlit ? moonDir : sunDir;

	directIrradiance  = cloudsMoonlit ? moonIrradiance : sunIrradiance;
	directIrradiance *= getAtmosphereTransmittance(rayOrigin, rayDir, airMieTurbidity);
	directIrradiance *= 1.0 - pulse(float(worldTime), 12850.0, 50.0) - pulse(float(worldTime), 23150.0, 50.0);

	gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 0.0, 1.0);
}
