#if !defined INCLUDE_ATMOSPHERE_CLOUDS
#define INCLUDE_ATMOSPHERE_CLOUDS

#include "/include/atmospherics/atmosphere.glsl"

#include "/include/utility/random.glsl"
#include "/include/utility/sampling.glsl"

struct Ray {
	vec3 origin;
	vec3 dir;
};

struct CloudLayer {
	vec2 offset;
	float radius;
	float thickness;
	float frequency;
	float minCoverage;
	float maxCoverage;
};

struct CloudLightingInfo {
	vec3 lightDir;
	float albedo;
	float density;
	float cosTheta;
	float phaseSun; // Single scattering phase function
	float bouncedLight;
};

//--// volumetric cumulus-style clouds

// Single scattering phase function
float getCloudsPhaseSingle(float cosTheta) {
	return 0.8 * kleinNishinaPhase(cosTheta, 2600.0)
	     + 0.2 * henyeyGreensteinPhase(cosTheta, -0.2);
}

// Multiple scattering phase function
float getCloudsPhaseMulti(float cosTheta, vec3 anisotropy) {
	return 0.7 * henyeyGreensteinPhase(cosTheta,  anisotropy.x)
	     + 0.1 * henyeyGreensteinPhase(cosTheta,  anisotropy.y)
	     + 0.2 * henyeyGreensteinPhase(cosTheta, -anisotropy.z);
}

float getCloudsPowderRatio(float density) {
	return 2.0 * density / (density + 0.15);
}

float getCumulusCloudsDensity(
	CloudLayer layer,
	vec3 pos,
	float altitudeFraction,
	int detailIterations
) {
	altitudeFraction *= 0.75;
	pos.xz = pos.xz * layer.frequency + layer.offset;

	// 2D noise to determine where to place clouds
	vec2 noise2D;
	noise2D.x = texture(noisetex, 0.000002 * pos.xz).x; // perlin noise for local coverage
	noise2D.y = texture(noisetex, 0.000024 * pos.xz * rcp(CLOUDS_CUMULUS_SIZE)).w; // perlin-worley-ish noise for shape

	float density;
	density = clamp01(mix(layer.minCoverage, layer.maxCoverage, noise2D.x));
	density = linearStep(1.0 - density, 1.0, noise2D.y);

	// Attenuate and erode density over altitude
	const vec4 cloudGradient = vec4(0.2, 0.2, 0.85, 0.2);
	density *= smoothstep(0.0, cloudGradient.x, altitudeFraction);
	density *= smoothstep(0.0, cloudGradient.y, 1.0 - altitudeFraction);
	density -= smoothstep(cloudGradient.z, 1.0, 1.0 - altitudeFraction) * 0.2;
	density -= smoothstep(cloudGradient.w, 1.0, altitudeFraction) * 0.6;

	if (density < eps) return 0.0;

	// Curl noise used to warp the 3D noise into swirling shapes
	vec3 curl = 0.1 * texture(depthtex2, 0.002 * pos).xyz * smoothstep(0.4, 1.0, 1.0 - altitudeFraction) * CLOUDS_CUMULUS_SWIRLINESS;

	// 3D worley noise for detail
	float detailAmplitude = 0.5 * CLOUDS_CUMULUS_WISPINESS;
	float detailFrequency = 0.001;
	float detailFade = 0.7 - 0.4 * smoothstep(0.05, 0.3, altitudeFraction);

	for (int i = 0; i < detailIterations; ++i) {
		density -= detailAmplitude * texture(depthtex0, pos * detailFrequency + curl).x * dampen(1.0 - density);
		detailAmplitude *= detailFade;
		detailFrequency *= 8.0;
		curl *= 10.0;
	}

	// Use 0.5 for remaining detail iterations
	for (int i = detailIterations; i < CLOUDS_CUMULUS_DETAIL_ITERATIONS; ++i) {
		density -= detailAmplitude * 0.5 * dampen(1.0 - density);
		detailAmplitude *= detailFade;
	}

	if (density < eps) return 0.0;

	// Adjust density so that the clouds are wispy at the bottom and hard at the top
	density  = 1.0 - pow(1.0 - density, 2.0 + 6.0 * altitudeFraction);
	density *= 0.1 + 0.9 * smoothstep(0.2, 0.6, altitudeFraction);

	return density;
}

float getCumulusCloudsOpticalDepth(Ray ray, CloudLayer layer, float dither, uint stepCount) {
	const float stepGrowth = 2.0;

	vec3 rayPos = ray.origin;
	float stepLength = 0.04 * layer.thickness * (6.0 / float(stepCount));
	float opticalDepth = 0.0;
	int detailIterations = CLOUDS_CUMULUS_DETAIL_ITERATIONS;

	for (uint i = 0; i < stepCount; ++i, rayPos += ray.dir * stepLength) {
		vec3 ditheredPos = rayPos + ray.dir * stepLength * stepGrowth * dither;

		float altitudeFraction = (length(ditheredPos) - layer.radius) * rcp(layer.thickness);
		if (clamp01(altitudeFraction) != altitudeFraction) break;

		opticalDepth += getCumulusCloudsDensity(
			layer,
			ditheredPos,
			altitudeFraction,
			max(detailIterations--, 0)
		) * stepLength;

		stepLength *= stepGrowth;
	}

	return opticalDepth;
}

vec2 getCumulusCloudsScattering(
	CloudLightingInfo lightingInfo,
	float density,
	float stepTransmittance,
	float sunOpticalDepth,
	float skyOpticalDepth,
	float groundOpticalDepth
) {
	float sigmaS = lightingInfo.density * lightingInfo.albedo;
	float sigmaT = lightingInfo.density;

	float powder = 1.0;
	float powderRatio = getCloudsPowderRatio(density);

	vec2 scattering = vec2(0.0);

	float phaseSun = lightingInfo.phaseSun;
	vec3 anisotropy = pow(vec3(0.6, 0.9, 0.3), vec3(1.0 + sunOpticalDepth));

	for (int i = 0; i < 8; ++i) {
		scattering.x += sigmaS * exp(-sigmaT * sunOpticalDepth) * phaseSun * powder;
		scattering.x += sigmaS * exp(-sigmaT * groundOpticalDepth) * lightingInfo.bouncedLight * powder;
		scattering.y += sigmaS * exp(-sigmaT * skyOpticalDepth) * isotropicPhase * powder;

		// Multiple scattering phase function
		anisotropy *= 0.8;
		phaseSun = getCloudsPhaseMulti(lightingInfo.cosTheta, anisotropy);

		sigmaS *= 0.65;
		sigmaT *= 0.5;
		powder *= powderRatio;
		powderRatio = 0.5 * powderRatio + 0.5 * sqrt(powderRatio);
	}

	float scatteringIntegral = (1.0 - stepTransmittance) / lightingInfo.density;

	return scattering * scatteringIntegral;
}

vec4 drawCumulusClouds(
	Ray ray,
	CloudLayer layer,
	CloudLightingInfo lightingInfo,
	float dither,
	float distanceToTerrain,
	uint primaryStepCount
) {
	//--// Raymarching setup

	const float distanceClip = 2e4;
	const float transmittanceThreshold = 0.075; // raymarch is terminated when transmittance is below this threshold

	float rayLength;
	vec2 dists = raySphericalShellIntersection(ray.origin, ray.dir, layer.radius, layer.radius + layer.thickness);
	bool planetIntersected = raySphereIntersection(ray.origin, ray.dir, planetRadius).y >= 0.0 && lengthSquared(ray.origin) > sqr(planetRadius);
	if (dists.y < 0.0 || planetIntersected && ray.origin.y < layer.radius) return vec4(0.0, 0.0, 1.0, 1e6);

	if (distanceToTerrain >= 0.0) {
		rayLength = max0(distanceToTerrain * CLOUDS_SCALE - dists.x);

		if (length(ray.origin) < layer.radius && dists.y - dists.x > rayLength) return vec4(0.0, 0.0, 1.0, 1e6);
	} else {
		rayLength = min(dists.y - dists.x, distanceClip);
	}

	float stepLength = rayLength * rcp(float(primaryStepCount));

	vec3 rayPos = ray.origin + ray.dir * (dists.x + stepLength * dither);
	vec3 rayStep = ray.dir * stepLength;

	vec2 scattering = vec2(0.0); // x = sunlight, y = skylight
	float transmittance = 1.0;

	float distanceToCloud = 0.0; // This will store the distance to the first sample with a non-zero density

	//--// Raymarching loop

	for (uint i = 0; i < primaryStepCount; ++i, rayPos += rayStep) {
		if (transmittance < transmittanceThreshold) break;

		float altitudeFraction = (length(rayPos) - layer.radius) * rcp(layer.thickness);

		float density = getCumulusCloudsDensity(layer, rayPos, altitudeFraction, CLOUDS_CUMULUS_DETAIL_ITERATIONS);

		if (density < eps) continue;

		// Fade away in the distance to hide the cutoff
		float distanceToSample = distance(ray.origin, rayPos);
		float distanceFade = smoothstep(0.95, 1.0, (distanceToSample - dists.x) * rcp(distanceClip));

		density *= 1.0 - distanceFade;

		vec4 hash = hash4(abs(rayPos));

		float sunOpticalDepth = getCumulusCloudsOpticalDepth(
			Ray(rayPos, lightingInfo.lightDir),
			layer,
			hash.x,
			CLOUDS_CUMULUS_LIGHTING_STEPS
		);

		vec3 skyRayDir = cosineWeightedHemisphereSample(vec3(0.0, 1.0, 0.0), hash.yz);

		float skyOpticalDepth = getCumulusCloudsOpticalDepth(
			Ray(rayPos, skyRayDir),
			layer,
			hash.w,
			CLOUDS_CUMULUS_AMBIENT_STEPS
		);

		float groundOpticalDepth = getCumulusCloudsOpticalDepth(
			Ray(rayPos, vec3(0.0, -1.0, 0.0)),
			layer,
			hash.w,
			CLOUDS_CUMULUS_AMBIENT_STEPS
		);

		float stepOpticalDepth = lightingInfo.density * density * stepLength;
		float stepTransmittance = exp(-stepOpticalDepth);

		scattering += getCumulusCloudsScattering(
			lightingInfo,
			density,
			stepTransmittance,
			sunOpticalDepth,
			skyOpticalDepth,
			groundOpticalDepth
		) * transmittance;

		transmittance *= stepTransmittance;

		// Update distance to cloud
		distanceToCloud = distanceToCloud == 0.0 ? distanceToSample : distanceToCloud;
	}

	distanceToCloud = distanceToCloud == 0.0 ? 1e6 : distanceToCloud;

	// Remap transmittance so that transmittanceThreshold is 0
	transmittance = linearStep(transmittanceThreshold, 1.0, transmittance);

	return vec4(scattering, transmittance, distanceToCloud);
}

//--// planar cirrus-style clouds

//--//

vec4 drawClouds(Ray ray, vec3 lightDir, float dither, float distanceToTerrain) {
	/*
	 * x: sunlight
	 * y: skylight
	 * z: transmittance
	 * w: apparent distance
	 */
	vec4 result = vec4(0.0, 0.0, 1.0, 1e6);

#if   CLOUDS_CUMULUS_QUALITY == CLOUDS_CUMULUS_QUALITY_FAST || defined PROGRAM_SKY_CAPTURE
	const float primaryStepCountH = 20.0;
	const float primaryStepCountZ = 12.0;
#elif CLOUDS_CUMULUS_QUALITY == CLOUDS_CUMULUS_QUALITY_FANCY
	const float primaryStepCountH = 36.0;
	const float primaryStepCountZ = 24.0;
#elif CLOUDS_CUMULUS_QUALITY == CLOUDS_CUMULUS_QUALITY_FABULOUS
	const float primaryStepCountH = 80.0;
	const float primaryStepCountZ = 40.0;
#endif

	float primaryStepCount = mix(primaryStepCountH, primaryStepCountZ, abs(ray.dir.y));

	//--// Lighting parameters

	const float groundAlbedo = 0.4; // It could be cool to make this biome-dependent

	CloudLightingInfo lightingInfo;
	lightingInfo.lightDir     = lightDir;
	lightingInfo.albedo       = 1.0 - 0.3 * rainStrength;
	lightingInfo.density      = CLOUDS_CUMULUS_DENSITY * 0.1 * (0.6 + 0.4 * lightDir.y); // Allow light to travel further through the cloud when the sun is nearer the horizon
	lightingInfo.cosTheta     = dot(ray.dir, lightDir);
	lightingInfo.bouncedLight = groundAlbedo * lightDir.y * rcpPi * isotropicPhase;
	lightingInfo.phaseSun     = getCloudsPhaseSingle(lightingInfo.cosTheta);

	//--// Layer parameters

	CloudLayer layer;
	layer.frequency    = 1.0;
	layer.radius       = planetRadius + CLOUDS_CUMULUS_ALTITUDE;
	layer.thickness    = CLOUDS_CUMULUS_ALTITUDE * CLOUDS_CUMULUS_THICKNESS;
	layer.minCoverage  = cloudsCumulusCoverage * CLOUDS_CUMULUS_COVERAGE - CLOUDS_CUMULUS_LOCAL_COVERAGE_VARIATION;
	layer.maxCoverage  = cloudsCumulusCoverage * CLOUDS_CUMULUS_COVERAGE + CLOUDS_CUMULUS_LOCAL_COVERAGE_VARIATION;

	float layerSpacing = CLOUDS_CUMULUS_LAYER_SPACING / CLOUDS_CUMULUS_LAYER_SPACING_FALLOFF;
	float windSpeed    = CLOUDS_CUMULUS_WIND_SPEED;
	float windAngle    = CLOUDS_CUMULUS_WIND_BEARING * tau / 360.0;

	//--//

#ifdef WORLD_TIME_ANIMATION
	float t = worldAge;
#else
	float t = frameTimeCounter;
#endif

	for (int i = 0; i < CLOUDS_CUMULUS_LAYERS; ++i) {
		vec2 wind = windSpeed * vec2(cos(windAngle), sin(windAngle));

		// Random xz offset for this layer, plus wind and camera offset
		layer.offset = 1e4 * R2(i) + wind * t + cameraPosition.xz * CLOUDS_SCALE;

		// Scale primary step count so that fewer steps are taken through thinner layers
		const float layer0Thickness = CLOUDS_CUMULUS_ALTITUDE * CLOUDS_CUMULUS_THICKNESS;
		uint layerStepCount = uint(ceil(float(primaryStepCount) * layer.thickness / layer0Thickness));

		vec4 layerResult = drawCumulusClouds(
			ray,
			layer,
			lightingInfo,
			dither,
			distanceToTerrain,
			layerStepCount
		);

		// Blend with layer below
		result.xy = result.xy + result.z * layerResult.xy;
		result.z *= layerResult.z;
		result.w  = min(result.w, layerResult.w);

		if (result.z < eps) return result;

		// Update layer parameters for next layer
		layer.radius += layerSpacing + layer.thickness;
		layer.thickness *= CLOUDS_CUMULUS_LAYER_THICKNESS_FALLOFF;
		layer.minCoverage = max0(layer.minCoverage * CLOUDS_CUMULUS_LAYER_COVERAGE_FALLOFF);
		layer.maxCoverage = max0(layer.maxCoverage * CLOUDS_CUMULUS_LAYER_COVERAGE_FALLOFF);

		layerSpacing *= CLOUDS_CUMULUS_LAYER_SPACING_FALLOFF;
		windSpeed *= 1.3;
		windAngle += 0.3;
	}

	//--// Cirrus clouds



	// If no cloud encountered, take distance to middle of first cloud layer (helps reprojection a lot)
	if (result.w > 1e5) {
		const float cloudVolumeMiddle = planetRadius + CLOUDS_CUMULUS_ALTITUDE * (1.0 + 0.5 * CLOUDS_CUMULUS_THICKNESS);
		vec2 dists = raySphereIntersection(ray.dir.y, ray.origin.y, cloudVolumeMiddle);
		result.w = ray.origin.y < cloudVolumeMiddle ? dists.y : dists.x;
	}

	return result;
}

//--// cloud shadows

vec2 getCloudShadows(Ray ray) {
	float transmittance = 1.0;
	float density = CLOUDS_CUMULUS_DENSITY * 0.1 * (0.6 + 0.4 * abs(sunDir.y)); // Allow light to travel further through the cloud when the sun is nearer the horizon

	const int stepCount = 8;

	//--// Layer parameters

	CloudLayer layer;
	layer.frequency    = 1.0;
	layer.radius       = planetRadius + CLOUDS_CUMULUS_ALTITUDE;
	layer.thickness    = CLOUDS_CUMULUS_ALTITUDE * CLOUDS_CUMULUS_THICKNESS;
	layer.minCoverage  = cloudsCumulusCoverage * CLOUDS_CUMULUS_COVERAGE - CLOUDS_CUMULUS_LOCAL_COVERAGE_VARIATION;
	layer.maxCoverage  = cloudsCumulusCoverage * CLOUDS_CUMULUS_COVERAGE + CLOUDS_CUMULUS_LOCAL_COVERAGE_VARIATION;

	float layerSpacing = CLOUDS_CUMULUS_LAYER_SPACING / CLOUDS_CUMULUS_LAYER_SPACING_FALLOFF;
	float windSpeed    = CLOUDS_CUMULUS_WIND_SPEED;
	float windAngle    = CLOUDS_CUMULUS_WIND_BEARING * tau / 360.0;

	//--//

#ifdef WORLD_TIME_ANIMATION
	float t = worldAge;
#else
	float t = frameTimeCounter;
#endif

	for (int i = 0; i < CLOUDS_CUMULUS_LAYERS; ++i) {
		vec2 wind = windSpeed * vec2(cos(windAngle), sin(windAngle));

		// Random xz offset for this layer, plus wind and camera offset
		layer.offset = 1e4 * R2(i) + wind * t + cameraPosition.xz * CLOUDS_SCALE;

		vec3 origin = ray.origin + ray.dir * raySphereIntersection(ray.origin, ray.dir, layer.radius).y;
		float opticalDepth = getCumulusCloudsOpticalDepth(Ray(origin, ray.dir), layer, 0.5, stepCount);
		transmittance *= exp(-density * opticalDepth);

		// Update layer parameters for next layer
		layer.radius += layerSpacing + layer.thickness;
		layer.thickness *= CLOUDS_CUMULUS_LAYER_THICKNESS_FALLOFF;
		layer.minCoverage = max0(layer.minCoverage * CLOUDS_CUMULUS_LAYER_COVERAGE_FALLOFF);
		layer.maxCoverage = max0(layer.maxCoverage * CLOUDS_CUMULUS_LAYER_COVERAGE_FALLOFF);

		layerSpacing *= CLOUDS_CUMULUS_LAYER_SPACING_FALLOFF;
		windSpeed *= 1.3;
		windAngle += 0.3;
	}

	return vec2(transmittance, 0.0);
}

#endif // INCLUDE_ATMOSPHERE_CLOUDS
