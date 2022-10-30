#version 400 compatibility

/*
--------------------------------------------------------------------------------

  Photon Shaders by SixthSurge

  world0/composite.fsh:
  Render volumetric fog

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

/* DRAWBUFFERS:56 */
layout (location = 0) out vec3 fogScattering;
layout (location = 1) out vec3 fogTransmittance;

in vec2 uv;

flat in vec3 lightColor;
flat in vec3 skyColor;
flat in mat2x3 fogCoeff[2];

uniform sampler2D noisetex;

uniform sampler2D colortex1; // Gbuffer data

uniform sampler2D depthtex1;

uniform sampler3D colortex3; // 3D worley noise

#ifdef SHADOW
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
#ifdef SHADOW_COLOR
uniform sampler2D shadowcolor0;
#endif
#endif

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;

uniform vec3 cameraPosition;

uniform float near;
uniform float far;

uniform float eyeAltitude;
uniform float blindness;

uniform int isEyeInWater;

uniform int frameCounter;

uniform float frameTimeCounter;

uniform vec3 lightDir;

uniform vec2 viewSize;
uniform vec2 texelSize;
uniform vec2 taaOffset;

uniform float eyeSkylight;

#define WORLD_OVERWORLD

#include "/include/utility/encoding.glsl"
#include "/include/utility/random.glsl"
#include "/include/utility/spaceConversion.glsl"

#include "/include/atmosphere.glsl"
#include "/include/phaseFunctions.glsl"
#include "/include/shadowDistortion.glsl"

#ifdef VOLUMETRIC_FOG
const uint fogMinStepCount     = 8;
const uint fogMaxStepCount     = 25;
const float fogStepCountGrowth = 0.1;
const float fogVolumeTop       = 320.0;
const float fogVolumeBottom    = SEA_LEVEL - 24.0;
const vec2 fogFalloffStart     = vec2(FOG_RAYLEIGH_FALLOFF_START, FOG_MIE_FALLOFF_START) + SEA_LEVEL;
const vec2 fogFalloffHalfLife  = vec2(FOG_RAYLEIGH_FALLOFF_HALF_LIFE, FOG_MIE_FALLOFF_HALF_LIFE);

vec2 fogDensity(vec3 worldPos) {
	const vec2 mul = -rcp(fogFalloffHalfLife);
	const vec2 add = -mul * fogFalloffStart;

	vec2 density = exp2(min(worldPos.y * mul + add, 0.0));

	// fade away below sea level
	density *= linearStep(fogVolumeBottom, SEA_LEVEL, worldPos.y);

#ifdef FOG_CLOUDY_NOISE
	const vec3 wind = 0.03 * vec3(1.0, 0.0, 0.7);

	float noise = texture(colortex3, 0.015 * worldPos + wind * frameTimeCounter).x;

	density.y *= 2.0 * sqr(1.0 - noise);
#endif

	return density;
}

mat2x3 raymarchFog(vec3 worldStartPos, vec3 worldEndPos, bool isSky, float skylight, float dither) {
	vec3 worldDir = worldEndPos - worldStartPos;

	float lengthSq = lengthSquared(worldDir);
	float norm = inversesqrt(lengthSq);
	float rayLength = lengthSq * norm;
	worldDir *= norm;

	vec3 shadowStartPos = transform(shadowModelView, worldStartPos - cameraPosition);
	     shadowStartPos = projectOrtho(shadowProjection, shadowStartPos);

	vec3 shadowDir = mat3(shadowModelView) * worldDir;
	     shadowDir = diagonal(shadowProjection).xyz * shadowDir;

	float distanceToLowerPlane = (fogVolumeBottom - eyeAltitude) / worldDir.y;
	float distanceToUpperPlane = (fogVolumeTop    - eyeAltitude) / worldDir.y;
	float distanceToVolumeStart, distanceToVolumeEnd;

	if (eyeAltitude < fogVolumeBottom) {
		// Below volume
		distanceToVolumeStart = distanceToLowerPlane;
		distanceToVolumeEnd = worldDir.y < 0.0 ? -1.0 : distanceToLowerPlane;
	} else if (eyeAltitude < fogVolumeTop) {
		// Inside volume
		distanceToVolumeStart = 0.0;
		distanceToVolumeEnd = worldDir.y < 0.0 ? distanceToLowerPlane : distanceToUpperPlane;
	} else {
		// Above volume
		distanceToVolumeStart = distanceToUpperPlane;
		distanceToVolumeEnd = worldDir.y < 0.0 ? distanceToUpperPlane : -1.0;
	}

	if (distanceToVolumeEnd < 0.0) return mat2x3(vec3(0.0), vec3(1.0));

	rayLength = isSky ? distanceToVolumeEnd : rayLength;
	rayLength = clamp(rayLength - distanceToVolumeStart, 0.0, far);

	uint stepCount = uint(float(fogMinStepCount) + fogStepCountGrowth * rayLength);
	     stepCount = min(stepCount, fogMaxStepCount);

	float stepLength = rayLength * rcp(float(stepCount));

	vec3 worldStep = worldDir * stepLength;
	vec3 worldPos  = worldStartPos + worldDir * (distanceToVolumeStart + stepLength * dither);

	vec3 shadowStep = shadowDir * stepLength;
	vec3 shadowPos  = shadowStartPos + shadowDir * (distanceToVolumeStart + stepLength * dither);

	vec3 transmittance = vec3(1.0);

	mat2x3 lightSun = mat2x3(0.0); // Rayleigh, mie
	mat2x3 lightSky = mat2x3(0.0); // Rayleigh, mie

	for (int i = 0; i < stepCount; ++i, worldPos += worldStep, shadowPos += shadowStep) {
		vec3 shadowScreenPos = distortShadowSpace(shadowPos) * 0.5 + 0.5;

#ifdef SHADOW
	#ifdef FOG_COLOR
	#else
		float depth1 = texelFetch(shadowtex1, ivec2(shadowScreenPos.xy * shadowMapResolution * MC_SHADOW_QUALITY), 0).x;
		float shadow = step(float(clamp01(shadowScreenPos) == shadowScreenPos) * shadowScreenPos.z, depth1);
	#endif
#else
		#define shadow 1.0
#endif

		vec2 density = fogDensity(worldPos) * stepLength;

		vec3 stepOpticalDepth = fogCoeff[1] * density;
		vec3 stepTransmittance = exp(-stepOpticalDepth);
		vec3 stepTransmittedFraction = (1.0 - stepTransmittance) / max(stepOpticalDepth, eps);

		vec3 visibleScattering = stepTransmittedFraction * transmittance;

		lightSun[0] += visibleScattering * density.x * shadow;
		lightSun[1] += visibleScattering * density.y * shadow;
		lightSky[0] += visibleScattering * density.x;
		lightSky[1] += visibleScattering * density.y;

		transmittance *= stepTransmittance;
	}

	lightSun[0] *= fogCoeff[0][0];
	lightSun[1] *= fogCoeff[0][1];
	lightSky[0] *= fogCoeff[0][0] * eyeSkylight;
	lightSky[1] *= fogCoeff[0][1] * eyeSkylight;

	if (!isSky) {
		// Skylight falloff
		lightSky[0] *= skylight;
		lightSky[1] *= skylight;
	}

	float LoV = dot(worldDir, lightDir);
	float miePhase = 0.7 * henyeyGreensteinPhase(LoV, 0.5) + 0.3 * henyeyGreensteinPhase(LoV, -0.2);

	/*
	// Single scattering
	vec3 scattering  = lightColor * (lightSun * vec2(isotropicPhase, miePhase));
	     scattering += skyColor * (lightSky * vec2(isotropicPhase));
	/*/
	// Multiple scattering
	vec3 scattering = vec3(0.0);
	float scatterAmount = 1.0;

	for (int i = 0; i < 4; ++i) {
		scattering += scatterAmount * (lightSun * vec2(isotropicPhase, miePhase)) * lightColor;
		scattering += scatterAmount * (lightSky * vec2(isotropicPhase)) * skyColor;

		scatterAmount *= 0.5;
		miePhase = mix(miePhase, isotropicPhase, 0.3);
	}
	//*/

	scattering *= 1.0 - blindness;

	return mat2x3(scattering, transmittance);
}
#endif

void main() {
	ivec2 fogTexel  = ivec2(gl_FragCoord.xy);
	ivec2 viewTexel = ivec2(gl_FragCoord.xy * rcp(FOG_RENDER_SCALE));

	float depth   = texelFetch(depthtex1, viewTexel, 0).x;
	vec4 gbuffer0 = texelFetch(colortex1, viewTexel, 0);

	float skylight = unpackUnorm2x8(gbuffer0.w).y;

	vec3 viewPos  = screenToViewSpace(vec3(uv, depth), true);
	vec3 scenePos = viewToSceneSpace(viewPos);
	vec3 worldPos = scenePos + cameraPosition;

	float dither = texelFetch(noisetex, fogTexel & 511, 0).b;
	      dither = R1(frameCounter, dither);

	switch (isEyeInWater) {
#ifdef VOLUMETRIC_FOG
		case 0:
			vec3 worldStartPos = gbufferModelViewInverse[3].xyz + cameraPosition;
			vec3 worldEndPos   = worldPos;

			mat2x3 fog = raymarchFog(worldStartPos, worldEndPos, depth == 1.0, skylight, dither);

			fogScattering    = fog[0];
			fogTransmittance = fog[1];

			break;
#endif

		default:
			fogScattering    = vec3(0.0);
			fogTransmittance = vec3(1.0);
			break;

		// Prevent potential game crash due to empty switch statement
		case -1:
			break;
	}
}
