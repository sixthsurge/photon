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

flat in float airMieDensity;
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

//--// Time uniforms

uniform int frameCounter;

uniform float sunAngle;

uniform float rainStrength;

//--// Custom uniforms

uniform bool cloudsMoonlit;

uniform float worldAge;

uniform float biomeCave;

uniform vec3 sunDir;
uniform vec3 moonDir;

//--// Includes //------------------------------------------------------------//

#define WORLD_OVERWORLD
#define PROGRAM_SKY_CAPTURE

#define ATMOSPHERE_SCATTERING_LUT colortex2

#include "/include/atmospherics/atmosphere.glsl"
#include "/include/atmospherics/clouds.glsl"
#include "/include/atmospherics/skyProjection.glsl"

//--// Functions //-----------------------------------------------------------//

vec3 getCloudsAerialPerspective(vec3 cloudsScattering, vec3 cloudData, vec3 rayDir, vec3 clearSky, float apparentDistance) {
	vec3 rayOrigin = vec3(0.0, planetRadius + CLOUDS_SCALE * (eyeAltitude - SEA_LEVEL), 0.0);
	vec3 rayEnd    = rayOrigin + apparentDistance * rayDir;

	vec3 transmittance;
	if (rayOrigin.y < length(rayEnd)) {
		vec3 trans0 = getAtmosphereTransmittance(rayOrigin, rayDir);
		vec3 trans1 = getAtmosphereTransmittance(rayEnd,    rayDir);

		transmittance = clamp01(trans0 / trans1);
	} else {
		vec3 trans0 = getAtmosphereTransmittance(rayOrigin, -rayDir);
		vec3 trans1 = getAtmosphereTransmittance(rayEnd,    -rayDir);

		transmittance = clamp01(trans1 / trans0);
	}

	return mix((1.0 - cloudData.b) * clearSky, cloudsScattering, transmittance);
}

void main() {
	ivec2 texel = ivec2(gl_FragCoord.xy);

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
			radiance = vec3(airMieDensity, cloudsCirrusCoverage, cloudsCumulusCoverage);
			break;
		}
	} else {
		vec3 rayDir = unprojectSky(coord);

		radiance = vec3(0.0);

		// Atmosphere

		vec3 atmosphereScattering = sunIrradiance * getAtmosphereScattering(rayDir, sunDir)
		                          + moonIrradiance * getAtmosphereScattering(rayDir, moonDir);

		vec3 atmosphereTransmittance = getAtmosphereTransmittance(rayDir.y, planetRadius);

		radiance = radiance * atmosphereTransmittance + atmosphereScattering;

		// Clouds

		Ray ray;
		ray.origin = vec3(0.0, CLOUDS_SCALE * (eyeAltitude - SEA_LEVEL) + planetRadius, 0.0) + CLOUDS_SCALE;
		ray.dir    = rayDir;

		vec3 cloudsLightDir = cloudsMoonlit ? moonDir : sunDir;

		float dither = texelFetch(noisetex, ivec2(texel & 511), 0).b;

		vec4 cloudData = drawClouds(ray, cloudsLightDir, dither, -1.0);

		vec3 cloudsScattering = mat2x3(cloudsDirectIrradiance, skyIrradiance) * cloudData.xy;
		     cloudsScattering = getCloudsAerialPerspective(cloudsScattering, cloudData.rgb, rayDir, atmosphereScattering, cloudData.w);

		#define cloudsTransmittance cloudData.z

		radiance = radiance * cloudsTransmittance + cloudsScattering;
	}
}
