#if !defined GTAO_INCLUDED
#define GTAO_INCLUDED

#define GTAO_SLICES        2
#define GTAO_HORIZON_STEPS 3
#define GTAO_RADIUS        2.0
#define GTAO_FALLOFF_START 0.75

float integrateArc(vec2 h, float n, float cosN) {
	vec2 tmp = cosN + 2.0 * h * sin(n) - cos(2.0 * h - n);
	return 0.25 * (tmp.x + tmp.y);
}

float calculateMaximumHorizonAngle(
	vec3 viewSliceDir,
	vec3 viewerDir,
	vec3 screenPos,
	vec3 viewPos,
	float dither
) {
	const float stepSize = GTAO_RADIUS * rcp(float(GTAO_HORIZON_STEPS));

	float maxCosTheta = -1.0;

	vec2 rayStep = (viewToScreenSpace(viewPos + viewSliceDir * stepSize, true) - screenPos).xy;
	vec2 rayPos = screenPos.xy + rayStep * (dither + maxOf(texelSize) * rcpLength(rayStep));

	for (int i = 0; i < GTAO_HORIZON_STEPS; ++i, rayPos += rayStep) {
		float depth = texelFetch(depthtex1, ivec2(clamp01(rayPos) * viewSize * taauRenderScale - 0.5), 0).x;

		if (isSky(depth) || isHand(depth) || depth == screenPos.z) continue;

		vec3 offset = screenToViewSpace(vec3(rayPos, depth), true) - viewPos;

		float lenSq = lengthSquared(offset);
		float norm = inversesqrt(lenSq);

		float distanceFalloff = linearStep(GTAO_FALLOFF_START * GTAO_RADIUS, GTAO_RADIUS, lenSq * norm);

		float cosTheta = dot(viewerDir, offset) * norm;
		      cosTheta = mix(cosTheta, -1.0, distanceFalloff);

		maxCosTheta = max(cosTheta, maxCosTheta);
	}

	return fastAcos(clamp(maxCosTheta, -1.0, 1.0));
}

vec4 calculateGtao(vec3 screenPos, vec3 viewPos, vec3 viewNormal, vec2 dither) {
	float ao = 0.0;
	vec3 bentNormal = vec3(0.0);

	// Construct local working space
	vec3 viewerDir   = normalize(-viewPos);
	vec3 viewerRight = normalize(cross(vec3(0.0, 1.0, 0.0), viewerDir));
	vec3 viewerUp    = cross(viewerDir, viewerRight);
	mat3 localToView = mat3(viewerRight, viewerUp, viewerDir);

	for (int i = 0; i < GTAO_SLICES; ++i) {
		float sliceAngle = (i + dither.x) * (pi / float(GTAO_SLICES));

		vec3 sliceDir = vec3(cos(sliceAngle), sin(sliceAngle), 0.0);
		vec3 viewSliceDir = localToView * sliceDir;

		vec3 orthoDir = sliceDir - dot(sliceDir, viewerDir) * viewerDir;
		vec3 axis = cross(sliceDir, viewerDir);
		vec3 projectedNormal = viewNormal - axis * dot(viewNormal, axis);

		float lenSq = dot(projectedNormal, projectedNormal);
		float norm = inversesqrt(lenSq);

		float sgnGamma = sign(dot(orthoDir, projectedNormal));
		float cosGamma = clamp01(dot(projectedNormal, viewerDir) * norm);
		float gamma = sgnGamma * fastAcos(cosGamma);

		vec2 maxHorizonAngles;
		maxHorizonAngles.x = calculateMaximumHorizonAngle(-viewSliceDir, viewerDir, screenPos, viewPos, dither.y);
		maxHorizonAngles.y = calculateMaximumHorizonAngle( viewSliceDir, viewerDir, screenPos, viewPos, dither.y);

		maxHorizonAngles = gamma + clamp(vec2(-1.0, 1.0) * maxHorizonAngles - gamma, -halfPi, halfPi);
		ao += integrateArc(maxHorizonAngles, gamma, cosGamma) * lenSq * norm;

		float bentAngle = dot(maxHorizonAngles, vec2(0.5));
		bentNormal += viewerDir * cos(bentAngle) + orthoDir * sin(bentAngle);
	}

	const float albedo = 0.2; // albedo of surroundings (for multibounce approx)

	ao *= rcp(float(GTAO_SLICES));
	ao /= albedo * ao + (1.0 - albedo);

	bentNormal = normalize(normalize(bentNormal) - 0.5 * viewerDir);

	return vec4(bentNormal, ao);
}

#endif // GTAO_INCLUDED
