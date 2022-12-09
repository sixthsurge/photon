#if !defined FOG_INCLUDED
#define FOG_INCLUDED

#include "utility/fastMath.glsl"

// This file is for analytical fog effects; for volumetric fog, see composite.fsh

// --------------------------------------
//  Fog effects common to all dimensions
// --------------------------------------

float getSphericalFog(float viewDist, float fogStartDistance, float fogDensity) {
	return exp2(-fogDensity * max0(viewDist - fogStartDistance));
}

float getBorderFog(vec3 scenePos, vec3 worldDir) {
#if defined WORLD_OVERWORLD
	float density = 1.0 - 0.2 * smoothstep(0.0, 0.25, worldDir.y);
#else
	float density = 1.0;
#endif

	float fog = cubicLength(scenePos.xz) / far;
	      fog = exp2(-12.0 * pow8(fog * density));

	return fog;
}

void applyCommonFog(inout vec3 fragColor, vec3 scenePos, vec3 worldDir, float viewDist, bool sky) {
	const vec3 lavaColor         = toRec2020(vec3(0.839, 0.373, 0.075)) * 2.0;
	const vec3 powderedSnowColor = toRec2020(vec3(0.957, 0.988, 0.988)) * 0.8;

	float fog;

	// Blindness fog
	fog = getSphericalFog(viewDist, 2.0, blindness);
	fragColor *= fog;

	// Lava fog
	fog = getSphericalFog(viewDist, 0.33, 3.0 * float(isEyeInWater == 2));
	fragColor = mix(lavaColor, fragColor, fog);

	// Powdered snow fog
	fog = getSphericalFog(viewDist, 0.5, 5.0 * float(isEyeInWater == 3));
	fragColor = mix(powderedSnowColor, fragColor, fog);
}

//----------------------------------------------------------------------------//
#if defined WORLD_OVERWORLD

#include "atmosphere.glsl"

const vec3 caveFogColor = vec3(0.033);

#if defined PROGRAM_DEFERRED3
vec3 getBorderFogColor(vec3 worldDir, float fog) {
	vec3 fogColor = sunColor * atmosphereScatteringBorderFog(worldDir, sunDir)
	              + moonColor * atmosphereScatteringBorderFog(worldDir, moonDir);

#ifdef BORDER_FOG_HIDE_SUNSET_GRADIENT
	worldDir.y = min(worldDir.y, -0.1);
	worldDir = normalize(worldDir);

	vec3 fogColorSunset = sunColor * atmosphereScatteringBorderFog(worldDir, sunDir)
	                    + moonColor * atmosphereScatteringBorderFog(worldDir, moonDir);

	float sunsetFactor = pulse(float(worldTime), 13000.0, 800.0, 24000.0)  // dusk
	                   + pulse(float(worldTime), 23000.0, 800.0, 24000.0); // dawn

	fogColor = mix(fogColor, fogColorSunset, sqr(sunsetFactor));
#endif

	return mix(fogColor, caveFogColor, biomeCave);
}
#endif

void applyFog(inout vec3 fragColor, vec3 scenePos, vec3 worldDir, bool sky) {
	float viewDist = length(scenePos - gbufferModelView[3].xyz);

	// Border fog

#if defined BORDER_FOG && defined PROGRAM_DEFERRED3
	if (!sky) {
		float fog = getBorderFog(scenePos, worldDir);
		fragColor = mix(getBorderFogColor(worldDir, fog), fragColor, fog);
	}
#endif

	// Cave fog

#ifdef CAVE_FOG
	float fog = getSphericalFog(viewDist, 0.0, 0.0033 * biomeCave * float(!sky));
	fragColor = mix(caveFogColor, fragColor, fog);
#endif

	applyCommonFog(fragColor, scenePos, worldDir, viewDist, sky);
}

//----------------------------------------------------------------------------//
#elif defined WORLD_NETHER

void applyFog(inout vec3 fragColor) {

}

//----------------------------------------------------------------------------//
#elif defined WORLD_END

void applyFog(inout vec3 fragColor) {

}

#endif

#endif
