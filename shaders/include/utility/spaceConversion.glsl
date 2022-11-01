#if !defined UTILITY_SPACECONVERSION_INCLUDED
#define UTILITY_SPACECONVERSION_INCLUDED

// https://wiki.shaderlabs.org/wiki/Shader_tricks#Linearizing_depth
float linearizeDepth(float depth) {
	return (near * far) / (depth * (near - far) + far);
}

// Approximate linear depth function by DrDesten
float linearizeDepthFast(float depth) {
	return near / (1.0 - depth);
}

float reverseLinearDepth(float linearZ) {
	return (far + near) / (far - near) + (2.0 * far * near) / (linearZ * (far - near));
}

vec3 screenToViewSpace(vec3 screenPos, bool handleJitter) {
	vec3 positionNdc = 2.0 * screenPos - 1.0;

#ifdef TAA
#ifdef TAAU
	vec2 jitterOffset = taaOffset * rcp(taauRenderScale);
#else
	vec2 jitterOffset = taaOffset * 0.75;
#endif

	if (handleJitter) positionNdc.xy -= jitterOffset;
#endif

	return projectAndDivide(gbufferProjectionInverse, positionNdc);
}

vec3 viewToScreenSpace(vec3 viewPos, bool handleJitter) {
	vec3 positionNdc = projectAndDivide(gbufferProjection, viewPos);

#ifdef TAA
#ifdef TAAU
	vec2 jitterOffset = taaOffset * rcp(taauRenderScale);
#else
	vec2 jitterOffset = taaOffset * 0.75;
#endif

	if (handleJitter) positionNdc.xy += jitterOffset;
#endif

	return positionNdc * 0.5 + 0.5;
}

vec3 viewToSceneSpace(vec3 viewPos) {
	return transform(gbufferModelViewInverse, viewPos);
}

vec3 sceneToViewSpace(vec3 scenePos) {
	return transform(gbufferModelView, scenePos);
}

mat3 getTbnMatrix(vec3 normal) {
	vec3 tangent = normal.y == 1.0 ? vec3(1.0, 0.0, 0.0) : normalize(cross(vec3(0.0, 1.0, 0.0), normal));
	vec3 bitangent = normalize(cross(tangent, normal));
	return mat3(tangent, bitangent, normal);
}

#if defined TEMPORAL_REPROJECTION
vec3 reprojectSceneSpace(vec3 scenePos, bool hand) {
	vec3 cameraOffset = hand
		? vec3(0.0)
		: cameraPosition - previousCameraPosition;

	vec3 previousPos = transform(gbufferPreviousModelView, scenePos + cameraOffset);
	     previousPos = projectAndDivide(gbufferPreviousProjection, previousPos);

	return previousPos * 0.5 + 0.5;
}

vec3 reproject(vec3 screenPos) {
	vec3 pos = screenToViewSpace(screenPos, false);
	     pos = viewToSceneSpace(pos);

	bool hand = screenPos.z < handDepth;

	return reprojectSceneSpace(pos, hand);
}

vec3 reproject(vec3 screenPos, sampler2D velocitySampler) {
	vec3 velocity = texelFetch(velocitySampler, ivec2(screenPos.xy * viewSize), 0).xyz;

	if (maxOf(abs(velocity)) < eps) {
		return reproject(screenPos);
	} else {
		vec3 pos = screenToViewSpace(screenPos, false);
		     pos = pos - velocity;
		     pos = viewToScreenSpace(pos, false);

		return pos;
	}
}
#endif

#endif // UTILITY_SPACECONVERSION_INCLUDED
