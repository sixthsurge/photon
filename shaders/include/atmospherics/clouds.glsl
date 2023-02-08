#if !defined INCLUDE_ATMOSPHERE_CLOUDS
#define INCLUDE_ATMOSPHERE_CLOUDS

#include "/include/atmospherics/atmosphere.glsl"
#include "/include/atmospherics/phaseFunctions.glsl"
#include "/include/atmospherics/weather.glsl"

#include "/include/utility/fastMath.glsl"
#include "/include/utility/random.glsl"
#include "/include/utility/sampling.glsl"

struct CloudLayer {
	float sigmaS;
	float sigmaT;
	float radius;
	float thickness;
	float frequency;
	float detailStrength;
	float curlStrength;
	vec2 coverage;     // min/max
	vec4 cloudType;    // stratus min/max, cumulus humilis min/max
	vec2 randomOffset;
	vec2 wind;
};

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

float cloudsPowderEffect(float density, float cosTheta) {
	float powder = pi * density / (density + 0.15);
	      powder = mix(powder, 1.0, 0.75 * sqr(cosTheta * 0.5 + 0.5));

	return powder;
}

float cloudVolumeDensity(CloudLayer layer, vec3 pos, float altitudeFraction, uint lod) {
	pos.xz += cameraPosition.xz * CLOUDS_SCALE;

	vec2 pos2D = pos.xz * layer.frequency + layer.randomOffset + layer.wind;

	// 2D noise to determine cloud type and coverage
	vec4 noise2D;
	noise2D.xy = texture(noisetex, 0.000002 * pos2D).wx; // cloud coverage, cloud type
	noise2D.zw = texture(noisetex, 0.000027 * pos2D).wx; // noise for base shape

	float coverage             = clamp01(mix(layer.coverage.x,  layer.coverage.y,  linearStep(0.25, 0.75, noise2D.x)));
	float stratusWeight        = clamp01(mix(layer.cloudType.x, layer.cloudType.y, linearStep(0.15, 0.85, noise2D.y)));
	float cumulusHumilisWeight = clamp01(mix(layer.cloudType.z, layer.cloudType.w, linearStep(0.25, 0.75, noise2D.y)) - stratusWeight) * (1.0 - cube(coverage));
	float cumulusWeight        = clamp01(1.0 - stratusWeight - cumulusHumilisWeight);

	float density = mix(noise2D.z, noise2D.w * 0.5 + 0.4, 0.8 * stratusWeight);
	      density = linearStep(1.0 - coverage, 1.0, density);

	// Attenuate and erode density over altitude
	altitudeFraction *= 0.75 * cumulusWeight + 1.2 * cumulusHumilisWeight + 1.25 * sqr(stratusWeight);
	const vec4 cloudGradient = vec4(0.2, 0.2, 0.85, 0.2);
	density *= smoothstep(0.0, cloudGradient.x, altitudeFraction);
	density *= smoothstep(0.0, cloudGradient.y, 1.0 - altitudeFraction);
	density -= smoothstep(cloudGradient.z, 1.0, 1.0 - altitudeFraction) * 0.1;
	density -= smoothstep(cloudGradient.w, 1.0, altitudeFraction) * 0.6;

	if (density < eps) return 0.0;

	// Curl noise used to warp the 3D noise into swirling shapes
	vec3 curl = 0.181 * layer.curlStrength * texture(depthtex2, 0.002 * pos).xyz * smoothstep(0.4, 1.0, 1.0 - altitudeFraction);

	// 3D worley noise for detail
	const uint detailIterations = 2;
	float detailAmplitude = 0.4 * cumulusWeight + 0.6 * cumulusHumilisWeight + 0.4 * stratusWeight;
	float detailFrequency = 0.00108 * layer.frequency;
	float detailFade = 0.6 - 0.35 * smoothstep(0.05, 0.5, altitudeFraction);

	for (uint i = lod; i < detailIterations; ++i) {
		pos.xz += 1.2 * layer.wind;

		float worley3D = texture(depthtex0, pos * detailFrequency + curl).x;
		density -= sqr(worley3D) * detailAmplitude * layer.detailStrength * dampen(clamp01(1.0 - density));

		detailAmplitude *= detailFade;
		detailFrequency *= 6.0;
		curl *= 3.0;
	}

	// Account for remaining detail iterations
	for (uint i = 0u; i < min(lod, detailIterations); ++i) {
		density -= detailAmplitude * 0.25 * dampen(clamp01(1.0 - density));
		detailAmplitude *= detailFade;
	}

	if (density < eps) return 0.0;

	// Adjust density so that the clouds are wispy at the bottom and hard at the top
	density  = 1.0 - pow(1.0 - density, 3.0 + 5.0 * altitudeFraction - 2.0 * stratusWeight);
	density *= 0.1 + 0.9 * smoothstep(0.2, 0.7, altitudeFraction);

	return density;
}

float cloudVolumeOpticalDepth(
	CloudLayer layer,
	vec3 rayOrigin,
	vec3 rayDir,
	float dither,
	const uint stepCount
) {
	const float stepGrowth = 2.0;

	float stepLength = 0.04 * layer.thickness * (6.0 / float(stepCount));

	vec3 rayPos = rayOrigin;
	vec4 rayStep = vec4(rayDir, 1.0) * stepLength;
	uint lod = 0;

	float opticalDepth = 0.0;

	for (uint i = 0u; i < stepCount; ++i, rayPos += rayStep.xyz) {
		rayStep *= stepGrowth;

		vec3 ditheredPos = rayPos + rayStep.xyz * dither;

		float altitudeFraction = (length(ditheredPos) - layer.radius) * rcp(layer.thickness);
		if (clamp01(altitudeFraction) != altitudeFraction) break;

		opticalDepth += cloudVolumeDensity(layer, ditheredPos, altitudeFraction, lod++) * rayStep.w;
	}

	return opticalDepth;
}

vec2 cloudVolumeScattering(
	CloudLayer layer,
	float density,
	float stepTransmittance,
	float lightOpticalDepth,
	float skyOpticalDepth,
	float groundOpticalDepth,
	float cosTheta,
	float bouncedLight
) {
	vec2 scattering = vec2(0.0);

	float sigmaS = layer.sigmaS;
	float sigmaT = layer.sigmaT;

	float phase = cloudsPhaseSingle(cosTheta);
	vec3 phaseG = pow(vec3(0.6, 0.9, 0.3), vec3(1.0 + lightOpticalDepth));

	float powderEffect = cloudsPowderEffect(density, cosTheta);

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

	float scatteringIntegral = (1.0 - stepTransmittance) / layer.sigmaT;

	return scattering * scatteringIntegral;
}

vec4 renderCloudVolume(
	CloudLayer layer,
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

	vec2 dists = intersectSphericalShell(rayOrigin, rayDir, layer.radius, layer.radius + layer.thickness);

	bool planetIntersected = intersectSphere(rayOrigin, rayDir, min(r - 10.0, planetRadius)).y >= 0.0;
	bool terrainIntersected = distanceToTerrain >= 0.0 && r < layer.radius && distanceToTerrain * CLOUDS_SCALE < dists.y;

	if (dists.y < 0.0                         // volume not intersected
	 || planetIntersected && r < layer.radius // planet blocking clouds
	 || terrainIntersected                    // terrain blocking clouds
	) {
		return vec4(0.0, 0.0, 1.0, 1e6);
	}

	float rayLength = (distanceToTerrain >= 0.0) ? distanceToTerrain : dists.y;
	      rayLength = clamp(rayLength - dists.x, 0.0, maxRayLength);

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

		float altitudeFraction = (length(rayPos) - layer.radius) * rcp(layer.thickness);

		float density = cloudVolumeDensity(layer, rayPos, altitudeFraction, 0);

		if (density < eps) continue;

		// fade away in the distance to hide the cutoff
		float distanceToSample = distance(rayOrigin, rayPos);
		float distanceFade = smoothstep(0.95, 1.0, (distanceToSample - dists.x) * rcp(maxRayLength));

		density *= 1.0 - distanceFade;

		vec4 hash = hash4(fract(rayPos)); // used to dither the light rays
		vec3 skyRayDir = cosineWeightedHemisphereSample(vec3(0.0, 1.0, 0.0), hash.xy);

		float lightOpticalDepth  = cloudVolumeOpticalDepth(layer, rayPos, lightDir, hash.z, lightingSteps);
		float skyOpticalDepth    = cloudVolumeOpticalDepth(layer, rayPos, skyRayDir, hash.w, ambientSteps);
		float groundOpticalDepth = mix(density, 1.0, clamp01(altitudeFraction * 2.0 - 1.0)) * altitudeFraction * layer.thickness; // guess optical depth to ground using altitude fraction and density from this sample

		float stepOpticalDepth = density * layer.sigmaT * stepLength;
		float stepTransmittance = exp(-stepOpticalDepth);

		scattering += cloudVolumeScattering(
			layer,
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

// from https://iquilezles.org/articles/gradientnoise/
vec2 perlinGradient(vec2 coord) {
	vec2 i = floor(coord);
	vec2 f = fract(coord);

	vec2 u  = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	vec2 du = 30.0 * f * f * ( f *( f - 2.0) + 1.0);

	vec2 g0 = hash2(i + vec2(0.0, 0.0));
	vec2 g1 = hash2(i + vec2(1.0, 0.0));
	vec2 g2 = hash2(i + vec2(0.0, 1.0));
	vec2 g3 = hash2(i + vec2(1.0, 1.0));

	float v0 = dot(g0, f - vec2(0.0, 0.0));
	float v1 = dot(g1, f - vec2(1.0, 0.0));
	float v2 = dot(g2, f - vec2(0.0, 1.0));
	float v3 = dot(g3, f - vec2(1.0, 1.0));

	return vec2(
		g0 + u.x * (g1 - g0) + u.y * (g2 - g0) + u.x * u.y * (g0 - g1 - g2 + g3) + // d/dx
		du * (u.yx * (v0 - v1 - v2 + v3) + vec2(v1, v2) - v0)                      // d/dy
	);
}

vec2 curl2D(vec2 coord) {
	vec2 gradient = perlinGradient(coord);
	return vec2(gradient.y, -gradient.x);
}

float cloudPlaneDensity(CloudLayer layer, vec2 coord, float altitudeFraction) {
	coord = coord + cameraPosition.xz * CLOUDS_SCALE;
	coord = coord * layer.frequency + layer.wind + layer.randomOffset;

	vec2 curl = 0.5 * curl2D(0.00002 * coord)
	          + 0.25 * curl2D(0.00004 * coord)
			  + 0.125 * curl2D(0.00008 * coord);

	curl *= layer.curlStrength;

	float density = 0.0;
	float heightShaping = 1.0 - abs(1.0 - 2.0 * altitudeFraction);

	/* -- cirrus clouds -- */

	if (layer.coverage.x > eps) {
		float cirrus = 0.7 * texture(noisetex, 0.000002 * coord + 0.004 * curl).x
		              + 0.3 * texture(noisetex, 0.000008 * coord + 0.008 * curl).x;
		      cirrus = linearStep(0.7 - layer.coverage.x, 1.0, cirrus);

		float detailAmplitude = 0.2 * layer.detailStrength;
		float detailFrequency = 0.00002;
		float curlStrength    = 0.1;

		for (int i = 0; i < 4; ++i) {
			float detail = texture(noisetex, coord * detailFrequency + curl * curlStrength).x;

			cirrus -= detail * detailAmplitude;

			detailAmplitude *= 0.6;
			detailFrequency *= 2.0;
			curlStrength *= 4.0;

			coord += 0.3 * layer.wind;
		}

		density += cube(max0(cirrus)) * heightShaping;
	}

	/* -- cirrocumulus clouds -- */

	if (layer.coverage.y > eps) {
		float coverage = texture(noisetex, 0.000002 * coord + 0.004 * curl).w;
		      coverage = layer.coverage.y * linearStep(0.5, 0.6, coverage);

		float cirrocumulus = texture(noisetex, 0.00003 * coord + 0.1 * curl).w;
		      cirrocumulus = linearStep(1.0 - coverage, 1.0, cirrocumulus);

		// detail
		cirrocumulus -= 0.2 * texture(noisetex, coord * 0.00005 + 0.1 * curl).y * layer.detailStrength;
		cirrocumulus -= 0.1 * texture(noisetex, coord * 0.00010 + 0.4  * curl).y * layer.detailStrength;

		density += cube(max0(cirrocumulus)) * dampen(heightShaping);
	}

	return density * heightShaping;
}

float cloudPlaneOpticalDepth(
	CloudLayer layer,
	vec3 rayOrigin,
	vec3 rayDir,
	float dither,
	const uint stepCount
) {
	const float maxRayLength = 1e3;
	const float stepGrowth   = 1.5;

	// assuming rayOrigin is between inner and outer boundary, find distance to closest layer
	// boundary
	vec2 innerSphere = intersectSphere(rayOrigin, rayDir, layer.radius - 0.5 * layer.thickness);
	vec2 outerSphere = intersectSphere(rayOrigin, rayDir, layer.radius + 0.5 * layer.thickness);
	float rayLength = (innerSphere.y >= 0.0) ? innerSphere.x : outerSphere.y;
	      rayLength = min(rayLength, maxRayLength);

	// find initial step length a so that Σ(ar^i) = rayLength
	float stepCoeff = (stepGrowth - 1.0) / (pow(stepGrowth, float(stepCount)) - 1.0) / stepGrowth;
	float stepLength = rayLength * stepCoeff;

	vec3 rayPos  = rayOrigin;
	vec4 rayStep = vec4(rayDir, 1.0) * stepLength;

	float opticalDepth = 0.0;

	for (uint i = 0u; i < stepCount; ++i, rayPos += rayStep.xyz) {
		rayStep *= stepGrowth;

		vec3 ditheredPos = rayPos + rayStep.xyz * dither;

		float altitudeFraction = (length(ditheredPos) - layer.radius) * rcp(layer.thickness) + 0.5;

		opticalDepth += cloudPlaneDensity(layer, ditheredPos.xz, altitudeFraction) * rayStep.w;
	}

	return opticalDepth;
}

vec2 cloudPlaneScattering(
	CloudLayer layer,
	float density,
	float viewTransmittance,
	float lightOpticalDepth,
	float cosTheta,
	float bouncedLight
) {
	vec2 scattering = vec2(0.0);

	float sigmaS = layer.sigmaS;
	float sigmaT = layer.sigmaT;

	float phase = cloudsPhaseSingle(cosTheta);
	vec3 phaseG = vec3(0.6, 0.9, 0.3);

	float powderEffect = 4.0 * (1.0 - exp(-8.0 * density));
	      powderEffect = mix(powderEffect, 1.0, cosTheta * 0.5 + 0.5);

	for (uint i = 0u; i < 8u; ++i) {
		scattering.x += sigmaS * exp(-sigmaT * lightOpticalDepth) * phase * powderEffect; // direct light
		scattering.y += sigmaS * exp(-0.33 * layer.thickness * sigmaT * density) * isotropicPhase; // direct light

		sigmaS *= 0.5;
		sigmaT *= 0.5;
		phaseG *= 0.8;

		phase = cloudsPhaseMulti(cosTheta, phaseG);
	}

	float scatteringIntegral = (1.0 - viewTransmittance) / layer.sigmaT;
	return scattering * scatteringIntegral;
}

vec4 renderCloudPlane(
	CloudLayer layer,
	vec3 rayOrigin,
	vec3 rayDir,
	vec3 lightDir,
	float dither,
	float distanceToTerrain,
	float cosTheta,
	float bouncedLight,
	uint lightingSteps
) {
	/* -- ray casting -- */

	float r = length(rayOrigin);

	vec2 dists = intersectSphere(rayOrigin, rayDir, layer.radius);

	bool planetIntersected = intersectSphere(rayOrigin, rayDir, min(r - 10.0, planetRadius)).y >= 0.0;
	bool terrainIntersected = distanceToTerrain >= 0.0 && r < layer.radius && distanceToTerrain < dists.y;

	if (dists.y < 0.0                         // plane not intersected
	 || planetIntersected && r < layer.radius // planet blocking clouds
	 || terrainIntersected                    // terrain blocking clouds
	) {
		return vec4(0.0, 0.0, 1.0, 1e6);
	}

	float distanceToSphere = (r < layer.radius) ? dists.y : dists.x;
	vec3 spherePos = rayOrigin + rayDir * distanceToSphere;

	/* -- cloud lighting -- */

	float density = cloudPlaneDensity(layer, spherePos.xz, 0.5);
	if (density < eps) return vec4(0.0, 0.0, 1.0, 1e6);

	float lightOpticalDepth  = cloudPlaneOpticalDepth(layer, spherePos, lightDir, dither, lightingSteps);
	float viewOpticalDepth   = density * layer.sigmaT * layer.thickness * rcp(abs(rayDir.y) + eps);
	float viewTransmittance  = exp(-viewOpticalDepth);

	vec2 scattering = cloudPlaneScattering(layer, density, viewTransmittance, lightOpticalDepth, cosTheta, bouncedLight);

	return vec4(scattering, viewTransmittance, distanceToSphere);
}

/* -- */

vec4 renderClouds(
	vec3 rayOrigin,
	vec3 rayDir,
	vec3 lightDir,
	float dither,
	float distanceToTerrain,
	bool isReflection
) {
	const float groundAlbedo = 0.4;

	/*
	 * x: sunlight
	 * y: skylight
	 * z: transmittance
	 * w: distance to cloud
	 */

	vec4 result = vec4(0.0, 0.0, 1.0, 1e6);
	vec4 resultTemp;

	float cosTheta = dot(rayDir, lightDir);
	float bouncedLight = groundAlbedo * lightDir.y * rcpPi;
	float cloudsScatteringAlbedo = 1.0 - 0.25 * rainStrength;

#ifdef WORLD_TIME_ANIMATION
	float cloudsTime = worldAge;
#else
	float cloudsTime = frameTimeCounter;
#endif

	/* -- volumetric clouds -- */

	CloudLayer layer;

#ifdef CLOUDS_LAYER0 // layer 0 (cumulus, cumulus humilis, stratocumulus, stratus)
	layer.radius         = CLOUDS_LAYER0_ALTITUDE + planetRadius;
	layer.thickness      = CLOUDS_LAYER0_THICKNESS;
	layer.frequency      = CLOUDS_LAYER0_FREQUENCY;
	layer.sigmaT         = cloudsLayer0Density(weather);
	layer.sigmaS         = cloudsScatteringAlbedo * layer.sigmaT;
	layer.coverage       = cloudsLayer0Coverage(weather);
	layer.cloudType      = cloudsLayer0CloudType(weather);
	layer.randomOffset   = vec2(0.0);
	layer.wind           = polar(CLOUDS_LAYER0_WIND_SPEED * cloudsTime, CLOUDS_LAYER0_WIND_ANGLE * degree);
	layer.detailStrength = CLOUDS_LAYER0_WISPINESS;
	layer.curlStrength   = CLOUDS_LAYER0_SWIRLINESS;

	result = renderCloudVolume(
		layer,
		rayOrigin,
		rayDir,
		lightDir,
		dither,
		distanceToTerrain,
		cosTheta,
		bouncedLight,
		CLOUDS_LAYER0_PRIMARY_STEPS,
		CLOUDS_LAYER0_LIGHTING_STEPS
	);

	if (result.z < 0.05) return result;
#endif

#ifdef CLOUDS_LAYER1 // layer 1 (altocumulus, altostratus)
	layer.radius         = CLOUDS_LAYER1_ALTITUDE + planetRadius;
	layer.thickness      = CLOUDS_LAYER1_THICKNESS;
	layer.frequency      = CLOUDS_LAYER1_FREQUENCY;
	layer.sigmaT         = CLOUDS_LAYER1_DENSITY * 0.1;
	layer.sigmaS         = cloudsScatteringAlbedo * layer.sigmaT;
	layer.coverage       = cloudsLayer1Coverage(weather);
	layer.cloudType      = vec4(vec2(CLOUDS_LAYER1_STRATUS_AMOUNT), vec2(CLOUDS_LAYER1_CUMULUS_HUMILIS_AMOUNT));
	layer.randomOffset   = vec2(631210.0, 814172.0);
	layer.wind           = polar(CLOUDS_LAYER1_WIND_SPEED * cloudsTime, CLOUDS_LAYER1_WIND_ANGLE * degree);
	layer.detailStrength = CLOUDS_LAYER1_WISPINESS;
	layer.curlStrength   = CLOUDS_LAYER1_SWIRLINESS;

	resultTemp = renderCloudVolume(
		layer,
		rayOrigin,
		rayDir,
		lightDir,
		dither,
		distanceToTerrain,
		cosTheta,
		bouncedLight,
		CLOUDS_LAYER1_PRIMARY_STEPS,
		CLOUDS_LAYER1_LIGHTING_STEPS
	);

	result.xy = result.xy + result.z * resultTemp.xy;
	result.z *= resultTemp.z;
	result.w  = min(result.w, resultTemp.w);

	if (result.z < 0.05) return result;
#endif

	/* -- planar clouds -- */

	float cirrusCoverage = cloudsCirrusCoverage(weather);
	float cirrocumulusCoverage = cloudsCirrocumulusCoverage(weather);

#ifdef CLOUDS_LAYER2 // layer 2 (cirrocumulus)
	layer.radius         = CLOUDS_LAYER2_ALTITUDE + planetRadius;
	layer.thickness      = CLOUDS_LAYER2_THICKNESS;
	layer.frequency      = CLOUDS_LAYER2_FREQUENCY;
	layer.sigmaT         = CLOUDS_LAYER2_DENSITY * 0.1;
	layer.sigmaS         = CLOUDS_LAYER2_DENSITY * 0.1;
	layer.cloudType      = vec4(vec2(CLOUDS_LAYER2_STRATUS_AMOUNT), vec2(CLOUDS_LAYER2_CUMULUS_HUMILIS_AMOUNT));
	layer.randomOffset   = vec2(-659843.0, 234920.0);
	layer.wind           = polar(CLOUDS_LAYER2_WIND_SPEED * cloudsTime, CLOUDS_LAYER2_WIND_ANGLE * degree);
	layer.detailStrength = CLOUDS_LAYER2_WISPINESS;
	layer.curlStrength   = CLOUDS_LAYER2_SWIRLINESS;

#if CLOUDS_LAYER2_MODE == CLOUDS_MODE_PLANAR
	layer.coverage.x = CLOUDS_LAYER2_COVERAGE * CLOUDS_LAYER2_CIRRUS_AMOUNT * mix(1.0, cirrusCoverage, CLOUDS_LAYER2_WEATHER_INFLUENCE);
	layer.coverage.y = CLOUDS_LAYER2_COVERAGE * CLOUDS_LAYER2_CIRROCUMULUS_AMOUNT * mix(1.0, cirrocumulusCoverage, CLOUDS_LAYER2_WEATHER_INFLUENCE);

	resultTemp = renderCloudPlane(
		layer,
		rayOrigin,
		rayDir,
		lightDir,
		dither,
		distanceToTerrain,
		cosTheta,
		bouncedLight,
		CLOUDS_LAYER2_LIGHTING_STEPS
	);
#else
	layer.coverage  = vec2(CLOUDS_LAYER2_COVERAGE) * mix(1.0, cirrocumulusCoverage, CLOUDS_LAYER2_WEATHER_INFLUENCE);
	layer.coverage += vec2(-0.2, 0.2) * CLOUDS_LAYER2_LOCAL_COVERAGE_VARIATION;

	resultTemp = renderCloudVolume(
		layer,
		rayOrigin,
		rayDir,
		lightDir,
		dither,
		distanceToTerrain,
		cosTheta,
		bouncedLight,
		CLOUDS_LAYER2_PRIMARY_STEPS,
		CLOUDS_LAYER2_LIGHTING_STEPS
	);
#endif

	result.xy = result.xy + result.z * resultTemp.xy;
	result.z *= resultTemp.z;
	result.w  = min(result.w, resultTemp.w);

	if (result.z < 0.05) return result;
#endif

#ifdef CLOUDS_LAYER3 // layer 3 (cirrus)
	layer.radius         = CLOUDS_LAYER3_ALTITUDE + planetRadius;
	layer.thickness      = CLOUDS_LAYER3_THICKNESS;
	layer.frequency      = CLOUDS_LAYER3_FREQUENCY;
	layer.sigmaT         = CLOUDS_LAYER3_DENSITY * 0.1;
	layer.sigmaS         = CLOUDS_LAYER3_DENSITY * 0.1;
	layer.cloudType      = vec4(vec2(CLOUDS_LAYER3_STRATUS_AMOUNT), vec2(CLOUDS_LAYER3_CUMULUS_HUMILIS_AMOUNT));
	layer.coverage       = vec2(CLOUDS_LAYER3_COVERAGE);
	layer.randomOffset   = vec2(-979530.0, -122390.0);
	layer.wind           = polar(CLOUDS_LAYER3_WIND_SPEED * cloudsTime, CLOUDS_LAYER3_WIND_ANGLE * degree);
	layer.detailStrength = CLOUDS_LAYER3_WISPINESS;
	layer.curlStrength   = CLOUDS_LAYER3_SWIRLINESS;


#if CLOUDS_LAYER3_MODE == CLOUDS_MODE_PLANAR
	layer.coverage.x = CLOUDS_LAYER3_COVERAGE * CLOUDS_LAYER3_CIRRUS_AMOUNT * mix(1.0, cirrusCoverage, CLOUDS_LAYER3_WEATHER_INFLUENCE);
	layer.coverage.y = CLOUDS_LAYER3_COVERAGE * CLOUDS_LAYER3_CIRROCUMULUS_AMOUNT * mix(1.0, cirrocumulusCoverage, CLOUDS_LAYER3_WEATHER_INFLUENCE);

	resultTemp = renderCloudPlane(
		layer,
		rayOrigin,
		rayDir,
		lightDir,
		dither,
		distanceToTerrain,
		cosTheta,
		bouncedLight,
		CLOUDS_LAYER3_LIGHTING_STEPS
	);
#else
	layer.coverage = vec2(CLOUDS_LAYER3_COVERAGE) * mix(1.0, cirrocumulusCoverage, CLOUDS_LAYER3_WEATHER_INFLUENCE);

	resultTemp = renderCloudVolume(
		layer,
		rayOrigin,
		rayDir,
		lightDir,
		dither,
		distanceToTerrain,
		cosTheta,
		bouncedLight,
		CLOUDS_LAYER3_PRIMARY_STEPS,
		CLOUDS_LAYER3_LIGHTING_STEPS
	);
#endif

	result.xy = result.xy + result.z * resultTemp.xy;
	result.z *= resultTemp.z;
	result.w  = min(result.w, resultTemp.w);

	if (result.z < 0.05) return result;
#endif

	return result;
}

/* -- cloud shadows -- */

float cloudVolumeShadow(CloudLayer layer, vec3 rayOrigin, vec3 rayDir) {
	const uint stepCount = 8;

	vec2 dists   = intersectSphericalShell(rayOrigin, rayDir, layer.radius, layer.radius + layer.thickness);
	     dists.x = max0(dists.x);

	float rayLength = dists.y - dists.x;
	float stepLength = rayLength * rcp(float(stepCount));

	vec3 rayPos = rayOrigin + rayDir * (dists.x + 0.5 * stepLength);
	vec3 rayStep = rayDir * stepLength;

	float opticalDepth = 0.0;

	for (uint i = 0u; i < stepCount; ++i, rayPos += rayStep) {
		float altitudeFraction = (length(rayPos) - layer.radius) * rcp(layer.thickness);
		opticalDepth += cloudVolumeDensity(layer, rayPos, altitudeFraction, 10);
	}

	return exp(-layer.sigmaT * opticalDepth * stepLength);
}

float cloudPlaneShadow(CloudLayer layer, vec3 rayOrigin, vec3 rayDir) {
	const float planarCloudShadowDarkness = 0.7;

	vec2 t = intersectSphere(rayOrigin, rayDir, layer.radius);
	vec3 spherePos = rayOrigin + rayDir * t.y;

	float density = cloudPlaneDensity(layer, spherePos.xz, 0.0);
	float opticalDepth = density * layer.sigmaT * layer.thickness * rcp(abs(rayDir.y) + eps);

	return exp(-layer.sigmaT * opticalDepth) * planarCloudShadowDarkness + (1.0 - planarCloudShadowDarkness);
}

float getCloudShadows(vec3 rayOrigin, vec3 rayDir) {
	vec3 weather = getWeather();
	float result = 1.0;

#ifdef WORLD_TIME_ANIMATION
	float cloudsTime = worldAge;
#else
	float cloudsTime = frameTimeCounter;
#endif

	/* -- volumetric clouds -- */

	CloudLayer layer;

#if defined CLOUDS_LAYER0 && defined CLOUDS_LAYER0_SHADOW // layer 0 (cumulus, cumulus humilis, stratocumulus, stratus)
	layer.radius         = CLOUDS_LAYER0_ALTITUDE + planetRadius;
	layer.thickness      = CLOUDS_LAYER0_THICKNESS;
	layer.frequency      = CLOUDS_LAYER0_FREQUENCY;
	layer.sigmaT         = cloudsLayer0Density(weather);
	layer.sigmaS         = 0.0;
	layer.coverage       = cloudsLayer0Coverage(weather);
	layer.cloudType      = cloudsLayer0CloudType(weather);
	layer.randomOffset   = vec2(0.0);
	layer.wind           = polar(CLOUDS_LAYER0_WIND_SPEED * cloudsTime, CLOUDS_LAYER0_WIND_ANGLE * degree);
	layer.detailStrength = CLOUDS_LAYER0_WISPINESS;
	layer.curlStrength   = CLOUDS_LAYER0_SWIRLINESS;

	result = cloudVolumeShadow(layer, rayOrigin, rayDir);

	if (result < 0.01) return 0.0;
#endif

#if defined CLOUDS_LAYER1 && defined CLOUDS_LAYER1_SHADOW // layer 1 (altocumulus, altostratus)
	layer.radius         = CLOUDS_LAYER1_ALTITUDE + planetRadius;
	layer.thickness      = CLOUDS_LAYER1_THICKNESS;
	layer.frequency      = CLOUDS_LAYER1_FREQUENCY;
	layer.sigmaT         = CLOUDS_LAYER1_DENSITY * 0.1;
	layer.sigmaS         = 0.0;
	layer.coverage       = cloudsLayer1Coverage(weather);
	layer.cloudType      = vec4(vec2(CLOUDS_LAYER1_STRATUS_AMOUNT), vec2(CLOUDS_LAYER1_CUMULUS_HUMILIS_AMOUNT));
	layer.randomOffset   = vec2(631210.0, 814172.0);
	layer.wind           = polar(CLOUDS_LAYER1_WIND_SPEED * cloudsTime, CLOUDS_LAYER1_WIND_ANGLE * degree);
	layer.detailStrength = CLOUDS_LAYER1_WISPINESS;
	layer.curlStrength   = CLOUDS_LAYER1_SWIRLINESS;

	result *= cloudVolumeShadow(layer, rayOrigin, rayDir);

	if (result < 0.01) return 0.0;
#endif

	/* -- planar clouds -- */

	float cirrusCoverage = cloudsCirrusCoverage(weather);
	float cirrocumulusCoverage = cloudsCirrocumulusCoverage(weather);

#if defined CLOUDS_LAYER2 && defined CLOUDS_LAYER2_SHADOW // layer 2 (cirrocumulus)
	layer.radius       = CLOUDS_LAYER2_ALTITUDE + planetRadius;
	layer.thickness    = CLOUDS_LAYER2_THICKNESS;
	layer.frequency    = CLOUDS_LAYER2_FREQUENCY;
	layer.sigmaT       = CLOUDS_LAYER2_DENSITY * 0.1;
	layer.sigmaS       = 0.0;
	layer.cloudType    = vec4(vec2(CLOUDS_LAYER2_STRATUS_AMOUNT), vec2(CLOUDS_LAYER2_CUMULUS_HUMILIS_AMOUNT));
	layer.randomOffset = vec2(-659843.0, 234920.0);
	layer.wind         = polar(CLOUDS_LAYER2_WIND_SPEED * cloudsTime, CLOUDS_LAYER2_WIND_ANGLE * degree);
	layer.detailStrength = CLOUDS_LAYER2_WISPINESS;
	layer.curlStrength   = CLOUDS_LAYER2_SWIRLINESS;

#if CLOUDS_LAYER2_MODE == CLOUDS_MODE_PLANAR
	layer.coverage.x = CLOUDS_LAYER2_COVERAGE * CLOUDS_LAYER2_CIRRUS_AMOUNT * mix(1.0, cirrusCoverage, CLOUDS_LAYER2_WEATHER_INFLUENCE);
	layer.coverage.y = CLOUDS_LAYER2_COVERAGE * CLOUDS_LAYER2_CIRROCUMULUS_AMOUNT * mix(1.0, cirrocumulusCoverage, CLOUDS_LAYER2_WEATHER_INFLUENCE);

	result *= cloudPlaneShadow(layer, rayOrigin, rayDir);
#else
	layer.coverage  = vec2(CLOUDS_LAYER2_COVERAGE) * mix(1.0, cirrocumulusCoverage, CLOUDS_LAYER2_WEATHER_INFLUENCE);
	layer.coverage += vec2(-0.2, 0.2) * CLOUDS_LAYER2_LOCAL_COVERAGE_VARIATION;
	layer.coverage  = clamp01(layer.coverage);

	result *= cloudVolumeShadow(layer, rayOrigin, rayDir);
#endif

	if (result < 0.01) return 0.0;
#endif

#if defined CLOUDS_LAYER3 && defined CLOUDS_LAYER3_SHADOW // layer 3 (cirrus)
	layer.radius       = CLOUDS_LAYER3_ALTITUDE + planetRadius;
	layer.thickness    = CLOUDS_LAYER3_THICKNESS;
	layer.frequency    = CLOUDS_LAYER3_FREQUENCY;
	layer.sigmaT       = CLOUDS_LAYER3_DENSITY * 0.1;
	layer.sigmaS       = 0.0;
	layer.cloudType    = vec4(vec2(CLOUDS_LAYER3_STRATUS_AMOUNT), vec2(CLOUDS_LAYER3_CUMULUS_HUMILIS_AMOUNT));
	layer.coverage     = vec2(CLOUDS_LAYER3_COVERAGE);
	layer.randomOffset = vec2(-979530.0, -122390.0);
	layer.wind         = polar(CLOUDS_LAYER3_WIND_SPEED * cloudsTime, CLOUDS_LAYER3_WIND_ANGLE * degree);
	layer.detailStrength = CLOUDS_LAYER3_WISPINESS;
	layer.curlStrength   = CLOUDS_LAYER3_SWIRLINESS;

#if CLOUDS_LAYER3_MODE == CLOUDS_MODE_PLANAR
	layer.coverage.x = CLOUDS_LAYER3_COVERAGE * CLOUDS_LAYER3_CIRRUS_AMOUNT * mix(1.0, cirrusCoverage, CLOUDS_LAYER3_WEATHER_INFLUENCE);
	layer.coverage.y = CLOUDS_LAYER3_COVERAGE * CLOUDS_LAYER3_CIRROCUMULUS_AMOUNT * mix(1.0, cirrocumulusCoverage, CLOUDS_LAYER3_WEATHER_INFLUENCE);

	result *= cloudPlaneShadow(layer, rayOrigin, rayDir);
#else
	layer.coverage       = vec2(CLOUDS_LAYER3_COVERAGE) * mix(1.0, cirrocumulusCoverage, CLOUDS_LAYER3_WEATHER_INFLUENCE);

	result *= cloudVolumeShadow(layer, rayOrigin, rayDir);
#endif

	if (result < 0.01) return 0.0;
#endif

	return result;
}

#endif // INCLUDE_ATMOSPHERE_CLOUDS
