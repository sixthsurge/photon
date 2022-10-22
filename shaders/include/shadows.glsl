#if !defined SHADOWS_INCLUDED
#define SHADOWS_INCLUDED

#include "/include/utility/color.glsl"
#include "/include/utility/dithering.glsl"
#include "/include/utility/random.glsl"
#include "/include/utility/rotation.glsl"

#include "/include/shadowDistortion.glsl"

#define SHADOW_PCF_STEPS_MIN           6 // [4 6 8 12 16 18 20 22 24 26 28 30 32]
#define SHADOW_PCF_STEPS_MAX          12 // [4 6 8 12 16 18 20 22 24 26 28 30 32]
#define SHADOW_PCF_STEPS_SCALE       1.0 // [0.0 0.2 0.4 0.6 0.8 1.0 1.2 1.4 1.6 1.8 2.0]
#define SHADOW_BLOCKER_SEARCH_STEPS    6 // [3 6 9 12 15]
#define SHADOW_BLOCKER_SEARCH_RADIUS 0.5 // [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]

const int shadowmapSize = int(float(shadowMapResolution) * MC_SHADOW_QUALITY);
const float shadowmapTexelSize = rcp(float(shadowmapSize));

// This kernel is progressive: any sample count will return an even spread of points
const vec2[32] blueNoiseDisk = vec2[](
	vec2( 0.478712,  0.875764),
	vec2(-0.337956, -0.793959),
	vec2(-0.955259, -0.028164),
	vec2( 0.864527,  0.325689),
	vec2( 0.209342, -0.395657),
	vec2(-0.106779,  0.672585),
	vec2( 0.156213,  0.235113),
	vec2(-0.413644, -0.082856),
	vec2(-0.415667,  0.323909),
	vec2( 0.141896, -0.939980),
	vec2( 0.954932, -0.182516),
	vec2(-0.766184,  0.410799),
	vec2(-0.434912, -0.458845),
	vec2( 0.415242, -0.078724),
	vec2( 0.728335, -0.491777),
	vec2(-0.058086, -0.066401),
	vec2( 0.202990,  0.686837),
	vec2(-0.808362, -0.556402),
	vec2( 0.507386, -0.640839),
	vec2(-0.723494, -0.229240),
	vec2( 0.489740,  0.317826),
	vec2(-0.622663,  0.765301),
	vec2(-0.010640,  0.929347),
	vec2( 0.663146,  0.647618),
	vec2(-0.096674, -0.413835),
	vec2( 0.525945, -0.321063),
	vec2(-0.122533,  0.366019),
	vec2( 0.195235, -0.687983),
	vec2(-0.563203,  0.098748),
	vec2( 0.418563,  0.561335),
	vec2(-0.378595,  0.800367),
	vec2( 0.826922,  0.001024)
);

// Fake, lightmap-based shadows for outside of the shadow range or when shadows are disabled
float lightmapShadows(float skylight, float NoL, out float sssDepth) {
	sssDepth = 0.5 * (6.15 - 6.0 * skylight) * clamp01(1.0 - 0.5 * max0(NoL));
	return smoothstep(13.5 / 15.0, 14.5 / 15.0, skylight);
}

#ifdef SHADOW
vec2 blockerSearch(vec3 scenePos, float dither) {
	const uint stepCount = SHADOW_BLOCKER_SEARCH_STEPS;

	vec3 shadowViewPos = transform(shadowModelView, scenePos);
	vec3 shadowClipPos = projectOrtho(shadowProjection, shadowViewPos);
	float refZ = shadowClipPos.z * (SHADOW_DEPTH_SCALE * 0.5) + 0.5;

	float radius = SHADOW_BLOCKER_SEARCH_RADIUS * shadowProjection[0].x;
	mat2 rotateAndScale = getRotationMatrix(tau * dither) * radius;

	float depthSum    = 0.0;
	float weightSum   = 0.0;
	float depthSumSss = 0.0;

	for (uint i = 0; i < stepCount; ++i) {
		vec2 uv  = shadowClipPos.xy + rotateAndScale * blueNoiseDisk[i];
		     uv /= getShadowDistortionFactor(uv);
		     uv  = uv * 0.5 + 0.5;

		float depth  = texelFetch(shadowtex0, ivec2(uv * shadowmapSize), 0).x;
		float weight = step(depth, refZ);

		depthSum    += weight * depth;
		weightSum   += weight;
		depthSumSss += max0(refZ - depth);
	}

	float blockerDepth = weightSum == 0.0 ? 0.0 : depthSum / weightSum;
	float sssDepth = -shadowProjectionInverse[2].z * depthSumSss * rcp(SHADOW_DEPTH_SCALE * float(stepCount));

	return vec2(blockerDepth, sssDepth);
}

vec3 shadowBasic(vec3 shadowScreenPos) {
	float shadow = texture(shadowtex1, shadowScreenPos);

#ifdef SHADOW_COLOR
	ivec2 texel = ivec2(shadowScreenPos.xy * shadowmapSize);

	float depth  = texelFetch(shadowtex0, texel, 0).x;
	vec3  color  = texelFetch(shadowcolor0, texel, 0).rgb * 4.0;
	float weight = step(depth, shadowScreenPos.z) * step(eps, maxOf(color));

	color = color * weight + (1.0 - weight);

	return shadow * color;
#else
	return vec3(shadow);
#endif
}

vec3 shadowPcf(
	vec3 shadowScreenPos,
	vec3 shadowClipPos,
	float penumbraSize,
	float dither
) {
	// penumbraSize > maxFilterRadius: blur
	// penumbraSize < minFilterRadius: anti-alias (blur then sharpen)
	float distortionFactor = getShadowDistortionFactor(shadowClipPos.xy);
	float minFilterRadius = 2.0 * shadowmapTexelSize * distortionFactor;

	float filterRadius = max(penumbraSize, minFilterRadius);
	float filterScale = sqr(filterRadius / minFilterRadius);

	uint stepCount = uint(SHADOW_PCF_STEPS_MIN + SHADOW_PCF_STEPS_SCALE * filterScale);
	     stepCount = min(stepCount, SHADOW_PCF_STEPS_MAX);

	mat2 rotateAndScale = getRotationMatrix(tau * dither) * filterRadius;

	float shadow = 0.0;

	vec3 colorSum = vec3(0.0);
	float weightSum = 0.0;

	// perform first 4 iterations and filter shadow color
	for (uint i = 0; i < 4; ++i) {
		vec2 offset = rotateAndScale * blueNoiseDisk[i];

		vec2 uv  = shadowClipPos.xy + offset;
		     uv /= getShadowDistortionFactor(uv);
		     uv  = uv * 0.5 + 0.5;

		ivec2 texel = ivec2(uv * shadowmapSize);

		shadow += texture(shadowtex1, vec3(uv, shadowScreenPos.z));

#ifdef SHADOW_COLOR
		float depth = texelFetch(shadowtex0, texel, 0).x;

		vec3 color = texelFetch(shadowcolor0, texel, 0).rgb;
		     color = mix(vec3(1.0), 4.0 * color, step(depth, shadowScreenPos.z));

		float weight = step(eps, maxOf(color));

		colorSum += color * weight;
		weightSum += weight;
#endif
	}

	vec3 color = weightSum > 0.0 ? colorSum * rcp(weightSum) : vec3(1.0);

	// exit early if outside shadow
	if (shadow > 4.0 - eps) return color;
	else if (shadow < eps) return vec3(0.0);

	// perform remaining iterations
	for (uint i = 4; i < stepCount; ++i) {
		vec2 offset = rotateAndScale * blueNoiseDisk[i];

		vec2 uv  = shadowClipPos.xy + offset;
		     uv /= getShadowDistortionFactor(uv);
		     uv  = uv * 0.5 + 0.5;

		shadow += texture(shadowtex1, vec3(uv, shadowScreenPos.z));
	}

	float rcpSteps = rcp(float(stepCount));

	// sharpening for small penumbra sizes
	float sharpeningThreshold = 0.4 * max0((minFilterRadius - penumbraSize) / minFilterRadius);
	shadow = linearStep(sharpeningThreshold, 1.0 - sharpeningThreshold, shadow * rcpSteps);

	return shadow * color;
}

#ifdef SSRT_DISTANT_SHADOWS

#else
#endif

vec3 calculateShadows(
	vec3 scenePos,
	vec3 flatNormal,
	float skylight,
	float sssAmount,
	out float sssDepth
) {
	float NoL = dot(flatNormal, lightDir);
	if (NoL < 1e-2 && sssAmount < 1e-2) return vec3(0.0);

	vec3 bias = getShadowBias(scenePos, flatNormal, NoL, skylight);

	vec3 shadowViewPos = transform(shadowModelView, scenePos + bias);
	vec3 shadowClipPos = projectOrtho(shadowProjection, shadowViewPos);
	vec3 shadowScreenPos = distortShadowSpace(shadowClipPos) * 0.5 + 0.5;

	float distanceFade = pow16(lengthSquared(scenePos) * rcp(shadowDistance * shadowDistance) * maxOf(abs(shadowScreenPos.xy)));

#ifdef SSRT_DISTANT_SHADOWS
	float distantShadow = raytraceShadows();
#else
	float distantShadow = lightmapShadows(skylight, NoL, sssDepth);
#endif

	if (distanceFade >= 1.0) return vec3(distantShadow);

	distantShadow = (1.0 - distanceFade) + distanceFade * distantShadow;

	float dither = interleavedGradientNoise(gl_FragCoord.xy, frameCounter);

#ifdef SHADOW_VPS
	vec2 blockerSearchResult = blockerSearch(scenePos, dither);

	// SSS depth computed together with blocker depth
	sssDepth = mix(blockerSearchResult.y, sssDepth, distanceFade);

	if (NoL < 1e-2) return vec3(0.0); // now we can exit early for SSS blocks
	if (blockerSearchResult.x < eps) return vec3(distantShadow); // blocker search empty handed => no occluders

	float penumbraSize  = 16.0 * SHADOW_PENUMBRA_SCALE * (shadowScreenPos.z - blockerSearchResult.x) / blockerSearchResult.x;
	      penumbraSize  = min(penumbraSize, SHADOW_BLOCKER_SEARCH_RADIUS);
	      penumbraSize *= shadowProjection[0].x;
#else
	const float penumbraSize = sqrt(0.5) * shadowmapTexelSize * SHADOW_PENUMBRA_SCALE;
#endif

#ifdef SHADOW_PCF
	return distantShadow * shadowPcf(shadowScreenPos, shadowClipPos, penumbraSize, dither);
#else
	return distantShadow * shadowBasic(shadowScreenPos);
#endif
}
#else
vec3 calculateShadows(
	vec3 scenePos,
	vec3 flatNormal,
	float skylight,
	float sssAmount,
	out float sssDepth
) {
	float NoL = dot(flatNormal, lightDir);
	if (NoL < 1e-2 && sssAmount < 1e-2) return vec3(0.0);

	return vec3(lightmapShadows(skylight, NoL, sssDepth));
}
#endif

#endif // SHADOWS_INCLUDED
