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

uniform ivec2 eyeBrightness;
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

uniform int moonPhase;

uniform float frameTimeCounter;

uniform float sunAngle;

//--// Custom uniforms

uniform float biomeCave;

uniform float timeNoon;

uniform vec2 viewSize;
uniform vec2 viewTexelSize;

uniform vec2 taaOffset;

uniform vec3 lightDir;
uniform vec3 sunDir;
uniform vec3 moonDir;

//--// Includes //------------------------------------------------------------//

#define PROGRAM_COMPOSITE
#define TEMPORAL_REPROJECTION

#include "/block.properties"
#include "/entity.properties"

#include "/include/atmospherics/atmosphere.glsl"
#include "/include/atmospherics/sky.glsl"
#include "/include/atmospherics/skyProjection.glsl"

#include "/include/fragment/fog.glsl"
#include "/include/fragment/material.glsl"
#include "/include/fragment/raytracer.glsl"
#include "/include/fragment/textureFormat.glsl"
#include "/include/fragment/waterNormal.glsl"
#include "/include/fragment/waterVolume.glsl"

#include "/include/lighting/bsdf.glsl"
#include "/include/lighting/cloudShadows.glsl"
#include "/include/lighting/lighting.glsl"
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

vec3 reprojectSpecular(
	vec3 screenPos,
	float roughness,
	float hitDistance
) {
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

vec3 traceSpecularRay(
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

	vec3 skyRadiance = texture(colortex4, projectSky(rayDir)).rgb * skylightFalloff * float(isEyeInWater == 0);

	if (hit) {
		float borderAttenuation = (hitPos.x * hitPos.y - hitPos.x) * (hitPos.x * hitPos.y - hitPos.y);
		      borderAttenuation = dampen(linearStep(0.0, 0.005, borderAttenuation));

#ifdef SSR_PREVIOUS_FRAME
		hitPos = reproject(hitPos);
		if (clamp01(hitPos) != hitPos) return skyRadiance;
		vec3 radiance = textureLod(colortex8, hitPos.xy, int(mipLevel)).rgb;
#else
		vec3 radiance = textureLod(colortex3, hitPos.xy, int(mipLevel)).rgb;
#endif

		vec3 viewHitPos = screenToViewSpace(hitPos, true);
		hitDistance += distance(viewPos, viewHitPos);

		return mix(skyRadiance, radiance, borderAttenuation);
	} else {
		return skyRadiance;
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

			vec3 radiance = traceSpecularRay(screenPos, viewPos, rayDir, dither, mipLevel, skylightFalloff, hitDistance);

			float MoV = clamp01(dot(microfacetNormal, -worldDir));
			float NoL = max(1e-2, dot(worldNormal, rayDir));
			float NoV = max(1e-2, dot(worldNormal, -worldDir));

			vec3 fresnel = material.isMetal ? fresnelSchlick(MoV, material.f0) : vec3(fresnelDielectric(MoV, material.n));
			float v1 = v1SmithGgx(NoV, alphaSq);
			float v2 = v2SmithGgx(NoL, NoV, alphaSq);

			reflection += radiance * fresnel * (2.0 * NoL * v2 / v1);

			hash = R2Next(hash);
		}

		float norm = rcp(float(SSR_RAY_COUNT));
		reflection *= norm;
		hitDistance *= norm;

		//--// Temporal accumulation

		vec3 previousScreenPos = reprojectSpecular(screenPos, material.roughness, hitDistance);

		reflectionHistory = textureSmooth(colortex9, previousScreenPos.xy);

		float historyDepth = 1.0 - textureSmooth(colortex13, previousScreenPos.xy).x;

		float depthDelta  = abs(linearizeDepth(screenPos.z) - linearizeDepth(historyDepth));
		float depthWeight = exp(-10.0 * depthDelta) * float(historyDepth < 1.0);

		float offscreenWeight = float(clamp01(previousScreenPos.xy) == previousScreenPos.xy);

		if (reflectionHistory != reflectionHistory) reflectionHistory.rgb = reflection;

		float pixelAge = reflectionHistory.a * depthWeight * offscreenWeight + 1.0;

		reflectionHistory.rgb = mix(reflectionHistory.rgb, reflection, rcp(pixelAge));

		float accumulationLimit = 16.0 * dampen(material.roughness); // Maximum accumulated frames
		reflectionHistory.a = min(pixelAge, accumulationLimit);

		return reflectionHistory.rgb;
	}
#endif

	//--// Mirror-like reflection

	reflectionHistory = vec4(0.0);

	vec3 rayDir = reflect(worldDir, worldNormal);

	vec3 radiance = traceSpecularRay(screenPos, viewPos, rayDir, dither, 0.0, skylightFalloff, hitDistance);

	float NoV = clamp01(dot(worldNormal, -worldDir));

	vec3 fresnel = material.isMetal ? fresnelSchlick(NoV, material.f0) : vec3(fresnelDielectric(NoV, material.n));

	return radiance * fresnel;
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

	/* -- texture fetches -- */

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

	/* -- fetch lighting palette -- */

	vec3 ambientIrradiance = texelFetch(colortex4, ivec2(255, 0), 0).rgb;
	vec3 directIrradiance  = texelFetch(colortex4, ivec2(255, 1), 0).rgb;
	vec3 skyIrradiance     = texelFetch(colortex4, ivec2(255, 2), 0).rgb;

	/* -- transformations -- */

	if (linearizeDepth(depthFront) < MC_HAND_DEPTH) depthFront += 0.38; // Hand lighting fix from Capt Tatsu

	vec3 screenPos = vec3(coord, depthFront);
	vec3 viewPos   = screenToViewSpace(screenPos, true);
	vec3 scenePos  = viewToSceneSpace(viewPos);
	vec3 worldPos  = scenePos + cameraPosition;

	float viewerDistance = length(viewPos);

	vec3 viewPosBack = screenToViewSpace(vec3(coord, depthBack), true);

	vec3 worldDir = normalize(scenePos);

	/* -- unpack gbuffer -- */

	mat2x4 data = mat2x4(
		unpackUnorm4x8(encoded.x),
		unpackUnorm4x8(encoded.y)
	);

	vec3 albedo = data[0].xyz;
	uint blockId = uint(data[0].w * 255.0);
	vec3 geometryNormal = decodeUnitVector(data[1].xy);
	vec2 lmCoord = data[1].zw;

	bool isWater = blockId == BLOCK_WATER;
	bool isTranslucent = depthFront != depthBack;

#ifdef MC_NORMAL_MAP
	vec4 normalData = unpackUnormArb(encoded.z, uvec4(12, 12, 7, 1));
	vec3 normal = decodeUnitVector(normalData.xy);
#else
	#define normal geometryNormal
#endif

	/* -- get material -- */

	albedo = srgbToLinear(isTranslucent ? translucentColor.rgb : albedo) * r709ToAp1;
	Material material = getMaterial(albedo, blockId);

#ifdef MC_SPECULAR_MAP
	vec4 specularTex = unpackUnorm4x8(encoded.w);
	decodeSpecularTex(specularTex, material);
#endif

	if (isWater) {
		material.f0 = vec3(0.02);
		material.n = isEyeInWater == 1 ? airN / waterN : waterN / airN;
		material.roughness = 0.002;

		// shadows

#if defined WORLD_OVERWORLD || defined WORLD_END
		float NoL = dot(geometryNormal, lightDir);

#if defined WORLD_OVERWORLD
		float cloudShadow = getCloudShadows(colortex7, scenePos);
#else
		float cloudShadow = 1.0;
#endif

		float sssDepth;
		vec3 shadows = getShadows(
			scenePos,
			geometryNormal,
			NoL,
			lmCoord.y,
			cloudShadow,
			1.0,
			0,
			sssDepth
		);
#else
		vec3 shadows = vec3(0.0);
#endif

		// water normals

		mat3 tbnMatrix = getTbnMatrix(geometryNormal);

#ifdef WATER_PARALLAX
		worldPos.xz = waterParallax(worldDir * tbnMatrix, worldPos.xz);
#endif

		vec3 tangentNormal = getWaterNormal(geometryNormal, worldPos);
		normal = tbnMatrix * tangentNormal;

		// refraction

		vec2 refractedCoord = coord + 0.5 * tangentNormal.xy * inversesqrt(dot(viewPos, viewPos) + eps);

		radiance  = texture(colortex3, refractedCoord).rgb;
		depthBack = texture(depthtex1, refractedCoord * renderScale).x;
		vec3 viewPosBack = screenToViewSpace(vec3(refractedCoord, depthBack), true);

		// water volume

		float LoV = dot(worldDir, lightDir);

		float distanceTraveled = (isEyeInWater == 1) ? 0.0 : distance(viewPos, viewPosBack);

		mat2x3 waterVolume = getSimpleWaterVolume(directIrradiance, skyIrradiance, ambientIrradiance, distanceTraveled, LoV, sssDepth, lmCoord.y, cloudShadow);

		radiance = radiance * waterVolume[0] + waterVolume[1];

		// water surface

		NoL = clamp01(dot(normal, lightDir));
		LoV = clamp01(dot(lightDir, -worldDir));
		float NoV = clamp01(dot(normal, -worldDir));
		float halfwayNorm = inversesqrt(2.0 * LoV + 2.0);
		float NoH = (NoL + NoV) * halfwayNorm;
		float LoH = LoV * halfwayNorm + halfwayNorm;

		radiance *= 1.0 - fresnelDielectric(NoV, material.n);

		if (maxOf(shadows) > eps) {
			vec3 brdf = getSpecularHighlight(material, NoL, NoV, NoH, LoV, LoH);
			radiance += directIrradiance * shadows * cloudShadow * NoL * brdf;
		}
	} else if (isTranslucent) {
	 	vec3 background = radiance;
		vec3 foreground = getSceneLighting(
			material,
			scenePos,
			normal,
			geometryNormal,
			-worldDir,
			ambientIrradiance,
			directIrradiance,
			skyIrradiance,
			lmCoord,
			1.0,
			blockId
		);

		radiance = blendLayers(background, foreground, albedo, translucentColor.a);
	}

	/* -- reflections -- */

#ifdef SSR
	radiance += getSpecularReflections(material, screenPos, viewPos, worldDir, normal, lmCoord.y);
#endif

	/* -- simple fog -- */

	if (isTranslucent) radiance = applySimpleFog(radiance, scenePos, clearSky);

	// temporary! will add underwater VL later
	if (isEyeInWater == 1) {
		mat2x3 waterVolume = getSimpleWaterVolume(
			directIrradiance,
			skyIrradiance,
			ambientIrradiance,
			length(viewPos),
			dot(worldDir, lightDir),
			15.0 - 15.0 * float(eyeBrightnessSmooth.y) * rcp(240.0),
			float(eyeBrightnessSmooth.y) * rcp(240.0),
			1.0
		);

		radiance = radiance * waterVolume[0] + waterVolume[1];
	}

	/* -- blend with clouds -- */

	if (clouds.w < viewerDistance * CLOUDS_SCALE) {
		vec3 cloudsScattering = mat2x3(directIrradiance, skyIrradiance) * clouds.xy;

		radiance = radiance * clouds.z + cloudsScattering;
	}
}
