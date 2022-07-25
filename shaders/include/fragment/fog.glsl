#if !defined INCLUDE_FRAGMENT_FOG
#define INCLUDE_FRAGMENT_FOG

#include "/include/fragment/aces/matrices.glsl"

#include "/include/utility/fastMath.glsl"

const vec3 caveFogColor = vec3(0.08);

float getSphericalFog(float viewerDistance, float fogStartDistance, float fogDensity) {
	return exp2(-fogDensity * max0(viewerDistance - fogStartDistance));
}

float getBorderFog(vec3 scenePos, vec3 direction) {
	float fog = cubicLength(scenePos.xz) / far;
	      fog = exp2(-8.0 * pow8(fog));
	      fog = mix(fog, 1.0, 0.75 * dampen(linearStep(0.0, 0.2, direction.y)));

	return fog;
}

// fog effects shared by all dimensions
vec3 applyCommonFog(vec3 radiance, vec3 scenePos, vec3 clearSky, float viewerDistance) {
	const vec3 lavaFogColor = 16.0 * pow(vec3(0.839, 0.373, 0.075), vec3(2.2)) * r709ToAp1;
	const vec3 snowFogColor = 0.05 * pow(vec3(0.957, 0.988, 0.988), vec3(2.2)) * r709ToAp1;

	scenePos -= gbufferModelViewInverse[3].xyz; // Account for view bobbing
	vec3 direction = scenePos * rcp(viewerDistance);

#ifdef BORDER_FOG
	// border fog
	float borderFog = getBorderFog(scenePos, direction);
	radiance = mix(clearSky, radiance, borderFog);
#endif

	// blindness fog
	radiance *= getSphericalFog(viewerDistance, 2.0, 4.0 * blindness);

	// lava fog
	float lavaFog = getSphericalFog(viewerDistance, 0.33, 3.0 * float(isEyeInWater == 2));
	radiance = mix(lavaFogColor, radiance, lavaFog);

	// powdered snow fog
	float snowFog = getSphericalFog(viewerDistance, 0.5, 5.0 * float(isEyeInWater == 3));
	radiance = mix(snowFogColor, radiance, snowFog);

	return radiance;
}

// fog effects specific to each dimension
#if   defined WORLD_OVERWORLD
vec3 applyFog(vec3 radiance, vec3 scenePos, vec3 clearSky) {
	clearSky = mix(clearSky, caveFogColor, biomeCave); // fix border fog underground

	float viewerDistance = length(scenePos);

#ifdef CAVE_FOG
	// cave fog
	float caveFog = getSphericalFog(viewerDistance, 0.0, 0.0033 * biomeCave);
	radiance = mix(caveFogColor, radiance, caveFog);
#endif

	radiance = applyCommonFog(radiance, scenePos, clearSky, viewerDistance);

	return radiance;
}
#endif

#endif // INCLUDE_FRAGMENT_FOG
