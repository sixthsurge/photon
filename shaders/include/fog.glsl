#if !defined FOG_INCLUDED
#define FOG_INCLUDED

#include "utility/fastMath.glsl"

// This file is for analytical fog effects; for volumetric fog, see composite.fsh

// --------------------------------------
//  Fog effects common to all dimensions
// --------------------------------------

float getBorderFog(vec3 scenePos, vec3 worldDir) {
#if defined WORLD_OVERWORLD
	float density = 1.0 - 0.2 * smoothstep(0.0, 0.25, worldDir.y);
#endif

	float fog = cubicLength(scenePos.xz) / far;
	      fog = exp2(-8.0 * pow8(fog * density));

	return fog;
}

//----------------------------------------------------------------------------//
#if   defined WORLD_OVERWORLD

#include "atmosphere.glsl"

const vec3 caveFogCol = toRec2020(vec3(1.0)) * 0.0;

vec3 getBorderFogColor(vec3 worldDir, float fog) {
	vec3 fogCol = illuminance[0] * atmosphereScattering(worldDir, sunDir)
	            + illuminance[1] * atmosphereScattering(worldDir, moonDir);

	worldDir.y = min(worldDir.y, -0.1);
	worldDir = normalize(worldDir);

#ifdef BORDER_FOG_HIDE_SUNSET_GRADIENT
	vec3 fogColSunset = illuminance[0] * atmosphereScattering(worldDir, sunDir)
	                  + illuminance[1] * atmosphereScattering(worldDir, moonDir);

	float sunsetFactor = sqr(pulse(float(worldTime), 13000.0, 800.0, 24000.0))  // dusk
	                   + sqr(pulse(float(worldTime), 23000.0, 800.0, 24000.0)); // dawn

	fogCol = mix(fogCol, fogColSunset, sunsetFactor);
#endif

	return mix(fogCol, caveFogCol, biomeCave);
}

void getSimpleFog(inout vec3 fragColor, vec3 scenePos, vec3 worldDir) {
	// Border fog

	float fog = getBorderFog(scenePos, worldDir);
	fragColor = mix(getBorderFogColor(worldDir, fog), fragColor, fog);
}

//----------------------------------------------------------------------------//
#elif defined WORLD_NETHER

void getSimpleFog(inout vec3 fragColor) {

}

//----------------------------------------------------------------------------//
#elif defined WORLD_END

void getSimpleFog(inout vec3 fragColor) {

}

#endif

#endif
