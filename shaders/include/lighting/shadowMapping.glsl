#if !defined INCLUDE_LIGHTING_SHADOWMAPPING
#define INCLUDE_LIGHTING_SHADOWMAPPING

#define KERNEL_BLUE_NOISE_32
#include "/include/fragment/kernel.glsl"

#include "/include/lighting/shadowDistortion.glsl"

#include "/include/utility/color.glsl"
#include "/include/utility/dithering.glsl"
#include "/include/utility/random.glsl"
#include "/include/utility/rotation.glsl"

// disable colored shadows for translucents
#if defined PROGRAM_COMPOSITE && defined SHADOW_COLOR
	#undef SHADOW_COLOR
#endif

const float shadowTexelSize = rcp(float(shadowMapResolution));

// Fake, lightmap-based shadows for outside of the shadow distance or when shadow mapping is disabled
float getDistantShadows(float skylight, float NoL, out float sssDepth) {
	sssDepth = (0.15 + 6.0 * (1.0 - skylight)) * clamp01(1.0 - 0.8 * NoL);
	return smoothstep(0.97, 0.99, skylight) * step(0.0, NoL);
}

#ifndef SHADOW
vec3 getShadows(
	vec3 scenePos,
	vec3 normal,
	float NoL,
	float skylight,
	float cloudShadow,
	float sssAmount,
	uint blockId,
	out float sssDepth
) {
	return vec3(getDistantShadows(skylight, NoL, sssDepth));
}
#else
vec3 textureShadowBilinear(vec3 shadowScreenPos) {
	float shadow = texture(shadowtex1, shadowScreenPos);

#ifdef SHADOW_COLOR
	vec3 color = texture(shadowcolor0, shadowScreenPos.xy).rgb;
	return shadow * color;
#else
	return vec3(shadow);
#endif
}

vec3 textureShadowPcf(
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

	float shadowSum = 0.0;
	vec3 colorSum = vec3(0.0);
	bool colorsMatch = true; // True if all of the first 4 samples have the same color
	vec3 lastColorSample = vec3(0.0);

	// Perform first 4 iterations
	for (uint i = 0; i < 4; ++i) {
		vec2 offset = rotateAndScale * blueNoiseDisk[i];
		vec2 coord  = shadowClipPos.xy + offset;
		     coord /= getShadowDistortionFactor(coord);
		     coord  = coord * 0.5 + 0.5;

		shadowSum += texture(shadowtex1, vec3(coord, shadowScreenPos.z));
#ifdef SHADOW_COLOR
		vec3 colorSample = texelFetch(shadowcolor0, ivec2(coord * vec2(shadowMapResolution)), 0).rgb;
		colorSum += colorSample;

		// Determine whether all of the samples so far have been the same color
		colorsMatch = colorsMatch && all(lessThan(colorSample - lastColorSample, vec3(eps)));
		lastColorSample = colorSample;
#endif
	}

	// Exit early if outside shadow or inside shadow umbra

#ifdef SHADOW_COLOR
	if (shadowSum < eps || (shadowSum > 4.0 - eps && colorsMatch))
		return 0.0625 * shadowSum * colorSum;
#else
	if (shadowSum < eps || (shadowSum > 4.0 - eps))
		return vec3(0.25 * shadowSum);
#endif

	// Perform remaining iterations
	for (uint i = 4; i < stepCount; ++i) {
		vec2 offset = rotateAndScale * blueNoiseDisk[i];
		vec2 coord  = shadowClipPos.xy + offset;
		     coord /= getShadowDistortionFactor(coord);
		     coord  = coord * 0.5 + 0.5;

		shadowSum += texture(shadowtex1, vec3(coord, shadowScreenPos.z));
#ifdef SHADOW_COLOR
		colorSum += texelFetch(shadowcolor0, ivec2(coord * vec2(shadowMapResolution)), 0).rgb;
#endif
	}

	float rcpStepCount = rcp(float(stepCount));

	// Sharpening for small penumbra sizes
	float edge = 0.4 * max0((minFilterRadius - penumbraRadius) / minFilterRadius);
	shadowSum  = linearStep(edge, 1.0 - edge, shadowSum * rcpStepCount);

#ifdef SHADOW_COLOR
	return shadowSum * colorSum * rcpStepCount;
#else
	return vec3(shadowSum);
#endif
}

float blockerSearch(vec3 shadowScreenPos, vec3 shadowClipPos, float dither, out float sssDepth) {
	const uint stepCount = SHADOW_BLOCKER_SEARCH_STEPS;

	float radius = SHADOW_BLOCKER_SEARCH_RADIUS * shadowProjection[0].x;

	float depthSum    = 0.0;
	float depthSumSss = 0.0;
	float weightSum   = 0.0;

	mat2 rotateAndScale = getRotationMatrix(tau * dither) * radius;

	for (uint i = 0; i < stepCount; ++i) {
		vec2 coord   = shadowClipPos.xy + rotateAndScale * blueNoiseDisk[i];
		     coord /= getShadowDistortionFactor(coord);
		     coord   = 0.5 * coord + 0.5;

		float depth  = texelFetch(shadowtex0, ivec2(coord * shadowMapResolution), 0).x;
		float weight = step(depth, shadowScreenPos.z);

		depthSum    += weight * depth;
		weightSum   += weight;
		depthSumSss += max0(shadowScreenPos.z - depth);
	}

	depthSum = weightSum == 0.0 ? 0.0 : depthSum / weightSum;
	sssDepth = depthSumSss * -shadowProjectionInverse[2].z * rcp(SHADOW_DEPTH_SCALE * float(stepCount));

	return depthSum;
}

float getPenumbraRadiusFromBlockerDepth(float depth, float blockerDepth, float cloudShadow) {
	float penumbraScale  = 8.0 * SHADOW_PENUMBRA_SCALE;
	float penumbraRadius = penumbraScale * (depth - blockerDepth) / blockerDepth;
	      penumbraRadius = min(penumbraRadius, SHADOW_BLOCKER_SEARCH_RADIUS);

	return (penumbraRadius + 0.125 * (1.0 - cloudShadow)) * shadowProjection[0].x;
}

vec3 getShadows(
	vec3 scenePos,
	vec3 normal,
	float NoL,
	float skylight,
	float cloudShadow,
	float sssAmount,
	uint blockId,
	out float sssDepth
) {
	if (NoL < eps && sssAmount < eps) return vec3(0.0);

	vec3 shadowViewPos = transform(shadowModelView, scenePos);
	vec3 shadowClipPos = projectOrtho(shadowProjection, shadowViewPos);

	float distortionFactor = getShadowDistortionFactor(shadowClipPos.xy);

	// gri573's method to prevent peter panning
	// Apply shadow bias in direction of normal rather than in direction of the light
	// Prevents peter panning, but can cause shadows to be shortened or misaligned on edges
	float biasScale = 1.0 + 2.0 * pow5(max0(dot(normal, lightDir))); // Intended to fix the 'blob' of shadow acne that appears when the sun is near the horizon
	vec3 shadowNormal = diagonal(shadowProjection).xyz * (mat3(shadowModelView) * normal);
	vec3 shadowClipPos1 = shadowClipPos + SHADOW_BIAS * biasScale * sqr(distortionFactor) * vec3(0.0, 0.0, -1.0) * 0.005;

	vec3 shadowScreenPos = distortShadowSpace(shadowClipPos1, distortionFactor) * 0.5 + 0.5;

	// Fake, lightmap-based shadows for outside of the shadow distance
	float distantShadow = getDistantShadows(skylight, NoL, sssDepth);
	if (clamp01(shadowScreenPos) != shadowScreenPos) return vec3(distantShadow);

	// Fade into distant shadows in the distance
	float distanceFade = smoothstep(0.45, 0.5, maxOf(abs(shadowScreenPos.xy - 0.5)));
	distantShadow = mix(1.0, distantShadow, distanceFade);

#ifdef SHADOW_LEAK_PREVENTION
	// Fade shadow light when sky light level is very low to hide light leaking underground caused
	// by optifine's poor shadow culling. This creates shadows in places where there should be none,
	// like directly under a floating island. Also, it mustn't be applied when looking through bodies
	// of water, otherwise the floor is completely black
	distantShadow *= (blockId == BLOCK_WATER) == (isEyeInWater == 1)
		? smoothstep(0.0, 0.1, skylight)
		: 1.0;
#endif

#if   SHADOW_QUALITY == SHADOW_QUALITY_FAST
	return textureShadowBilinear(shadowScreenPos) * distantShadow;
#elif SHADOW_QUALITY == SHADOW_QUALITY_FANCY
	float dither = interleavedGradientNoise(gl_FragCoord.xy, frameCounter);

	float blockerDepth = blockerSearch(shadowScreenPos, shadowClipPos, dither, sssDepth);
	float penumbraRadius = getPenumbraRadiusFromBlockerDepth(shadowScreenPos.z, blockerDepth, cloudShadow);

	if (NoL < eps) {
	 	// Now we can exit early for SSS blocks
		return vec3(0.0);
	} else if (blockerDepth == 0.0) {
		// Blocker search empty handed => no occluders
		return vec3(distantShadow);
	}

	return textureShadowPcf(
		shadowScreenPos,
		shadowClipPos1,
		penumbraRadius,
		distortionFactor,
		dither
	) * distantShadow;
#endif
}
#endif

#endif // INCLUDE_LIGHTING_SHADOWMAPPING
