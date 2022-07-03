#version 410 compatibility

/*
 * Program description:
 * Render sky from all directions into 256x128 sky capture for reflections, SSPT and SH skylight
 * Store lighting color palette and dynamic weather properties
 */

#include "/include/global.glsl"

//--// Outputs //-------------------------------------------------------------//

/* RENDERTARGETS: 4 */
layout (location = 0) out vec3 radiance;

//--// Inputs //--------------------------------------------------------------//

in vec2 coord;

flat in vec3 cloudsDirectIrradiance;

flat in vec3 ambientIrradiance;
flat in vec3 directIrradiance;
flat in vec3 skyIrradiance;

flat in float airMieTurbidity;
flat in float cloudsCirrusCoverage;
flat in float cloudsCumulusCoverage;

//--// Uniforms //------------------------------------------------------------//

uniform sampler2D noisetex;

uniform sampler3D colortex2; // Atmosphere scattering LUT

uniform sampler3D depthtex0; // 3D worley noise
uniform sampler3D depthtex2; // 3D curl noise

//--// Camera uniforms

uniform float eyeAltitude;

uniform vec3 cameraPosition;

//--// Shadow uniforms

uniform mat3 shadowModelView;

//--// Time uniforms

uniform int frameCounter;

uniform int moonPhase;

uniform float sunAngle;

uniform float rainStrength;

//--// Custom uniforms

uniform bool cloudsMoonlit;

uniform float worldAge;

uniform float biomeCave;

uniform float timeNoon;
uniform float moonPhaseBrightness;

uniform vec3 sunDir;
uniform vec3 moonDir;

//--// Includes //------------------------------------------------------------//

#define WORLD_OVERWORLD
#define PROGRAM_SKY_CAPTURE
#define ATMOSPHERE_SCATTERING_LUT colortex2

#include "/block.properties"
#include "/entity.properties"

#include "/include/atmospherics/atmosphere.glsl"
#include "/include/atmospherics/clouds.glsl"
#include "/include/atmospherics/sky.glsl"
#include "/include/atmospherics/skyProjection.glsl"

//--// Program //-------------------------------------------------------------//

void main() {
	ivec2 texel = ivec2(gl_FragCoord.xy);

	radiance = vec3(0.0);

	if (texel.x == skyCaptureRes.x) {
		switch (texel.y) {
		case 0:
			radiance = ambientIrradiance;
			break;

		case 1:
			radiance = directIrradiance;
			break;

		case 2:
			radiance = skyIrradiance;
			break;

		case 3:
			radiance = vec3(airMieTurbidity, cloudsCirrusCoverage, cloudsCumulusCoverage);
			break;
		}
	} else {
		vec3 rayDir = unprojectSky(coord);

		/* -- atmosphere -- */

		vec3 atmosphereScattering = sunIrradiance * getAtmosphereScattering(rayDir, sunDir)
		                          + moonIrradiance * getAtmosphereScattering(rayDir, moonDir) * moonPhaseBrightness;

		vec3 atmosphereTransmittance = getAtmosphereTransmittance(rayDir.y, planetRadius);

		radiance = radiance * atmosphereTransmittance + atmosphereScattering;

		/* -- clouds -- */

		Ray ray;
		ray.origin = vec3(0.0, CLOUDS_SCALE * (eyeAltitude - SEA_LEVEL) + planetRadius, 0.0) + CLOUDS_SCALE;
		ray.dir    = rayDir;

		vec3 cloudsLightDir = cloudsMoonlit ? moonDir : sunDir;

		vec4 cloudData = drawClouds(ray, cloudsLightDir, 0.5, -1.0, true);

		vec3 cloudsScattering = mat2x3(cloudsDirectIrradiance, skyIrradiance) * cloudData.xy;
		     cloudsScattering = getCloudsAerialPerspective(cloudsScattering, cloudData.rgb, rayDir, atmosphereScattering, cloudData.w);

		#define cloudsTransmittance cloudData.z

		radiance = radiance * cloudsTransmittance + cloudsScattering;
	}
}
