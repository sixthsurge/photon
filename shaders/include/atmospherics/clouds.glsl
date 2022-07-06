#if !defined INCLUDE_ATMOSPHERE_CLOUDS
#define INCLUDE_ATMOSPHERE_CLOUDS

#include "/include/atmospherics/atmosphere.glsl"
#include "/include/atmospherics/phaseFunctions.glsl"
#include "/include/atmospherics/weather.glsl"

#include "/include/utility/fastMath.glsl"
#include "/include/utility/random.glsl"
#include "/include/utility/sampling.glsl"

const float groundAlbedo = 0.4;

float cloudsPhaseSingle(float cosTheta) { // single scattering phase function
	return 0.7 * kleinNishinaPhase(cosTheta, 2600.0)    // forwards lobe
	     + 0.3 * henyeyGreensteinPhase(cosTheta, -0.2); // backwards lobe
}

float cloudsPhaseMulti(float cosTheta, vec3 g) { // multiple scattering phase function
	return 0.65 * henyeyGreensteinPhase(cosTheta,  g.x)  // forwards lobe
	     + 0.10 * henyeyGreensteinPhase(cosTheta,  g.y)  // forwards peak
	     + 0.25 * henyeyGreensteinPhase(cosTheta, -g.z); // backwards lobe
}

/* -- volumetric clouds -- */

struct CloudVolume {
	float radius;
	float thickness;
	float frequency;
	float coverage;
	float density;
	float cloudType; // blend between cumulus clouds (0.0) and stratus clouds (1.0)
	float detailMul;
	float curlMul;
	vec2 randomOffset;
	vec2 wind;
};

float cloudsPowderEffect(float density, float cosTheta) {
	float powder = pi * density / (density + 0.15);
	      powder = mix(powder, 1.0, 0.75 * sqr(cosTheta * 0.5 + 0.5));

	return powder;
}

float volumetricCloudsDensity(CloudVolume volume, vec3 pos, float altitudeFraction, uint lod) {
	const float localCoverageVariation = 0.3;
	const float localTypeVariation     = 0.5;
	const uint detailIterations        = 2;

	pos.xz += cameraPosition.xz * CLOUDS_SCALE;

	vec2 pos2D = pos.xz * volume.frequency + volume.randomOffset + volume.wind;

	// 2D noise to determine where to place clouds
	vec4 noise2D;
	noise2D.xy = texture(noisetex, 0.000002 * pos2D).xw; // cloud type, cloud coverage
	noise2D.zw = texture(noisetex, 0.00002 * pos2D).wx;  // base shape

	float cloudType = clamp01(mix(volume.cloudType - localTypeVariation, volume.cloudType + localTypeVariation, noise2D.x));
	float coverage  = clamp01(mix(volume.coverage - localCoverageVariation, volume.coverage + localCoverageVariation, noise2D.y));

	float density = linearStep(1.0 - coverage, 1.0, mix(noise2D.z, noise2D.w * 0.5 + 0.4, 0.8 * cloudType));

	// Attenuate and erode density over altitude
	altitudeFraction *= mix(0.75, 1.25, sqr(cloudType));
	const vec4 cloudGradient = vec4(0.2, 0.2, 0.85, 0.2);
	density *= smoothstep(0.0, cloudGradient.x, altitudeFraction);
	density *= smoothstep(0.0, cloudGradient.y, 1.0 - altitudeFraction);
	density -= smoothstep(cloudGradient.z, 1.0, 1.0 - altitudeFraction) * 0.1;
	density -= smoothstep(cloudGradient.w, 1.0, altitudeFraction) * 0.6;

	if (density < eps) return 0.0;

	// Curl noise used to warp the 3D noise into swirling shapes
	vec3 curl = 0.1 * volume.curlMul * texture(depthtex2, 0.002 * pos).xyz * smoothstep(0.4, 1.0, 1.0 - altitudeFraction);

	// 3D worley noise for detail
	float detailAmplitude = mix(0.45, 0.35, cloudType) * volume.detailMul;
	float detailFrequency = 0.0008 * volume.frequency;
	float detailFade = 0.5 - 0.35 * smoothstep(0.05, 0.5, altitudeFraction);

	for (uint i = lod; i < detailIterations; ++i) {
		pos.xz += 0.5 * volume.wind;

		density -= sqr(texture(depthtex0, pos * detailFrequency + curl).x) * detailAmplitude * dampen(clamp01(1.0 - density));

		detailAmplitude *= detailFade;
		detailFrequency *= 4.0;
		curl *= 3.0;
	}

	// Account for remaining detail iterations
	for (uint i = 0u; i < min(lod, detailIterations); ++i) {
		density -= detailAmplitude * 0.25 * dampen(clamp01(1.0 - density));
		detailAmplitude *= detailFade;
	}

	if (density < eps) return 0.0;

	// Adjust density so that the clouds are wispy at the bottom and hard at the top
	density  = 1.0 - pow(1.0 - density, 3.0 + 5.0 * altitudeFraction - 2.0 * cloudType);
	density *= 0.1 + 0.9 * smoothstep(0.2, 0.7, altitudeFraction) * mix(1.0, 0.8, cloudType);


	return density;
}

float volumetricCloudsOpticalDepth(
	CloudVolume volume,
	vec3 rayOrigin,
	vec3 rayDir,
	float dither,
	const uint stepCount
) {
	const float stepGrowth = 2.0;

	float stepLength = 0.04 * volume.thickness * (6.0 / float(stepCount));

	vec3 rayPos = rayOrigin;
	vec4 rayStep = vec4(rayDir, 1.0) * stepLength;
	uint lod = 0;

	float opticalDepth = 0.0;

	for (uint i = 0u; i < stepCount; ++i, rayPos += rayStep.xyz) {
		rayStep *= stepGrowth;

		vec3 ditheredPos = rayPos + rayStep.xyz * dither;

		float altitudeFraction = (length(ditheredPos) - volume.radius) * rcp(volume.thickness);
		if (clamp01(altitudeFraction) != altitudeFraction) break;

		opticalDepth += volumetricCloudsDensity(volume, ditheredPos, altitudeFraction, lod++) * rayStep.w;
	}

	return opticalDepth;
}

vec2 volumetricCloudsScattering(
	CloudVolume volume,
	float density,
	float stepTransmittance,
	float lightOpticalDepth,
	float skyOpticalDepth,
	float groundOpticalDepth,
	float cosTheta,
	float bouncedLight
) {
	float scatteringAlbedo = 1.0 - 0.33 * rainStrength;
	vec2 scattering = vec2(0.0);

	float sigmaS = volume.density * scatteringAlbedo;
	float sigmaT = volume.density;

	float powderEffect = cloudsPowderEffect(density, cosTheta);

	float phase = cloudsPhaseSingle(cosTheta);
	vec3 phaseG = pow(vec3(0.6, 0.9, 0.3), vec3(1.0 + lightOpticalDepth));

	for (uint i = 0u; i < 8u; ++i) {
		scattering.x += sigmaS * exp(-sigmaT *  lightOpticalDepth) * phase;                         // direct light
		scattering.x += sigmaS * exp(-sigmaT * groundOpticalDepth) * isotropicPhase * bouncedLight; // bounced light
		scattering.y += sigmaS * exp(-sigmaT *    skyOpticalDepth) * isotropicPhase;                // skylight

		sigmaS *= 0.55 * powderEffect;
		sigmaT *= 0.4;
		phaseG *= 0.8;
		powderEffect = 0.5 * powderEffect + 0.5 * sqrt(powderEffect);

		phase = cloudsPhaseMulti(cosTheta, phaseG);
	}

	float scatteringIntegral = (1.0 - stepTransmittance) / volume.density;

	return scattering * scatteringIntegral;
}

vec4 renderVolumetricClouds(
	CloudVolume volume,
	vec3 rayOrigin,
	vec3 rayDir,
	vec3 lightDir,
	float dither,
	float distanceToTerrain,
	float cosTheta,
	float bouncedLight,
	uint primarySteps,
	uint lightingSteps
) {
	/* -- raymarching setup -- */

	const float maxRayLength     = 2e4;
	const float minTransmittance = 0.075;
	const float primaryStepsMulH = 1.0;
	const float primaryStepsMulV = 0.5;
	const uint ambientSteps      = 2;

	primarySteps = uint(float(primarySteps) * mix(primaryStepsMulH, primaryStepsMulV, abs(rayDir.y))); // take fewer steps when the ray points vertically

	float r = length(rayOrigin);

	vec2 dists = intersectSphericalShell(rayOrigin, rayDir, volume.radius, volume.radius + volume.thickness);

	bool planetIntersected = intersectSphere(rayOrigin, rayDir, planetRadius).y >= 0.0 && r > planetRadius;
	bool terrainIntersected = distanceToTerrain >= 0.0 && r < volume.radius && distanceToTerrain < dists.y;

	if (dists.y < 0.0                          // volume not intersected
	 || planetIntersected && r < volume.radius // planet blocking clouds
	 || terrainIntersected                     // terrain blocking clouds
	) {
		return vec4(0.0, 0.0, 1.0, 1e6);
	}

	float rayLength = (distanceToTerrain >= 0.0) ? distanceToTerrain : dists.y;
	      rayLength = min(rayLength - dists.x, maxRayLength);

	float stepLength = rayLength * rcp(float(primarySteps));

	vec3 rayPos = rayOrigin + rayDir * (dists.x + stepLength * dither);
	vec3 rayStep = rayDir * stepLength;

	vec2 scattering = vec2(0.0); // x: direct light, y: skylight
	float transmittance = 1.0;

	float distanceSum = 0.0;
	float distanceWeightSum = 0.0;

	/* -- raymarching loop -- */

	for (uint i = 0u; i < primarySteps; ++i, rayPos += rayStep) {
		if (transmittance < minTransmittance) break;

		float altitudeFraction = (length(rayPos) - volume.radius) * rcp(volume.thickness);

		float density = volumetricCloudsDensity(volume, rayPos, altitudeFraction, 0);

		if (density < eps) continue;

		// fade away in the distance to hide the cutoff
		float distanceToSample = distance(rayOrigin, rayPos);
		float distanceFade = smoothstep(0.95, 1.0, (distanceToSample - dists.x) * rcp(maxRayLength));

		density *= 1.0 - distanceFade;

		vec4 hash = hash4(fract(rayPos)); // used to dither the light rays
		vec3 skyRayDir = cosineWeightedHemisphereSample(vec3(0.0, 1.0, 0.0), hash.xy);

		float lightOpticalDepth  = volumetricCloudsOpticalDepth(volume, rayPos, lightDir, hash.z, lightingSteps);
		float skyOpticalDepth    = volumetricCloudsOpticalDepth(volume, rayPos, skyRayDir, hash.w, ambientSteps);
		float groundOpticalDepth = density * altitudeFraction * volume.thickness * 0.75; // guess optical depth to ground using altitude fraction and density from this sample

		float stepOpticalDepth = density * volume.density * stepLength;
		float stepTransmittance = exp(-stepOpticalDepth);

		scattering += volumetricCloudsScattering(
			volume,
			density,
			stepTransmittance,
			lightOpticalDepth,
			skyOpticalDepth,
			groundOpticalDepth,
			cosTheta,
			bouncedLight
		) * transmittance;

		transmittance *= stepTransmittance;

		// update distance to cloud
		distanceSum += distanceToSample * density;
		distanceWeightSum += density;
	}

	// remap the transmittance so that minTransmittance is 0
	transmittance = linearStep(minTransmittance, 1.0, transmittance);

	float distanceToCloud = distanceWeightSum == 0.0 ? 1e6 : distanceSum / distanceWeightSum;

	return vec4(scattering, transmittance, distanceToCloud);
}

/* -- planar clouds -- */

/* -- */

vec4 renderClouds(
	vec3 rayOrigin,
	vec3 rayDir,
	vec3 lightDir,
	float dither,
	float distanceToTerrain,
	bool isReflection
) {
	/*
	 * x: sunlight
	 * y: skylight
	 * z: transmittance
	 * w: distance to cloud
	 */

	vec4 result = vec4(0.0, 0.0, 1.0, 1e6);
	vec4 resultTemp;

	float cosTheta     = dot(rayDir, lightDir);
	float bouncedLight = groundAlbedo * lightDir.y * rcpPi * isotropicPhase;

#ifdef WORLD_TIME_ANIMATION
	float cloudsTime = worldAge;
#else
	float cloudsTime = frameTimeCounter;
#endif

	/* -- volumetric clouds -- */

	CloudVolume volume;

#ifdef VCLOUD_LAYER0 // layer 0 (cumulus/stratocumulus clouds)
	volume.radius       = VCLOUD_LAYER0_ALTITUDE + planetRadius;
	volume.thickness    = VCLOUD_LAYER0_THICKNESS;
	volume.frequency    = VCLOUD_LAYER0_FREQUENCY;
	volume.coverage     = vcloudLayer0Coverage(weather);
	volume.density      = vcloudLayer0Density(weather);
	volume.cloudType    = vcloudLayer0TypeBlend(weather);
	volume.detailMul    = vcloudLayer0DetailMultiplier(weather);
	volume.curlMul      = vcloudLayer0CurlMultiplier(weather);
	volume.randomOffset = vec2(0.0);
	volume.wind         = polar(VCLOUD_LAYER0_WIND_SPEED * cloudsTime, VCLOUD_LAYER0_WIND_ANGLE * degree);

	result = renderVolumetricClouds(
		volume,
		rayOrigin,
		rayDir,
		lightDir,
		dither,
		distanceToTerrain,
		cosTheta,
		bouncedLight,
		VCLOUD_LAYER0_PRIMARY_STEPS,
		VCLOUD_LAYER0_LIGHTING_STEPS
	);
#endif

#ifdef VCLOUD_LAYER1 // layer 1 (altocumulus/altostratus clouds)
	volume.radius       = VCLOUD_LAYER1_ALTITUDE + planetRadius;
	volume.thickness    = VCLOUD_LAYER1_THICKNESS;
	volume.frequency    = VCLOUD_LAYER1_FREQUENCY;
	volume.coverage     = vcloudLayer1Coverage(weather);
	volume.density      = VCLOUD_LAYER1_DENSITY * 0.1;
	volume.cloudType    = vcloudLayer1TypeBlend(weather);
	volume.detailMul    = VCLOUD_LAYER1_WISPINESS;
	volume.curlMul      = VCLOUD_LAYER1_SWIRLINESS;
	volume.randomOffset = vec2(631210.0, 814172.0);
	volume.wind         = polar(VCLOUD_LAYER1_WIND_SPEED * cloudsTime, VCLOUD_LAYER1_WIND_ANGLE * degree);

	resultTemp = renderVolumetricClouds(
		volume,
		rayOrigin,
		rayDir,
		lightDir,
		dither,
		distanceToTerrain,
		cosTheta,
		bouncedLight,
		VCLOUD_LAYER1_PRIMARY_STEPS,
		VCLOUD_LAYER1_LIGHTING_STEPS
	);

	result.xy = result.xy + result.z * resultTemp.xy;
	result.z *= resultTemp.z;
	result.w  = min(result.w, resultTemp.w);
#endif

#ifdef VCLOUD_LAYER2 // layer 2 (disabled by default)
	volume.radius       = VCLOUD_LAYER2_ALTITUDE + planetRadius;
	volume.thickness    = VCLOUD_LAYER2_THICKNESS;
	volume.frequency    = VCLOUD_LAYER2_FREQUENCY;
	volume.coverage     = VCLOUD_LAYER2_COVERAGE;
	volume.density      = VCLOUD_LAYER2_DENSITY * 0.1;
	volume.cloudType    = VCLOUD_LAYER2_TYPE_BLEND;
	volume.detailMul    = VCLOUD_LAYER2_WISPINESS;
	volume.curlMul      = VCLOUD_LAYER2_SWIRLINESS;
	volume.randomOffset = vec2(-659843.0, 234920.0);
	volume.wind         = polar(VCLOUD_LAYER2_WIND_SPEED * cloudsTime, VCLOUD_LAYER2_WIND_ANGLE * degree);

	resultTemp = renderVolumetricClouds(
		volume,
		rayOrigin,
		rayDir,
		lightDir,
		dither,
		distanceToTerrain,
		cosTheta,
		bouncedLight,
		VCLOUD_LAYER2_PRIMARY_STEPS,
		VCLOUD_LAYER2_LIGHTING_STEPS
	);

	result.xy = result.xy + result.z * resultTemp.xy;
	result.z *= resultTemp.z;
	result.w  = min(result.w, resultTemp.w);
#endif

#ifdef VCLOUD_LAYER3 // layer 3 (disabled by default)
	volume.radius       = VCLOUD_LAYER3_ALTITUDE + planetRadius;
	volume.thickness    = VCLOUD_LAYER3_THICKNESS;
	volume.frequency    = VCLOUD_LAYER3_FREQUENCY;
	volume.coverage     = VCLOUD_LAYER3_COVERAGE;
	volume.density      = VCLOUD_LAYER3_DENSITY * 0.1;
	volume.cloudType    = VCLOUD_LAYER3_TYPE_BLEND;
	volume.detailMul    = VCLOUD_LAYER3_WISPINESS;
	volume.curlMul      = VCLOUD_LAYER3_SWIRLINESS;
	volume.randomOffset = vec2(-979530.0, -122390.0);
	volume.wind         = polar(VCLOUD_LAYER3_WIND_SPEED * cloudsTime, VCLOUD_LAYER3_WIND_ANGLE * degree);

	resultTemp = renderVolumetricClouds(
		volume,
		rayOrigin,
		rayDir,
		lightDir,
		dither,
		distanceToTerrain,
		cosTheta,
		bouncedLight,
		VCLOUD_LAYER3_PRIMARY_STEPS,
		VCLOUD_LAYER3_LIGHTING_STEPS
	);

	result.xy = result.xy + result.z * resultTemp.xy;
	result.z *= resultTemp.z;
	result.w  = min(result.w, resultTemp.w);
#endif

	/* -- planar clouds -- */

	// If no cloud encountered, take distance to middle of first cloud layer (helps reprojection a lot)
	if (result.w > 1e5) {
		const float cloudVolumeMiddle = planetRadius + VCLOUD_LAYER0_ALTITUDE + VCLOUD_LAYER0_THICKNESS * 0.5;
		vec2 dists = intersectSphere(rayDir.y, rayOrigin.y, cloudVolumeMiddle);
		result.w = rayOrigin.y < cloudVolumeMiddle ? dists.y : dists.x;
	}

	return result;
}

/* -- cloud shadows -- */

float getCloudVolumeShadow(CloudVolume volume, vec3 rayOrigin, vec3 rayDir) {
	const uint stepCount = 8;

	vec2 dists   = intersectSphericalShell(rayOrigin, rayDir, volume.radius, volume.radius + volume.thickness);
	     dists.x = max0(dists.x);

	float rayLength = dists.y - dists.x;
	float stepLength = rayLength * rcp(float(stepCount));

	vec3 rayPos = rayOrigin + rayDir * (dists.x * 0.5 + stepLength);
	vec3 rayStep = rayDir * stepLength;

	float opticalDepth = 0.0;

	for (uint i = 0u; i < stepCount; ++i, rayPos += rayStep) {
		float altitudeFraction = (length(rayPos) - volume.radius) * rcp(volume.thickness);
		opticalDepth += volumetricCloudsDensity(volume, rayPos, altitudeFraction, 10);
	}

	return exp(-volume.density * opticalDepth * stepLength);
}

float getCloudShadows(vec3 rayOrigin, vec3 rayDir) {
	vec3 weather = getWeather();
	float result = 1.0;

#ifdef WORLD_TIME_ANIMATION
	float cloudsTime = worldAge;
#else
	float cloudsTime = frameTimeCounter;
#endif

	CloudVolume volume;

#if defined VCLOUD_LAYER0 && defined VCLOUD_LAYER0_SHADOW // layer 0 (cumulus/stratocumulus clouds)
	volume.radius       = VCLOUD_LAYER0_ALTITUDE + planetRadius;
	volume.thickness    = VCLOUD_LAYER0_THICKNESS;
	volume.frequency    = VCLOUD_LAYER0_FREQUENCY;
	volume.coverage     = vcloudLayer0Coverage(weather);
	volume.density      = vcloudLayer0Density(weather);
	volume.cloudType    = vcloudLayer0TypeBlend(weather);
	volume.detailMul    = vcloudLayer0DetailMultiplier(weather);
	volume.curlMul      = vcloudLayer0CurlMultiplier(weather);
	volume.randomOffset = vec2(0.0);
	volume.wind         = polar(VCLOUD_LAYER0_WIND_SPEED * cloudsTime, VCLOUD_LAYER0_WIND_ANGLE * degree);

	result  = getCloudVolumeShadow(volume, rayOrigin, rayDir);
#endif

#if defined VCLOUD_LAYER1 && defined VCLOUD_LAYER1_SHADOW // layer 1 (altocumulus/altostratus clouds)
	volume.radius       = VCLOUD_LAYER1_ALTITUDE + planetRadius;
	volume.thickness    = VCLOUD_LAYER1_THICKNESS;
	volume.frequency    = VCLOUD_LAYER1_FREQUENCY;
	volume.coverage     = vcloudLayer1Coverage(weather);
	volume.density      = VCLOUD_LAYER1_DENSITY * 0.1;
	volume.cloudType    = vcloudLayer1TypeBlend(weather);
	volume.detailMul    = VCLOUD_LAYER1_WISPINESS;
	volume.curlMul      = VCLOUD_LAYER1_SWIRLINESS;
	volume.randomOffset = vec2(631210.0, 814172.0);
	volume.wind         = polar(VCLOUD_LAYER1_WIND_SPEED * cloudsTime, VCLOUD_LAYER1_WIND_ANGLE * degree);

	result *= getCloudVolumeShadow(volume, rayOrigin, rayDir);
#endif

#if defined VCLOUD_LAYER2 && defined VCLOUD_LAYER2_SHADOW// layer 2 (disabled by default)
	volume.radius       = VCLOUD_LAYER2_ALTITUDE + planetRadius;
	volume.thickness    = VCLOUD_LAYER2_THICKNESS;
	volume.frequency    = VCLOUD_LAYER2_FREQUENCY;
	volume.coverage     = VCLOUD_LAYER2_COVERAGE;
	volume.density      = VCLOUD_LAYER2_DENSITY * 0.1;
	volume.cloudType    = VCLOUD_LAYER2_TYPE_BLEND;
	volume.detailMul    = VCLOUD_LAYER2_WISPINESS;
	volume.curlMul      = VCLOUD_LAYER2_SWIRLINESS;
	volume.randomOffset = vec2(-659843.0, 234920.0);
	volume.wind         = polar(VCLOUD_LAYER2_WIND_SPEED * cloudsTime, VCLOUD_LAYER2_WIND_ANGLE * degree);

	result *= getCloudVolumeShadow(volume, rayOrigin, rayDir);
#endif

#if defined VCLOUD_LAYER3 && defined VCLOUD_LAYER3_SHADOW // layer 3 (disabled by default)
	volume.radius       = VCLOUD_LAYER3_ALTITUDE + planetRadius;
	volume.thickness    = VCLOUD_LAYER3_THICKNESS;
	volume.frequency    = VCLOUD_LAYER3_FREQUENCY;
	volume.coverage     = VCLOUD_LAYER3_COVERAGE;
	volume.density      = VCLOUD_LAYER3_DENSITY * 0.1;
	volume.cloudType    = VCLOUD_LAYER3_TYPE_BLEND;
	volume.detailMul    = VCLOUD_LAYER3_WISPINESS;
	volume.curlMul      = VCLOUD_LAYER3_SWIRLINESS;
	volume.randomOffset = vec2(-979530.0, -122390.0);
	volume.wind         = polar(VCLOUD_LAYER3_WIND_SPEED * cloudsTime, VCLOUD_LAYER3_WIND_ANGLE * degree);

	result *= getCloudVolumeShadow(volume, rayOrigin, rayDir);
#endif

	return result;
}

#endif // INCLUDE_ATMOSPHERE_CLOUDS
