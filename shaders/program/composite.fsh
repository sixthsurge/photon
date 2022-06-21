/*
 * Program description:
 * Deferred lighting pass for translucent objects, simple fog, reflections and refractions
 */

#include "/include/global.glsl"

//--// Outputs //-------------------------------------------------------------//

/* RENDERTARGETS: 3 */
layout (location = 0) out vec3 radiance;

//--// Inputs //--------------------------------------------------------------//

in vec2 coord;

//--// Uniforms //------------------------------------------------------------//

uniform sampler2D noisetex;

uniform sampler2D colortex0;  // Translucent color
uniform usampler2D colortex1; // Scene data
uniform sampler2D colortex3;  // Scene radiance
uniform sampler2D colortex4;  // Sky capture, lighting color palette
uniform sampler2D colortex6;  // Clear sky
uniform sampler2D colortex7;  // Cloud shadows
uniform sampler2D colortex11; // Clouds

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

#ifdef SHADOW
#ifdef SHADOW_COLOR
uniform sampler2D shadowcolor0;
#endif
uniform sampler2D shadowtex0;
uniform sampler2DShadow shadowtex1;
#endif

//--// Camera uniforms

uniform int isEyeInWater;

uniform ivec2 eyeBrightnessSmooth;

uniform float eyeAltitude;

uniform float near;
uniform float far;

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

uniform float sunAngle;

//--// Custom uniforms

uniform float biomeCave;

uniform vec2 viewSize;
uniform vec2 viewTexelSize;

uniform vec2 taaOffset;

uniform vec3 lightDir;

//--// Includes //------------------------------------------------------------//

#include "/block.properties"
#include "/entity.properties"

#include "/include/atmospherics/atmosphere.glsl"

#include "/include/fragment/fog.glsl"
#include "/include/fragment/material.glsl"
#include "/include/fragment/textureFormat.glsl"

#include "/include/lighting/bsdf.glsl"
#include "/include/lighting/cloudShadows.glsl"
#include "/include/lighting/shadowMapping.glsl"

#include "/include/utility/color.glsl"
#include "/include/utility/encoding.glsl"
#include "/include/utility/spaceConversion.glsl"

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

float getSkylightFalloff(float skylight) {
	return pow4(skylight);
}

vec3 lightTranslucents(
	Material material,
	vec3 scenePos,
	vec3 normal,
	vec3 flatNormal,
	vec3 viewerDir,
	vec2 lmCoord,
	vec3 ambientIrradiance,
	vec3 directIrradiance,
	vec3 skyIrradiance,
	vec3 clearSky
) {
	vec3 radiance = vec3(0.0);

	// Self-emission

	radiance += 16.0 * material.emission;

	// Sunlight/moonlight

#if defined WORLD_OVERWORLD || defined WORLD_END
	float NoL = dot(normal, lightDir) * step(0.0, dot(flatNormal, lightDir));

#if defined WORLD_OVERWORLD
	float cloudShadow = getCloudShadow(colortex7, scenePos);
#else
	float cloudShadow = 1.0;
#endif

	float sssDepth;
	vec3 shadows = calculateShadows(
		scenePos,
		flatNormal,
		NoL,
		lmCoord.y,
		cloudShadow,
		material.sssAmount,
		0,
		sssDepth
	);

	if (maxOf(shadows) > eps|| material.sssAmount > eps) {
		NoL = clamp01(NoL);
		float NoV = clamp01(dot(normal, viewerDir));
		float LoV = dot(lightDir, viewerDir);
		float halfwayNorm = inversesqrt(2.0 * LoV + 2.0);
		float NoH = (NoL + NoV) * halfwayNorm;
		float LoH = LoV * halfwayNorm + halfwayNorm;

		float lightRadius = (sunAngle < 0.5 ? SUN_ANGULAR_RADIUS : MOON_ANGULAR_RADIUS) * (tau / 360.0);

		vec3 visibility = NoL * shadows * cloudShadow;

		vec3 diffuse  = diffuseBrdf(material.albedo, material.f0.x, material.n, material.roughness, NoL, NoV, NoH, LoV);
		vec3 specular = specularBrdf(material, NoL, NoV, NoH, LoV, LoH, lightRadius);

		radiance += directIrradiance * visibility * (diffuse + specular);
	}
#endif

	// Skylight

	vec3 bsdf = material.albedo * rcpPi;

	radiance += bsdf * skyIrradiance * getSkylightFalloff(lmCoord.y);

	// Blocklight

	radiance += 4.0 * blackbody(3750.0) * bsdf * pow5(lmCoord.x);

	// Ambient light

	radiance += bsdf * ambientIrradiance;

#ifdef DISTANCE_FADE
	radiance = distanceFade(radiance, clearSky, scenePos, -viewerDir);
#endif

	return radiance;
}

vec3 blendLayers(vec3 background, vec3 foreground, vec3 tint, float alpha) {
#if   BLENDING_METHOD == BLENDING_METHOD_MIX
	return mix(background, foreground, alpha);
#elif BLENDING_METHOD == BLENDING_METHOD_TINTED
	background *= (1.0 - alpha) + tint * alpha;
	return mix(background, foreground, alpha);
#endif
}

void main() {
	ivec2 texel = ivec2(gl_FragCoord.xy);

	float depthFront      = texelFetch(depthtex0, texel, 0).x;
	float depthBack       = texelFetch(depthtex1, texel, 0).x;
	vec4 translucentColor = texelFetch(colortex0, texel, 0);
	uvec4 encoded         = texelFetch(colortex1, texel, 0);
	radiance              = texelFetch(colortex3, texel, 0).rgb;

#if defined WORLD_OVERWORLD
	vec3 clearSky         = texelFetch(colortex6, texel, 0).rgb;
	vec4 clouds           = texelFetch(colortex11, texel, 0);
#endif

	if (depthFront == 1.0) return;

	// Fetch lighting palette

	vec3 ambientIrradiance = texelFetch(colortex4, ivec2(255, 0), 0).rgb;
	vec3 directIrradiance  = texelFetch(colortex4, ivec2(255, 1), 0).rgb;
	vec3 skyIrradiance     = texelFetch(colortex4, ivec2(255, 2), 0).rgb;

	// Transformations

	vec3 viewPosFront = screenToViewSpace(vec3(coord, depthFront), true);
	vec3 scenePosFront = viewToSceneSpace(viewPosFront);

	float viewerDistance = length(viewPosFront);

	vec3 viewPosBack = screenToViewSpace(vec3(coord, depthBack), true);

	vec3 worldDir = normalize(scenePosFront);

	// Unpack gbuffer data

	mat2x4 data = mat2x4(
		unpackUnorm4x8(encoded.x),
		unpackUnorm4x8(encoded.y)
	);

	vec3 albedo = data[0].xyz;
	uint blockId = uint(data[0].w * 255.0);
	vec3 flatNormal = decodeUnitVector(data[1].xy);
	vec2 lmCoord = data[1].zw;

#ifdef MC_NORMAL_MAP
	vec4 normalData = unpackUnormArb(encoded.z, uvec4(12, 12, 7, 1));
	vec3 normal = decodeUnitVector(normalData.xy);
#else
	#define normal flatNormal
#endif

	bool isWater = blockId == BLOCK_WATER;
	bool isTranslucent = depthFront != depthBack;

	albedo = srgbToLinear(isTranslucent ? translucentColor.rgb : albedo) * r709ToAp1;
	Material material = getMaterial(albedo, blockId);

#ifdef MC_SPECULAR_MAP
	vec4 specularTex = unpackUnorm4x8(encoded.w);
	decodeSpecularTex(specularTex, material);
#endif

	if (isWater) { // Water

	} else if (isTranslucent) { // Translucents
	 	vec3 background = radiance;
		vec3 foreground = lightTranslucents(material, scenePosFront, normal, flatNormal, -worldDir, lmCoord, ambientIrradiance, directIrradiance, skyIrradiance, clearSky);
		radiance = blendLayers(background, foreground, albedo, translucentColor.a);
	} else { // Solids

	}

	// Blend with clouds

	if (clouds.w < viewerDistance * CLOUDS_SCALE) {
		vec3 cloudsScattering = mat2x3(directIrradiance, skyIrradiance) * clouds.xy;

		radiance = radiance * clouds.z + cloudsScattering;
	}
}
