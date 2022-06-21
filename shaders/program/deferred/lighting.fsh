/*
 * Program description:
 * Deferred lighting pass for solid objects
 */

#include "/include/global.glsl"

//--// Outputs //-------------------------------------------------------------//

/* RENDERTARGETS: 3 */
layout (location = 0) out vec3 radiance;

//--// Inputs //--------------------------------------------------------------//

in vec2 coord;

flat in vec3 ambientIrradiance;
flat in vec3 directIrradiance;

#if defined SH_SKYLIGHT && defined GTAO
flat in vec3[9] skySh;
#else
flat in vec3 skyIrradiance;
#endif

//--// Uniforms //------------------------------------------------------------//

uniform sampler2D noisetex;

uniform sampler2D colortex0;  // Translucent overlays
uniform usampler2D colortex1; // Scene data
uniform sampler2D colortex3;  // Scene radiance
uniform sampler2D colortex6;  // Clear sky
uniform sampler2D colortex7;  // Cloud shadow map

#ifdef SSPT
uniform sampler2D colortex5;  // SSPT
#endif

#ifdef GTAO
uniform sampler2D colortex10; // GTAO
#endif

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

#include "/include/atmospherics/phaseFunctions.glsl"

#include "/include/fragment/aces/matrices.glsl"
#include "/include/fragment/fog.glsl"
#include "/include/fragment/material.glsl"
#include "/include/fragment/textureFormat.glsl"

#include "/include/lighting/bsdf.glsl"
#include "/include/lighting/cloudShadows.glsl"
#include "/include/lighting/shadowMapping.glsl"

#include "/include/utility/color.glsl"
#include "/include/utility/encoding.glsl"
#include "/include/utility/spaceConversion.glsl"
#include "/include/utility/sphericalHarmonics.glsl"

//--// Functions //-----------------------------------------------------------//

const float indirectRenderScale = 0.01 * INDIRECT_RENDER_SCALE;

vec3 getSubsurfaceScattering(vec3 albedo, float sssAmount, float sssDepth, float LoV) {
	const float sssIntensity  = 3.0;
	const float sssDensity    = 12.0;

	if (sssAmount < eps) return vec3(0.0);

	vec3 coeff = normalizeSafe(albedo) * sqrt(sqrt(length(albedo)));
	     coeff = (sssDensity * coeff - sssDensity) / sssAmount;

	vec3 sss1 = exp(3.0 * coeff * sssDepth) * henyeyGreensteinPhase(-LoV, 0.5);
	vec3 sss2 = exp(1.0 * coeff * sssDepth) * (0.6 * henyeyGreensteinPhase(-LoV, 0.4) + 0.4 * henyeyGreensteinPhase(-LoV, -0.2));

	return albedo * sssIntensity * sssAmount * (sss1 + sss2);
}

float getBlocklightFalloff(float blocklight, float ao) {
	float falloff  = rcp(16.0 - 15.0 * blocklight);
	      falloff  = linearStep(rcp(16.0), 1.0, falloff);
	      falloff *= mix(ao, 1.0, falloff);

	return falloff;
}

float getSkylightFalloff(float skylight) {
	return pow4(skylight);
}

void main() {
	ivec2 texel = ivec2(gl_FragCoord.xy);

	float depth   = texelFetch(depthtex1, texel, 0).x;
	vec4 overlays = texelFetch(colortex0, texel, 0);
	uvec4 encoded = texelFetch(colortex1, texel, 0);
	radiance      = texelFetch(colortex3, texel, 0).rgb;
	vec3 clearSky = texelFetch(colortex6, texel, 0).rgb;

#ifdef GTAO
	vec4 gtao = texture(colortex10, coord * indirectRenderScale);
#endif

	if (linearizeDepth(depth) < MC_HAND_DEPTH) depth += 0.38; // hand lighting fix from Capt Tatsu

	vec3 viewPos = screenToViewSpace(vec3(coord, depth), true);
	vec3 scenePos = viewToSceneSpace(viewPos);
	vec3 worldDir = normalize(scenePos - gbufferModelViewInverse[3].xyz);

	if (depth == 1.0) return;

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

	uint overlayId = uint(255.0 * overlays.a);
	albedo = overlayId == 0 ? albedo + overlays.rgb : albedo; // enchantment glint
	albedo = overlayId == 1 ? 2.0 * albedo * overlays.rgb : albedo; // damage overlay
	albedo = srgbToLinear(albedo) * r709ToAp1Unlit;

	// Get material

	Material material = getMaterial(albedo, blockId);

#ifdef MC_SPECULAR_MAP
	vec4 specularTex = unpackUnorm4x8(encoded.w);
	decodeSpecularTex(specularTex, material);
#endif

	radiance = vec3(0.0);

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
		blockId,
		sssDepth
	);

	if (maxOf(shadows) > eps|| material.sssAmount > eps) {
		NoL = clamp01(NoL);
		float NoV = clamp01(dot(normal, -worldDir));
		float LoV = dot(lightDir, -worldDir);
		float halfwayNorm = inversesqrt(2.0 * LoV + 2.0);
		float NoH = (NoL + NoV) * halfwayNorm;
		float LoH = LoV * halfwayNorm + halfwayNorm;

		float lightRadius = (sunAngle < 0.5 ? SUN_ANGULAR_RADIUS : MOON_ANGULAR_RADIUS) * (tau / 360.0);

		vec3 visibility = NoL * shadows;

		vec3 bsdf  = diffuseBrdf(material.albedo, material.f0.x, material.n, material.roughness, NoL, NoV, NoH, LoV);
		     bsdf *= float(!material.isMetal) * (1.0 - material.sssAmount);
#ifdef AO_IN_SUNLIGHT
			 bsdf *= gtao.w;
#endif
		     bsdf += specularBrdf(material, NoL, NoV, NoH, LoV, LoH, lightRadius);

		vec3 sss  = getSubsurfaceScattering(albedo, material.sssAmount, sssDepth, LoV);

		radiance += directIrradiance * cloudShadow * (bsdf * visibility + sss);
	}
#endif

#if defined SSPT

#else
	vec3 bsdf = albedo * rcpPi * (1.0 - float(material.isMetal));

	// Bounced light

	const float bounceAlbedo = 0.5;
	const vec3 bounceWeights = vec3(0.2, 0.6, 0.2); // fraction of light that bounces off each axis

	radiance += directIrradiance * bsdf * gtao.x * dot(max0(-normal), bounceWeights) * bounceAlbedo * rcpPi * pow8(lmCoord.y);

	// Skylight

	float skylightFalloff = getSkylightFalloff(lmCoord.y);

#ifdef SH_SKYLIGHT
	vec3 skylight = evaluateSphericalHarmonicsIrradiance(skySh, gtao.xyz * 2.0 - 1.0, gtao.w);
#else
	vec3 skylight = mix(skyIrradiance, vec3(skyIrradiance.b * sqrt(2.0)), rcpPi) * gtao.w;
#endif

	radiance += skylight * skylightFalloff * bsdf;

	// Blocklight

	float blocklightFalloff = getBlocklightFalloff(lmCoord.x, gtao.w);
	radiance += 16.0 * blackbody(3500.0) * bsdf * blocklightFalloff;

	// Ambient light

	radiance += ambientIrradiance * bsdf * gtao.w;
#endif

#ifdef DISTANCE_FADE
	radiance = distanceFade(radiance, clearSky, scenePos, worldDir);
#endif

	radiance += 16.0 * material.emission;
}
