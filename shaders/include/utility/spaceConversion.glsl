#if !defined INCLUDE_UTILITY_SPACECONVERSION
#define INCLUDE_UTILITY_SPACECONVERSION

float linearizeDepth(float depth) {
	// https://wiki.shaderlabs.org/wiki/Shader_tricks#Linearizing_depth
	return (near * far) / (depth * (near - far) + far);
}

vec3 screenToViewSpace(vec3 screenPos, bool handleJitter) {
	vec3 ndcPos = 2.0 * screenPos - 1.0;

#ifdef TAA
	if (handleJitter) ndcPos.xy -= taaOffset;
#endif

	return projectAndDivide(gbufferProjectionInverse, ndcPos);
}

vec3 viewToScreenSpace(vec3 viewPos, bool handleJitter) {
	vec3 ndcPos = projectAndDivide(gbufferProjection, viewPos);

#ifdef TAA
	if (handleJitter) ndcPos.xy += taaOffset;
#endif

	return ndcPos * 0.5 + 0.5;
}

vec3 viewToSceneSpace(vec3 viewPos) {
	return transform(gbufferModelViewInverse, viewPos);
}

vec3 sceneToViewSpace(vec3 scenePos) {
	return transform(gbufferModelView, scenePos);
}

#if defined TEMPORAL_REPROJECTION
vec3 reproject(vec3 screenPos) {
	vec3 pos = screenToViewSpace(screenPos, false);
	     pos = viewToSceneSpace(pos);

	vec3 cameraOffset = linearizeDepth(screenPos.z) < MC_HAND_DEPTH
		? vec3(0.0)
		: cameraPosition - previousCameraPosition;

	vec3 previousPos = transform(gbufferPreviousModelView, pos + cameraOffset);
	     previousPos = projectAndDivide(gbufferPreviousProjection, previousPos);

	return previousPos * 0.5 + 0.5;
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

#endif // INCLUDE_UTILITY_SPACECONVERSION
