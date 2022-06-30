/*
 * Program description:
 * Deferred lighting pass for translucent objects, simple fog, reflections and refractions
 */

#include "/include/global.glsl"

//--// Outputs //-------------------------------------------------------------//

/* RENDERTARGETS: 3,9 */
layout (location = 0) out vec3 radiance;
layout (location = 1) out vec4 reflectionHistory;


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
uniform sampler2D colortex8;  // Scene history
uniform sampler2D colortex9;  // SSR history
uniform sampler2D colortex11; // Clouds
uniform sampler2D colortex13; // Previous frame depth

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

uniform float blindness;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;

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

#define TEMPORAL_REPROJECTION

#include "/block.properties"
#include "/entity.properties"

#include "/include/atmospherics/atmosphere.glsl"
#include "/include/atmospherics/skyProjection.glsl"

#include "/include/fragment/fog.glsl"
#include "/include/fragment/material.glsl"
#include "/include/fragment/raytracer.glsl"
#include "/include/fragment/textureFormat.glsl"

#include "/include/lighting/bsdf.glsl"
#include "/include/lighting/cloudShadows.glsl"
#include "/include/lighting/shadowMapping.glsl"

#include "/include/utility/bicubic.glsl"
#include "/include/utility/color.glsl"
#include "/include/utility/encoding.glsl"
#include "/include/utility/sampling.glsl"
#include "/include/utility/spaceConversion.glsl"

//--// Functions //-----------------------------------------------------------//

/*
const bool colortex3MipmapEnabled = true;
const bool colortex8MipmapEnabled = true;
*/

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

	// Sunlight/moonlight

#if defined WORLD_OVERWORLD || defined WORLD_END
	float NoL = dot(normal, lightDir) * step(0.0, dot(flatNormal, lightDir));

#if defined WORLD_OVERWORLD
	float cloudShadow = getCloudShadows(colortex7, scenePos);
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

	radiance += 256.0 * material.emission;

	// Simple fog
	radiance = applySimpleFog(radiance, scenePos, clearSky);

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

mat3 getTbnMatrix(vec3 normal) {
	vec3 tangent   = normalize(cross(vec3(0.0, 1.0, 0.0), normal));
	vec3 bitangent = normalize(cross(tangent, normal));
	return mat3(tangent, bitangent, normal);
}

vec3 getRadianceAlongRay(
	vec3 screenPos,
	vec3 viewPos,
	vec3 rayDir,
	float dither,
	float mipLevel,
	float skylightFalloff,
	inout float hitDistance
) {
	vec3 viewDir = mat3(gbufferModelView) * rayDir;

	vec3 hitPos;
	bool hit = raytraceIntersection(
		depthtex0,
		screenPos,
		viewPos,
		viewDir,
		1.0,
		dither,
		mipLevel == 0.0 ? SSR_INTERSECTION_STEPS_SMOOTH : SSR_INTERSECTION_STEPS_ROUGH,
		SSR_REFINEMENT_STEPS,
		false,
		hitPos
	);

	vec3 skyRadiance = textureBicubic(colortex4, projectSky(rayDir)).rgb * skylightFalloff;

	if (hit) {
		vec3 viewHitPos = screenToViewSpace(hitPos, true);
		hitDistance += distance(viewPos, viewHitPos);

		float borderAttenuation = (hitPos.x * hitPos.y - hitPos.x) * (hitPos.x * hitPos.y - hitPos.y);
		      borderAttenuation = smoothstep(0.0, 0.025, dampen(borderAttenuation));

#ifdef SSR_PREVIOUS_FRAME
		hitPos = reproject(hitPos);
		vec3 radiance = textureLod(colortex8, hitPos.xy, int(mipLevel)).rgb;
#else
		vec3 radiance = textureLod(colortex3, hitPos.xy, int(mipLevel)).rgb;
#endif

		return mix(skyRadiance, radiance, borderAttenuation);
	} else { // Sky reflection
		return skyRadiance;
	}
}

vec3 reprojectSpecular(
	vec3 screenPos,
	float roughness,
	float hitDistance
) {
	// Reprojection method from Samuel
	if (roughness < 0.33) {
		vec3 pos = screenToViewSpace(screenPos, false);
		     pos = pos + normalize(pos) * hitDistance;
             pos = viewToSceneSpace(pos);

		vec3 cameraOffset = linearizeDepth(screenPos.z) < MC_HAND_DEPTH
			? vec3(0.0)
			: cameraPosition - previousCameraPosition;

		vec3 previousPos = transform(gbufferPreviousModelView, pos + cameraOffset);
		     previousPos = projectAndDivide(gbufferPreviousProjection, previousPos);

		return previousPos * 0.5 + 0.5;
	} else {
		return reproject(screenPos);
	}
}

vec3 getSpecularReflections(
	Material material,
	vec3 screenPos,
	vec3 viewPos,
	vec3 worldDir,
	vec3 worldNormal,
	float skylight
) {
	bool hasReflections = (material.f0.x - material.f0.x * material.roughness * SSR_ROUGHNESS_THRESHOLD) > 0.015; // based on Kneemund's method
	if (!hasReflections) return vec3(0.0);

	float alphaSq = sqr(material.roughness);
	float skylightFalloff = pow8(skylight);

	float dither = R1(frameCounter, texelFetch(noisetex, ivec2(gl_FragCoord.xy) & 511, 0).b);

	float hitDistance = 0.0;

#ifdef SSR_ROUGH
	vec2 hash = R2(
		SSR_RAY_COUNT * frameCounter,
		vec2(
			texelFetch(noisetex, ivec2(gl_FragCoord.xy)                     & 511, 0).b,
			texelFetch(noisetex, ivec2(gl_FragCoord.xy + vec2(239.0, 23.0)) & 511, 0).b
		)
	);

	if (material.roughness > 5e-2) { // Rough reflection
	 	float mipLevel = sqrt(4.0 * dampen(material.roughness));

		mat3 tbn = getTbnMatrix(worldNormal);
		vec3 tangentDir = worldDir * tbn;

		vec3 reflection = vec3(0.0);

		for (int i = 0; i < SSR_RAY_COUNT; ++i) {
			vec3 microfacetNormal = tbn * sampleGgxVndf(-tangentDir, vec2(material.roughness), hash);
			vec3 rayDir = reflect(worldDir, microfacetNormal);

			vec3 radiance = getRadianceAlongRay(screenPos, viewPos, rayDir, dither, mipLevel, skylightFalloff, hitDistance);

			float MoV = clamp01(dot(microfacetNormal, -worldDir));
			float NoL = max(1e-2, dot(worldNormal, rayDir));
			float NoV = max(1e-2, dot(worldNormal, -worldDir));

			vec3 fresnel = material.isMetal ? fresnelSchlick(MoV, material.f0) : vec3(fresnelDielectric(MoV, material.n));
			float v1 = V1SmithGgx(NoV, alphaSq);
			float v2 = V2SmithGgx(NoL, NoV, alphaSq);

			reflection += radiance * fresnel * (2.0 * NoL * v2 / v1);

			hash = R2Next(hash);
		}

		float norm = rcp(float(SSR_RAY_COUNT));
		reflection *= norm;
		hitDistance *= norm;

		//--// Temporal accumulation

		float accumulationLimit = 16.0 * dampen(material.roughness); // Maximum accumulated frames

		vec3 previousScreenPos = reprojectSpecular(screenPos, material.roughness, hitDistance);

		reflectionHistory = textureSmooth(colortex9, previousScreenPos.xy);
		float historyDepth = 1.0 - textureSmooth(colortex13, previousScreenPos.xy).x;

		float depthDelta  = abs(linearizeDepth(screenPos.z) - linearizeDepth(historyDepth));
		float depthWeight = exp(-10.0 * depthDelta) * float(historyDepth < 1.0);

		float pixelAge  = min(reflectionHistory.a, accumulationLimit);
		      pixelAge *= float(clamp01(previousScreenPos.xy) == previousScreenPos.xy);
			  pixelAge *= depthWeight;
			  pixelAge += 1.0;

		float alpha = rcp(pixelAge);

		reflectionHistory.rgb = mix(reflectionHistory.rgb, reflection, alpha);
		reflectionHistory.a   = pixelAge;

		return reflectionHistory.rgb;
	}
#endif

	//--// Mirror-like reflection

	reflectionHistory = vec4(0.0);

	vec3 rayDir = reflect(worldDir, worldNormal);

	vec3 radiance = getRadianceAlongRay(screenPos, viewPos, rayDir, dither, 0.0, skylightFalloff, hitDistance);

	float NoV = clamp01(dot(worldNormal, -worldDir));

	vec3 fresnel = material.isMetal ? fresnelSchlick(NoV, material.f0) : vec3(fresnelDielectric(NoV, material.n));

	return radiance * fresnel;
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

	vec3 screenPosFront = vec3(coord, depthFront);
	vec3 viewPosFront = screenToViewSpace(screenPosFront, true);
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

	// SSR

#ifdef SSR
	radiance += getSpecularReflections(material, screenPosFront, viewPosFront, worldDir, normal, lmCoord.y);
#endif

	// Blend with clouds

	if (clouds.w < viewerDistance * CLOUDS_SCALE) {
		vec3 cloudsScattering = mat2x3(directIrradiance, skyIrradiance) * clouds.xy;

		radiance = radiance * clouds.z + cloudsScattering;
	}
}
