#if !defined INCLUDE_LIGHTING_CloudShadows
#define INCLUDE_LIGHTING_CloudShadows

const ivec2 cloudShadowRes = ivec2(256);
const float cloudShadowIntensity = 0.85;

vec2 projectCloudShadowmap(vec3 scenePos) {
	vec2 cloudShadowPos  = transform(shadowModelView, scenePos).xy / far;
	     cloudShadowPos /= 1.0 + length(cloudShadowPos);
		 cloudShadowPos  = cloudShadowPos * 0.5 + 0.5;

	return cloudShadowPos;
}

vec3 unprojectCloudShadowmap(vec2 cloudShadowPos) {
	cloudShadowPos  = cloudShadowPos * 2.0 - 1.0;
	cloudShadowPos /= 1.0 - length(cloudShadowPos);

	vec3 shadowViewPos = vec3(cloudShadowPos * far, 1.0);

	return transform(shadowModelViewInverse, shadowViewPos);
}

float getCloudShadows(sampler2D cloudShadowmap, vec3 scenePos) {
#ifndef CLOUD_SHADOWS
	return 1.0;
#else
	vec2 cloudShadowPos = projectCloudShadowmap(scenePos) * vec2(cloudShadowRes) / vec2(textureSize(cloudShadowmap, 0));

	if (clamp01(cloudShadowPos) != cloudShadowPos) return 1.0;

	float cloudShadow = texture(cloudShadowmap, cloudShadowPos).x;

	return cloudShadow * cloudShadowIntensity + (1.0 - cloudShadowIntensity);
#endif
}

#endif // INCLUDE_LIGHTING_CloudShadows
