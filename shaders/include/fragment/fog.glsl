#if !defined INCLUDE_FRAGMENT_FOG
#define INCLUDE_FRAGMENT_FOG

const vec3 caveFogColor = vec3(0.0);

float cubicLength(vec2 v) {
	return pow(cube(abs(v.x)) + cube(abs(v.y)), rcp(3.0));
}

vec3 distanceFade(vec3 radiance, vec3 clearSky, vec3 scenePos, vec3 worldDir) {
	float fade = cubicLength(scenePos.xz) / far;
	      fade = exp2(-8.0 * pow8(fade));
	      fade = mix(fade, 1.0, 0.75 * dampen(linearStep(0.0, 0.2, worldDir.y)));

	vec3 sky = mix(clearSky, caveFogColor, biomeCave);

	return mix(sky, radiance, fade);
}

#endif // INCLUDE_FRAGMENT_FOG
