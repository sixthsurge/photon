#if !defined INCLUDE_LIGHTING_SHADOWMAPPING
#define INCLUDE_LIGHTING_SHADOWMAPPING

#define KERNEL_BLUE_NOISE_32
#include "/include/fragment/kernel.glsl"

#include "/include/lighting/shadowDistortion.glsl"

#include "/include/utility/color.glsl"
#include "/include/utility/dithering.glsl"
#include "/include/utility/random.glsl"
#include "/include/utility/rotation.glsl"

const float shadowTexelSize = rcp(floor(float(shadowMapResolution) * MC_SHADOW_QUALITY));

// Fake, lightmap-based shadows for outside of the shadow distance or when shadow mapping is disabled
float lightmapShadows(float skylight, float NoL, out float sssDepth) {
	sssDepth = (0.15 + 6.0 * (1.0 - skylight)) * clamp01(1.0 - 0.8 * NoL);
	return smoothstep(0.97, 0.99, skylight) * step(0.0, NoL);
}

#ifdef SHADOW
float blockerSearch(sampler2D depthSampler, vec3 shadowScreenPos, vec3 shadowClipPos, float dither, out float sssDepth) {
	const uint stepCount = SHADOW_BLOCKER_SEARCH_STEPS;

	float radius = SHADOW_BLOCKER_SEARCH_RADIUS * shadowProjection[0].x;

	float blockerDepth = 0.0;
	float weightSum    = 0.0;
	sssDepth           = 0.0;

	mat2 rotateAndScale = getRotationMatrix(tau * dither) * radius;

	for (uint i = 0; i < stepCount; ++i) {
		vec2 coord   = shadowClipPos.xy + rotateAndScale * blueNoiseDisk[i];
		     coord /= getShadowDistortionFactor(coord);
		     coord   = 0.5 * coord + 0.5;

		float depth  = texelFetch(depthSampler, ivec2(coord * shadowMapResolution * MC_SHADOW_QUALITY), 0).x;
		float weight = step(depth, shadowScreenPos.z);

		blockerDepth += weight * depth;
		weightSum    += weight;
		sssDepth     += max0(shadowScreenPos.z - depth);
	}

	sssDepth *= -shadowProjectionInverse[2].z * rcp(SHADOW_DEPTH_SCALE * float(stepCount));

	return weightSum == 0.0 ? 0.0 : blockerDepth / weightSum;
}

float blockerDepthToPenumbraRadius(float depth, float blockerDepth, float cloudShadow) {
	float penumbraScale  = 8.0 * SHADOW_PENUMBRA_SCALE;
	float penumbraRadius = penumbraScale * (depth - blockerDepth) / blockerDepth;
	      penumbraRadius = min(penumbraRadius, SHADOW_BLOCKER_SEARCH_RADIUS);

	return (penumbraRadius + 0.125 * (1.0 - cloudShadow)) * shadowProjection[0].x;
}

vec3 shadowSimple(vec3 shadowScreenPos) {
#ifdef SHADOW_COLOR
	float shadow0 = texture(shadowtex0, shadowScreenPos);

	if (shadow0 < 1.0 - eps) {
		float shadow1 = texture(shadowtex1, shadowScreenPos);
		vec3  color   = texture(shadowcolor0, shadowScreenPos.xy).rgb;

		return shadow0 + shadow1 * color * (1.0 - shadow0);
	} else {
		return vec3(shadow0);
	}
#else
	return vec3(texture(shadowtex1, shadowScreenPos));
#endif
}

vec3 shadowSoft(
	vec3 shadowScreenPos,
	vec3 shadowClipPos,
	float penumbraRadius,
	float distortionFactor,
	float dither
) {
	// penumbraRadius > maxFilterRadius: blur
	// penumbraRadius < minFilterRadius: anti-alias (blur then sharpen)
	float minFilterRadius = 2.0 * shadowTexelSize * distortionFactor;

	float filterRadius = max(penumbraRadius, minFilterRadius);
	float filterScale  = sqr(filterRadius / minFilterRadius);

	uint stepCount = uint(SHADOW_PCF_STEPS_MIN + SHADOW_PCF_STEPS_INCREASE * filterScale);
	     stepCount = min(stepCount, SHADOW_PCF_STEPS_MAX);

	mat2 rotateAndScale = getRotationMatrix(tau * dither) * filterRadius;

	float shadow = 0.0;
	vec3 shadowColor = vec3(0.0);

	// perform first 4 iterations
	for (uint i = 0; i < 4; ++i) {
		vec2 offset = rotateAndScale * blueNoiseDisk[i];
		vec2 coord  = shadowClipPos.xy + offset;
		     coord /= getShadowDistortionFactor(coord);
		     coord  = coord * 0.5 + 0.5;

#ifdef SHADOW_COLOR
		shadow += texture(shadowtex0, vec3(coord, shadowScreenPos.z));
#else
		shadow += texture(shadowtex1, vec3(coord, shadowScreenPos.z));
#endif
	}

	// exit early if outside shadow
	if (shadow > 4.0 - eps)
		return vec3(0.25 * shadow);

	// perform remaining iterations
	for (uint i = 4; i < stepCount; ++i) {
		vec2 offset = rotateAndScale * blueNoiseDisk[i];
		vec2 coord  = shadowClipPos.xy + offset;
		     coord /= getShadowDistortionFactor(coord);
		     coord  = coord * 0.5 + 0.5;

#ifdef SHADOW_COLOR
		shadow += texture(shadowtex0, vec3(coord, shadowScreenPos.z));
#else
		shadow += texture(shadowtex1, vec3(coord, shadowScreenPos.z));
#endif
	}

	float perSampleWeight = rcp(float(stepCount));

	// sharpening for small penumbra sizes
	float sharpeningThreshold = 0.4 * max0((minFilterRadius - penumbraRadius) / minFilterRadius);
	shadow = linearStep(sharpeningThreshold, 1.0 - sharpeningThreshold, shadow * perSampleWeight);

#ifdef SHADOW_COLOR
	if (shadow > 1.0 - eps) return vec3(shadow);

	// filter colored shadow
	for (uint i = 0; i < stepCount; ++i) {
		vec2 offset = rotateAndScale * blueNoiseDisk[i];
		vec2 coord  = shadowClipPos.xy + offset;
		     coord /= getShadowDistortionFactor(coord);
		     coord  = coord * 0.5 + 0.5;

		float shadow = texture(shadowtex1, vec3(coord, shadowScreenPos.z));
		vec3  color  = texture(shadowcolor0, coord).rgb;

		shadowColor += shadow * color;
	}

	shadowColor *= perSampleWeight;
#endif

	return shadow + (1.0 - shadow) * shadowColor;
}

vec3 calculateShadows(
	vec3 scenePos,
	vec3 normal,
	float NoL,
	float skylight,
	float cloudShadow,
	uint blockId,
	out float sssDepth
) {
	vec3 shadowViewPos = transform(shadowModelView, scenePos);
	vec3 shadowClipPos = projectOrtho(shadowProjection, shadowViewPos);

	float distortionFactor = getShadowDistortionFactor(shadowClipPos.xy);

	// gri573's method to prevent peter panning
	// apply shadow bias away from the surface rather than in direction of the light
	// Prevents peter panning, but can cause shadows to be shortened or misaligned on edges
	float biasScale = 1.0 + 2.0 * pow5(max0(dot(normal, lightDir))); // Intended to fix the 'blob' of shadow acne that appears when the sun is near the horizon
	vec3 shadowNormal = diagonal(shadowProjection).xyz * (mat3(shadowModelView) * normal);
	shadowClipPos += SHADOW_BIAS * biasScale * sqr(distortionFactor) * shadowNormal;

	vec3 shadowScreenPos = distortShadowSpace(shadowClipPos, distortionFactor) * 0.5 + 0.5;

	// fake, lightmap-based shadows for outside of the shadow distance
	float distantShadow   = lightmapShadows(skylight, NoL, sssDepth);
	float distantSssDepth = sssDepth;
	if (clamp01(shadowScreenPos) != shadowScreenPos) return vec3(distantShadow);

	// fade into distant shadows in the distance
	float distanceFade = smoothstep(0.45, 0.5, maxOf(abs(shadowScreenPos.xy - 0.5)));
	distantShadow = mix(1.0, distantShadow, distanceFade);

#ifdef SHADOW_LEAK_PREVENTION
	// fade shadow light when skylight access is very low to hide light leaking underground caused
	// by optifine's poor shadow culling. This creates shadows in places where there should be none,
	// like directly under a floating island. Also, it mustn't be applied when looking through bodies
	// of water, otherwise the floor is completely black
	distantShadow *= (blockId == BLOCK_WATER) == (isEyeInWater == 1)
		? smoothstep(0.0, 0.1, skylight)
		: 1.0;
#endif

#if   SHADOW_QUALITY == SHADOW_QUALITY_FAST
	if (NoL < eps) {
		return vec3(0.0);
	} else {
		return shadowSimple(shadowScreenPos) * distantShadow;
	}
#elif SHADOW_QUALITY == SHADOW_QUALITY_FANCY
	float dither = interleavedGradientNoise(gl_FragCoord.xy, frameCounter);

#if defined PROGRAM_DEFERRED_LIGHTING
	vec2 penumbraMask = texelFetch(colortex7, ivec2(gl_FragCoord.xy), 0).xy;

	float blockerDepth = penumbraMask.x;
	sssDepth           = penumbraMask.y;
#else
	float blockerDepth = blockerSearch(shadowtex0, shadowScreenPos, shadowClipPos, dither, sssDepth);
#endif

	// fade into lightmap-based SSS in the distance
	sssDepth = mix(sssDepth, distantSssDepth, distanceFade);

	if (NoL < eps) return vec3(0.0);
	if (blockerDepth < eps) return vec3(distantShadow); // blocker search empty handed => no occlusion

	float penumbraRadius = blockerDepthToPenumbraRadius(shadowScreenPos.z, blockerDepth, cloudShadow);

	return shadowSoft(
		shadowScreenPos,
		shadowClipPos,
		penumbraRadius,
		distortionFactor,
		dither
	) * distantShadow;
#endif
}

#else
vec3 calculateShadows(
	vec3 scenePos,
	vec3 normal,
	float NoL,
	float skylight,
	uint blockId,
	out float sssDepth
) {
	return vec3(lightmapShadows(skylight, NoL, sssDepth));
}
#endif

#endif // INCLUDE_LIGHTING_SHADOWMAPPING
