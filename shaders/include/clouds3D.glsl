#if !defined CLOUDS3D_INCLUDED
#define CLOUDS3D_INCLUDED

const float cloudVolumeRadius    = planetRadius + CLOUDS3D_ALTITUDE;
const float cloudVolumeThickness = CLOUDS3D_ALTITUDE * CLOUDS3D_THICKNESS;

float cloudsPhaseSingle(float cosTheta) { // Single scattering phase function
	return 0.7 * kleinNishinaPhase(cosTheta, 2600.0)    // Forwards lobe
	     + 0.3 * henyeyGreensteinPhase(cosTheta, -0.2); // Backwards lobe
}

float cloudsPhaseMulti(float cosTheta, vec3 g) { // Multiple scattering phase function
	return 0.65 * henyeyGreensteinPhase(cosTheta,  g.x)  // Forwards lobe
	     + 0.10 * henyeyGreensteinPhase(cosTheta,  g.y)  // Forwards peak
	     + 0.25 * henyeyGreensteinPhase(cosTheta, -g.z); // Backwards lobe
}

float clouds3DShape(vec3 pos) {
	float altitudeFraction = (length(pos) - cloudVolumeRadius) * rcp(cloudVolumeThickness);

	pos.xz += cameraPosition.xz * CLOUDS3D_SCALE;

	// 2D noise for base shape and coverage
	vec2 noise2D;
	noise2D.x = texture(noisetex, 0.000002 * pos2D).r; // Cloud coverage
	noise2D.y = texture(noisetex, 0.000027 * pos2D).a; // Cloud shape

	float density;
	density = clamp01(mix(cloudsCumulusCoverage.x, cloudsCumulusCoverage.y, noise2D.x));
	density = linearStep(1.0 - density, 1.0, noise2D.y);

	// Attenuate and erode density over altitude
	const vec4 cloudGradient = vec4(0.2, 0.2, 0.85, 0.2);
	density *= smoothstep(0.0, cloudGradient.x, altitudeFraction);
	density *= smoothstep(0.0, cloudGradient.y, 1.0 - altitudeFraction);
	density -= smoothstep(cloudGradient.z, 1.0, 1.0 - altitudeFraction) * 0.1;
	density -= smoothstep(cloudGradient.w, 1.0, altitudeFraction) * 0.6;

	// Curl noise used to warp the 3D noise into swirling shapes

	// 3D worley noise for detail

	// Adjust density so that the clouds are wispy at the bottom and hard at the top
	density  = 1.0 - pow(1.0 - density, 3.0 + 5.0 * altitudeFraction - 2.0 * stratusWeight);
	density *= 0.1 + 0.9 * smoothstep(0.2, 0.7, altitudeFraction);

	return density;
}

float clouds3DOpticalDepth() {
	const float stepGrowth = 2.0;

	float stepLength = 20.0 / float(stepCount); // m

	vec3 rayPos = rayOrigin;
	vec4 rayStep = vec4(rayDir, 1.0) * stepLength;

	float opticalDepth = 0.0;

	for (uint i = 0u; i < stepCount; ++i, rayPos += rayStep.xyz) {
		rayStep *= stepGrowth;
		opticalDepth += clouds3DShape(rayPos + rayStep.xyz * dither) * rayStep.w;
	}

	return opticalDepth;
}

vec3 clouds3DScattering(
	float cosTheta,
	float scatteringCoeff,
	float extinctionCoeff,
	float stepT,
	float lightTransmittance,
	float skyTransmittance,
	float groundTransmittance,

) {
	vec2 scattering = vec2(0.0);

	float scatteringIntegral = (1.0 - stepT) / extinctionCoeff;

	float phase = cloudsPhaseSingle(cosTheta);
	vec3 phaseG = lift(vec3(0.6, 0.9, 0.3), lightTransmittance - 1.0);

	float powderEffect = cloudsPowderEffect(density, cosTheta);

	for (uint i = 0u; i < 6u; ++i) {
		scattering.x += scatteringCoeff * phase * lightTransmittance;                     // Direct light
		scattering.x += scatteringCoeff * isotropicPhase * groundTransmittance * bounced; // Bounced light
		scattering.y += scatteringCoeff * isotropicPhase * skyTransmittance;              // Skylight

		scatteringCoeff *= 0.6 * powderEffect;

		lightTransmittance  = dampen(lightTransmittance);
		groundTransmittance = dampen(groundTransmittance);
		skyTransmittance    = dampen(skyTransmittance);

		phaseG *= 0.8;
		powderEffect = mix(powderEffect, dampen(powderEffect), 0.5);

		phase = cloudsPhaseMulti(cosTheta, phaseG);
	}

	return scattering * scatteringIntegral;
}

vec4 draw3DClouds() {
	// ---------------------
	//   Raymarching Setup
	// ---------------------

	const uint  lightingSteps      = 4;
	const uint  ambientSteps       = 2;
	const float maxRayLength       = 2e4;
	const float minTransmittance   = 0.075;
	const float primaryStepsScaleH = 1.0;
	const float primaryStepsScaleV = 0.5;
	const vec3  skyDir             = vec3(0.0, 1.0, 0.0);

	primarySteps = uint(float(primarySteps) * mix(primaryStepsScaleH, primaryStepsScaleV, abs(rayDir.y))); // Take fewer steps when the ray points vertically

	vec2 dists = intersectSphericalShell(rayOrigin, rayDir, cloudVolumeRadius, cloudVolumeRadius + cloudVolumeThickness);

	float altitude = length(rayOrigin);
	bool planetIntersected = intersectSphere(rayOrigin, rayDir, min(altitude - 10.0, planetRadius)).y >= 0.0;
	bool terrainIntersected = distanceToTerrain >= 0.0 && altitude < cloudVolumeRadius && distanceToTerrain * CLOUDS_SCALE < dists.y;

	if (dists.y < 0.0                         // volume not intersected
	 || planetIntersected && r < layer.radius // planet blocking clouds
	 || terrainIntersected                    // terrain blocking clouds
	) {
		return vec4(0.0, 0.0, 0.0, 1.0);
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

	// --------------------
	//   Raymarching Loop
	// --------------------

	for (uint i = 0u; i < primarySteps; ++i, rayPos += rayStep) {
		if (transmittance < minTransmittance) break;

		float altitudeFraction = (length(rayPos) - layer.radius) * rcp(layer.thickness);

		float density = cloudVolumeDensity(rayPos);

		if (density < eps) continue;

		// Fade out in the distance to hide the cutoff
		float distanceToSample = distance(rayOrigin, rayPos);
		float distanceFade = smoothstep(0.95, 1.0, (distanceToSample - dists.x) * rcp(maxRayLength));

		density *= 1.0 - distanceFade;

		float stepOpticalDepth = density * layer.sigmaT * stepLength;
		float stepTransmittance = exp(-stepOpticalDepth);

		scattering += cloudVolumeScattering(
		) * transmittance;

		vec2 hash = hash2(fract(rayPos)); // used to dither the light rays

		float lightOpticalDepth  = clouds3DOpticalDepth(rayPos, lightDir, hash.x, lightingSteps);
		float skyOpticalDepth    = clouds3DOpticalDepth(rayPos, skyDir, hash.y, ambientSteps);
		float groundOpticalDepth = mix(density, 1.0, clamp01(altitudeFraction * 2.0 - 1.0)) * altitudeFraction * layer.thickness; // Guess optical depth to the ground using altitude fraction and density from this sample

		float lightTransmittance  = exp2();
		float skyTransmittance    = exp2();
		float groundTransmittance = exp2();

		transmittance *= stepTransmittance;

		// Update distance to cloud
		distanceSum += distanceToSample * density;
		distanceWeightSum += density;
	}

	// Eemap the transmittance so that minTransmittance is 0
	transmittance = linearStep(minTransmittance, 1.0, transmittance);
}

#endif // CLOUDS3D_INCLUDED
