#if !defined INCLUDE_LIGHTING_REFLECTIONS
#define INCLUDE_LIGHTING_REFLECTIONS

#include "/include/atmospherics/sky.glsl"
#include "/include/atmospherics/skyProjection.glsl"

#include "/include/fragment/raytracer.glsl"

#include "/include/utility/sampling.glsl"
#include "/include/utility/spaceConversion.glsl"

vec3 traceSpecularRay(
	vec3 screenPos,
	vec3 viewPos,
	vec3 rayDir,
	float dither,
	float mipLevel,
	float skylightFalloff
) {
	vec3 rayDirView = mat3(gbufferModelView) * rayDir;

	vec3 hitPos;
	bool hit = raytraceIntersection(
		depthtex1,
		screenPos,
		viewPos,
		rayDirView,
		dither,
		mipLevel == 0.0 ? SSR_INTERSECTION_STEPS_SMOOTH : SSR_INTERSECTION_STEPS_ROUGH,
		SSR_REFINEMENT_STEPS,
		hitPos
	);

	vec3 skyRadiance = texture(colortex4, projectSky(rayDir)).rgb * skylightFalloff * float(isEyeInWater == 0);

	if (hit) {
		float borderAttenuation = (hitPos.x * hitPos.y - hitPos.x) * (hitPos.x * hitPos.y - hitPos.y);
		      borderAttenuation = dampen(linearStep(0.0, 0.005, borderAttenuation));

		hitPos = reproject(hitPos);
		if (clamp01(hitPos) != hitPos) return skyRadiance;
		vec3 radiance = textureLod(colortex8, hitPos.xy, int(mipLevel)).rgb;

		return mix(skyRadiance, radiance, borderAttenuation);
	} else {
		return skyRadiance;
	}
}

vec3 getSpecularReflections(
	Material material,
	mat3 tbnMatrix,
	vec3 screenPos,
	vec3 viewPos,
	vec3 normal,
	vec3 viewerDir,
	vec3 viewerDirTangent,
	float skylight
) {
	bool hasReflections = (material.f0.x - material.f0.x * material.roughness * SSR_ROUGHNESS_THRESHOLD) > 0.01; // based on Kneemund's method
	if (!hasReflections) return vec3(0.0);

	vec3 albedoTint = material.isHardcodedMetal ? material.albedo : vec3(1.0);

	float alphaSq = sqr(material.roughness);
	float skylightFalloff = pow8(skylight);

	float dither = R1(frameCounter, texelFetch(noisetex, ivec2(gl_FragCoord.xy) & 511, 0).b);

#if defined MC_SPECULAR_MAP && defined SSR_ROUGH
	vec2 hash = R2(
		SSR_RAY_COUNT * frameCounter,
		vec2(
			texelFetch(noisetex, ivec2(gl_FragCoord.xy)                     & 511, 0).b,
			texelFetch(noisetex, ivec2(gl_FragCoord.xy + vec2(239.0, 23.0)) & 511, 0).b
		)
	);

	if (material.roughness > 5e-2) { // Rough reflection
	 	float mipLevel = sqrt(4.0 * dampen(material.roughness));

		vec3 reflection = vec3(0.0);

		for (int i = 0; i < SSR_RAY_COUNT; ++i) {
			vec3 microfacetNormal = tbnMatrix * sampleGgxVndf(viewerDirTangent, vec2(material.roughness), hash);
			vec3 rayDir = reflect(-viewerDir, microfacetNormal);

			float NoL = dot(normal, rayDir);
			if (NoL < eps) continue;

			vec3 radiance = traceSpecularRay(screenPos, viewPos, rayDir, dither, mipLevel, skylightFalloff);

			NoL       = max(1e-2, NoL);
			float NoV = max(1e-2, dot(normal, viewerDir));
			float MoV = clamp01(dot(microfacetNormal, viewerDir));

			vec3 fresnel = material.isMetal ? fresnelSchlick(MoV, material.f0) : vec3(fresnelDielectric(MoV, material.n));
			float v1 = v1SmithGgx(NoV, alphaSq);
			float v2 = v2SmithGgx(NoL, NoV, alphaSq);

			reflection += radiance * fresnel * (2.0 * NoL * v2 / v1);

			hash = R2Next(hash);
		}

		reflection *= albedoTint * rcp(float(SSR_RAY_COUNT));
		if (any(isnan(reflection))) reflection = vec3(0.0); // don't reflect NaNs
		return reflection;
	}
#endif

	//--// Mirror-like reflection

	vec3 rayDir = reflect(-viewerDir, normal);

	float NoL = dot(normal, rayDir);
	float NoV = clamp01(dot(normal, viewerDir));

	if (NoL < eps) return vec3(0.0);

	vec3 radiance = traceSpecularRay(screenPos, viewPos, rayDir, dither, 0.0, skylightFalloff);

	vec3 fresnel = material.isMetal ? fresnelSchlick(NoV, material.f0) : vec3(fresnelDielectric(NoV, material.n));

	vec3 reflection = radiance * albedoTint * fresnel;
	if (any(isnan(reflection))) reflection = vec3(0.0); // don't reflect NaNs
	return reflection;
}

#endif // INCLUDE_LIGHTING_REFLECTIONS
