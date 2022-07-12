#if !defined INCLUDE_UTILITY_SPACECONVERSION
#define INCLUDE_UTILITY_SPACECONVERSION

float linearizeDepth(float depth) {
	// https://wiki.shaderlabs.org/wiki/Shader_tricks#Linearizing_depth
	return (near * far) / (depth * (near - far) + far);
}

float reverseLinearDepth(float linearZ) {
	return (far + near) / (far - near) + (2.0 * far * near) / (linearZ * (far - near));
}

vec3 screenToViewSpace(vec3 positionScreen, bool handleJitter) {
	vec3 positionNdc = 2.0 * positionScreen - 1.0;

#ifdef TAA
	if (handleJitter) positionNdc.xy -= taaOffset;
#endif

	return projectAndDivide(gbufferProjectionInverse, positionNdc);
}

vec3 viewToScreenSpace(vec3 positionView, bool handleJitter) {
	vec3 positionNdc = projectAndDivide(gbufferProjection, positionView);

#ifdef TAA
	if (handleJitter) positionNdc.xy += taaOffset;
#endif

	return positionNdc * 0.5 + 0.5;
}

vec3 viewToSceneSpace(vec3 positionView) {
	return transform(gbufferModelViewInverse, positionView);
}

vec3 sceneToViewSpace(vec3 positionScene) {
	return transform(gbufferModelView, positionScene);
}

mat3 getTbnMatrix(vec3 normal) {
	vec3 tangent = normal.y == 1.0 ? vec3(1.0, 0.0, 0.0) : normalize(cross(vec3(0.0, 1.0, 0.0), normal));
	vec3 bitangent = normalize(cross(tangent, normal));
	return mat3(tangent, bitangent, normal);
}

#if defined TEMPORAL_REPROJECTION
vec3 reproject(vec3 positionScreen) {
	vec3 pos = screenToViewSpace(positionScreen, false);
	     pos = viewToSceneSpace(pos);

	vec3 cameraOffset = linearizeDepth(positionScreen.z) < MC_HAND_DEPTH
		? vec3(0.0)
		: cameraPosition - previousCameraPosition;

	vec3 previousPos = transform(gbufferPreviousModelView, pos + cameraOffset);
	     previousPos = projectAndDivide(gbufferPreviousProjection, previousPos);

	return previousPos * 0.5 + 0.5;
}

vec3 reproject(vec3 positionScreen, sampler2D velocitySampler) {
	vec3 velocity = texelFetch(velocitySampler, ivec2(positionScreen.xy * viewSize), 0).xyz;

	if (maxOf(abs(velocity)) < eps) {
		return reproject(positionScreen);
	} else {
		vec3 pos = screenToViewSpace(positionScreen, false);
		     pos = pos - velocity;
		     pos = viewToScreenSpace(pos, false);

		return pos;
	}
}
#endif

#endif // INCLUDE_UTILITY_SPACECONVERSION
