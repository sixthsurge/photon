#if !defined INCLUDE_LIGHTING_CloudShadows
#define INCLUDE_LIGHTING_CloudShadows

const ivec2 cloudShadowRes = ivec2(256);
const float cloudShadowIntensity = 0.85;

vec2 projectCloudShadowmap(vec3 positionScene) {
	vec2 cloudShadowPos  = transform(shadowModelView, positionScene).xy / far;
	     cloudShadowPos /= 1.0 + length(cloudShadowPos);
		 cloudShadowPos  = cloudShadowPos * 0.5 + 0.5;

	return cloudShadowPos;
}

vec3 unprojectCloudShadowmap(vec2 cloudShadowPos) {
	cloudShadowPos  = cloudShadowPos * 2.0 - 1.0;
	cloudShadowPos /= 1.0 - length(cloudShadowPos);

	vec3 positionShadowView = vec3(cloudShadowPos * far, 1.0);

	return transform(shadowModelViewInverse, positionShadowView);
}

float getCloudShadows(sampler2D cloudShadowmap, vec3 positionScene) {
#ifndef CLOUD_SHADOWS
	return 1.0;
#else
	vec2 cloudShadowPos = projectCloudShadowmap(positionScene) * vec2(cloudShadowRes) / vec2(textureSize(cloudShadowmap, 0));

	if (clamp01(cloudShadowPos) != cloudShadowPos) return 1.0;

	// fade out cloud shadows when:
	// - the fragment is above the cloud layer
	// - the sun is near the horizon
	float altitudeFraction = (positionScene.y + eyeAltitude - SEA_LEVEL) * (CLOUDS_SCALE / CLOUDS_LAYER0_THICKNESS) - CLOUDS_LAYER0_ALTITUDE;
	float cloudShadowFade  = smoothstep(0.0, 0.7, 1.0 - altitudeFraction);
	      cloudShadowFade *= smoothstep(0.1, 0.2, lightDir.y);

	float cloudShadow = texture(cloudShadowmap, cloudShadowPos).x;
	      cloudShadow = mix(1.0, cloudShadow, cloudShadowFade);

	return cloudShadow * cloudShadowIntensity + (1.0 - cloudShadowIntensity);
#endif
}

#endif // INCLUDE_LIGHTING_CloudShadows
