#version 410 compatibility

/*
 * Program description:
 * Render volumetric fog
 */

#include "/include/global.glsl"

//--// Outputs //-------------------------------------------------------------//

/* RENDERTARGETS: 6,7 */
layout (location = 0) out vec3 fogScattering;
layout (location = 1) out vec3 fogTransmittance;

//--// Inputs //--------------------------------------------------------------//

in vec2 coord;

flat in vec3 directIrradiance;
flat in vec3 skyIrradiance;

//--// Uniforms //------------------------------------------------------------//

uniform sampler2D noisetex;

uniform sampler2D colortex15; // Cloud shadow map

uniform sampler2D depthtex0;

uniform sampler3D colortex10; // 3D worley noise

#ifdef SHADOW
uniform sampler2D shadowtex1;
#endif

//--// Camera uniforms

uniform int isEyeInWater;

uniform ivec2 eyeBrightness;

uniform float eyeAltitude;

uniform float near;
uniform float far;

uniform float blindness;

uniform vec3 cameraPosition;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

//--// Shadow uniforms

uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;

//--// Time uniforms

uniform int frameCounter;

uniform float rainStrength;

//--// Custom uniforms

uniform float eyeSkylight;

uniform float biomeCave;
uniform float biomeMayRain;

uniform float timeSunrise;
uniform float timeNoon;
uniform float timeSunset;
uniform float timeMidnight;

uniform float desertSandstorm;
uniform float lightningFlash;

uniform vec2 viewSize;
uniform vec2 viewTexelSize;

uniform vec2 taaOffset;

uniform vec3 lightDir;

//--// Includes //------------------------------------------------------------//

#include "/include/atmospherics/atmosphere.glsl"
#include "/include/atmospherics/phaseFunctions.glsl"

#include "/include/fragment/waterVolume.glsl"

#include "/include/lighting/cloudShadows.glsl"
#include "/include/lighting/shadowDistortion.glsl"

#include "/include/utility/random.glsl"
#include "/include/utility/spaceConversion.glsl"

//--// Constants //-----------------------------------------------------------//

const float fogRenderScale     = 0.01 * FOG_RENDER_SCALE;
const uint fogMinStepCount     = 8;
const uint fogMaxStepCount     = 25;
const float fogStepCountGrowth = 0.1;
const float fogScale           = 100.0 * AIR_FOG_DENSITY;
const vec2 fogFalloffStart     = vec2(30.0, 5.0);
const vec2 fogFalloffHalfLife  = vec2(15.0, 8.0); // How many meters it takes for the fog density to halve (rayleigh, mie)
const float fogLightningFlash  = 5.0;

// desert sandstorm
const float desertSandstormScatter = 0.5;
const vec3 desertSandstormExtinct  = vec3(0.2, 0.3, 0.8);
const vec2 desertSandstormDensity = vec2(0.005, 0.23); // rayleigh, mie

//--// Functions //-----------------------------------------------------------//

vec2 getFogDensity(vec3 worldPos) {
	const vec2 mul = -rcp(fogFalloffHalfLife);
	const vec2 add = -(SEA_LEVEL + fogFalloffStart) * mul;

	vec2 density    = exp2(min(worldPos.y * mul + add, 0.0));
	     density.y *= sqr(1.0 - texture(colortex10, 0.02 * worldPos).x);

	return density;
}

mat2x3 raymarchFog(vec3 worldStartPos, vec3 worldEndPos, bool isSky, float dither) {
	//--// Raymarching setup

	vec3 worldDir = worldEndPos - worldStartPos;
	float rayLength = length(worldDir);
	worldDir *= rcp(rayLength);

	vec3 shadowStartPos = mat3(shadowModelView) * (worldStartPos - cameraPosition) + shadowModelView[3].xyz;
	     shadowStartPos = diagonal(shadowProjection).xyz * shadowStartPos + shadowProjection[3].xyz;

	vec3 shadowDir = mat3(shadowModelView) * worldDir;
	     shadowDir = diagonal(shadowProjection).xyz * shadowDir;

	const float lowerPlaneAltitude = -64.0;
	const float upperPlaneAltitude = 320.0;

	float distanceToLowerPlane = (lowerPlaneAltitude - eyeAltitude) / worldDir.y;
	float distanceToUpperPlane = (upperPlaneAltitude - eyeAltitude) / worldDir.y;
	float distanceToVolumeStart, distanceToVolumeEnd;

	if (eyeAltitude < lowerPlaneAltitude) {
		// Below volume
		distanceToVolumeStart = distanceToLowerPlane;
		distanceToVolumeEnd = worldDir.y < 0.0 ? -1.0 : distanceToLowerPlane;
	} else if (eyeAltitude < upperPlaneAltitude) {
		// Inside volume
		distanceToVolumeStart = 0.0;
		distanceToVolumeEnd = worldDir.y < 0.0 ? distanceToLowerPlane : distanceToUpperPlane;
	} else {
		// Above volume
		distanceToVolumeStart = distanceToUpperPlane;
		distanceToVolumeEnd = worldDir.y < 0.0 ? distanceToUpperPlane : -1.0;
	}

	if (distanceToVolumeEnd < 0.0) return mat2x3(vec3(0.0), vec3(1.0)); // Did not intersect volume

	rayLength = isSky ? distanceToVolumeEnd : rayLength;
	rayLength = clamp(rayLength - distanceToVolumeStart, 0.0, far);

	uint stepCount = uint(float(fogMinStepCount) + fogStepCountGrowth * rayLength);
	     stepCount = clamp(stepCount, fogMinStepCount, fogMaxStepCount);

	float stepLength = rayLength * rcp(float(stepCount));

	vec3 worldStep = worldDir * stepLength;
	vec3 shadowStep = shadowDir * stepLength;

	vec3 worldPos = worldStartPos + worldDir * (distanceToVolumeStart + stepLength * dither);
	vec3 shadowPos = shadowStartPos + shadowDir * (distanceToVolumeStart + stepLength * dither);

	//--// Constants

	vec2 densityAtSeaLevel;
	densityAtSeaLevel.x = 0.3 * timeSunrise + 0.3 * timeNoon + 0.3 * timeSunset + 0.4 * timeMidnight;
	densityAtSeaLevel.y = 80.0 * timeSunrise + 0.5 * timeNoon + 50.0 * timeSunset + 40.0 * timeMidnight;

	mat2x3 scatteringCoeff = mat2x3(
		(airScatteringCoefficients[0] * fogScale) * densityAtSeaLevel.x,
		(airScatteringCoefficients[1] * fogScale) * densityAtSeaLevel.y
	);

	mat2x3 extinctionCoeff = mat2x3(
		(airExtinctionCoefficients[0] * fogScale) * densityAtSeaLevel.x,
		(airExtinctionCoefficients[1] * fogScale) * densityAtSeaLevel.y
	);

#ifdef DESERT_SANDSTORM
	scatteringCoeff[0] += desertSandstorm * desertSandstormDensity.x * desertSandstormScatter;
	extinctionCoeff[0] += desertSandstorm * desertSandstormDensity.x * desertSandstormExtinct;
	scatteringCoeff[1] += desertSandstorm * desertSandstormDensity.y * desertSandstormScatter;
	extinctionCoeff[1] += desertSandstorm * desertSandstormDensity.y * desertSandstormExtinct;
#endif

	//--// Raymarching loop

	vec3 transmittance = vec3(1.0);

	mat2x3 ambientScattering = mat2x3(0.0);
	mat2x3 directScattering  = mat2x3(0.0);

	for (int i = 0; i < stepCount; ++i, worldPos += worldStep, shadowPos += shadowStep) {
		vec3 shadowScreenPos = distortShadowSpace(shadowPos) * 0.5 + 0.5;

#ifdef SHADOW
		float shadowDepth = texelFetch(shadowtex1, ivec2(shadowScreenPos.xy * shadowMapResolution * MC_SHADOW_QUALITY), 0).x;
		float shadow = step(float(clamp01(shadowScreenPos) == shadowScreenPos) * shadowScreenPos.z, shadowDepth);
#else
		float shadow = 1.0;
#endif

#ifdef CLOUD_SHADOWS
		shadow *= getCloudShadows(colortex15, worldPos - cameraPosition);
#endif

		vec2 density = getFogDensity(worldPos) * stepLength;

		vec3 stepOpticalDepth = extinctionCoeff * density;
		vec3 stepTransmittance = exp(-stepOpticalDepth);
		vec3 stepTransmittedFraction = (1.0 - stepTransmittance) / max(stepOpticalDepth, eps);

		vec3 visibleScattering = stepTransmittedFraction * transmittance;

		directScattering[0]  += density.x * visibleScattering * shadow;
		directScattering[1]  += density.y * visibleScattering * shadow;
		ambientScattering[0] += density.x * visibleScattering;
		ambientScattering[1] += density.y * visibleScattering;

		transmittance *= stepTransmittance;
	}

	float eyeSkylight = rcp(240.0) * float(eyeBrightness.y) * linearStep(SEA_LEVEL - 15.0, SEA_LEVEL, eyeAltitude);

	directScattering[0]  *= scatteringCoeff[0];
	directScattering[1]  *= scatteringCoeff[1];
	ambientScattering[0] *= scatteringCoeff[0] * eyeSkylight;
	ambientScattering[1] *= scatteringCoeff[1] * eyeSkylight;

	float LoV = dot(worldDir, lightDir);

	vec2 phase;
	phase.x = rayleighPhase(LoV).x;
	phase.y = 0.7 * henyeyGreensteinPhase(LoV, 0.4) + 0.3 * henyeyGreensteinPhase(LoV, -0.2);

	/*
	// Single scattering
	vec3 scattering  = directIrradiance * (directScattering * phase);
	     scattering += skyIrradiance * (ambientScattering * vec2(isotropicPhase));
	/*/
	// Multiple scattering
	vec3 scattering = vec3(0.0);
	float scatteringStrength = 1.0;

	for (int i = 0; i < 4; ++i) {
		scattering += scatteringStrength * directIrradiance * (directScattering * phase);
		scattering += scatteringStrength * skyIrradiance * (ambientScattering * vec2(isotropicPhase));

		scatteringStrength *= 0.5;
		phase = mix(phase, vec2(isotropicPhase), 0.3);
	}
	//*/

	return mat2x3(scattering, transmittance);
}

void main() {
	ivec2 fogTexel = ivec2(gl_FragCoord.xy);
	ivec2 viewTexel = ivec2(gl_FragCoord.xy * rcp(fogRenderScale));

	if (clamp(viewTexel, ivec2(0), ivec2(viewSize)) != viewTexel) discard;

	float depth = texelFetch(depthtex0, viewTexel, 0).x;

	vec3 viewPos  = screenToViewSpace(vec3(coord * rcp(fogRenderScale), depth), true);
	vec3 scenePos = viewToSceneSpace(viewPos);
	vec3 worldPos = scenePos + cameraPosition;

	float dither = texelFetch(noisetex, fogTexel & 511, 0).b;
	      dither = R1(frameCounter, dither);

	mat2x3 fogData;

	switch (isEyeInWater) {
		case 0:
#ifdef AIR_FOG_VL
			vec3 rayOrigin = gbufferModelViewInverse[3].xyz + cameraPosition;
			vec3 rayEnd = worldPos;
			fogData = raymarchFog(rayOrigin, rayEnd, depth == 1.0, dither);
#else
#endif
			break;

	case 1:
#ifdef UNDERWATER_VL
#else
		vec3 rayDir = normalize(scenePos - gbufferModelViewInverse[3].xyz);
		float viewerDistance = length(viewPos);

		fogData = getSimpleWaterVolume(
			directIrradiance,
			skyIrradiance,
			vec3(0.0),
			viewerDistance,
			dot(lightDir, -rayDir),
			15.0 - 15.0 * eyeSkylight,
			eyeSkylight,
			1.0
		);
#endif
		break;

		default:
			fogData = mat2x3(vec3(0.0), vec3(1.0));
			break;
	}

	fogScattering    = fogData[0] * (1.0 - blindness);
	fogTransmittance = fogData[1];
}
