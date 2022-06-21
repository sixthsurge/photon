#if !defined INCLUDE_ATMOSPHERE_PALETTE
#define INCLUDE_ATMOSPHERE_PALETTE

#include "/include/atmospherics/atmosphere.glsl"
#include "/include/utility/color.glsl"

void paletteSetup() {
	// Added ambient lighting, so that you can see at all in caves
	const float ambientIntensity = 0.05 * AMBIENT_LIGHT_INTENSITY;
	const vec3 ambientColor = vec3(AMBIENT_LIGHT_TINT_R, AMBIENT_LIGHT_TINT_G, AMBIENT_LIGHT_TINT_B);
	ambientIrradiance = ambientIntensity * ambientColor * sqr(1.0 - rcp(240.0) * eyeBrightnessSmooth.y);

	// Sunlight/moonlight
	directIrradiance  = sunAngle < 0.5 ? sunIrradiance : moonIrradiance * moonPhaseBrightness;
	directIrradiance *= getAtmosphereTransmittance(lightDir.y, planetRadius);
	directIrradiance *= clamp01(rcp(0.02) * lightDir.y); // fade away during day/night transition

	// Skylight
	const vec3 up = vec3(0.0, 1.0, 0.0);
	skyIrradiance = sunIrradiance * getAtmosphereScattering(up, sunDir)
	              + moonIrradiance * getAtmosphereScattering(up, moonDir) * moonPhaseBrightness;
	skyIrradiance = tau * skyIrradiance;
}

#endif // INCLUDE_ATMOSPHERE_PALETTE
