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

flat in vec3 weather;
flat in vec3 cloudsDirectIrradiance;

flat in vec3 ambientIrradiance;
flat in vec3 directIrradiance;
flat in vec3 skyIrradiance;

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

uniform int worldDay;
uniform int worldTime;
uniform int moonPhase;

uniform int frameCounter;

uniform float frameTimeCounter;

uniform float sunAngle;

uniform float rainStrength;
uniform float wetness;

//--// Custom uniforms

uniform bool cloudsMoonlit;

uniform float worldAge;

uniform float biomeCave;
uniform float biomeTemperature;
uniform float biomeHumidity;
uniform float biomeMayRain;

uniform float timeSunset;
uniform float timeNoon;
uniform float timeSunrise;
uniform float timeMidight;

uniform float lightningFlash;
uniform float moonPhaseBrightness;

uniform vec3 lightDir;
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
		}
	} else {
		vec3 rayDir = unprojectSky(coord);

		/* -- atmosphere -- */

		vec3 atmosphereScattering = sunIrradiance * getAtmosphereScattering(rayDir, sunDir)
		                          + moonIrradiance * getAtmosphereScattering(rayDir, moonDir) * moonPhaseBrightness;

		vec3 atmosphereTransmittance = getAtmosphereTransmittance(rayDir.y, planetRadius);

		radiance = radiance * atmosphereTransmittance + atmosphereScattering;

		/* -- clouds -- */

		vec3 rayOrigin = vec3(0.0, CLOUDS_SCALE * (eyeAltitude - SEA_LEVEL) + planetRadius, 0.0) + CLOUDS_SCALE;

		vec3 cloudsLightDir = cloudsMoonlit ? moonDir : sunDir;

		vec4 cloudData = renderClouds(rayOrigin, rayDir, cloudsLightDir, 0.5, -1.0, true);

		const vec3 cloudsLightningFlash = vec3(20.0);

		vec3 cloudsScattering = mat2x3(cloudsDirectIrradiance, skyIrradiance + cloudsLightningFlash * lightningFlash) * cloudData.xy;
		     cloudsScattering = cloudsAerialPerspective(cloudsScattering, cloudData.rgb, rayDir, atmosphereScattering, cloudData.w);

		#define cloudsTransmittance cloudData.z

		radiance = radiance * cloudsTransmittance + cloudsScattering;
	}
}
