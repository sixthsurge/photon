#version 400 compatibility

/*
--------------------------------------------------------------------------------

  Photon Shaders by SixthSurge

  world0/deferred3.vsh:
  Generate sky SH for far-field indirect lighting

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

out vec2 uv;

flat out vec3 lightColor;
#ifdef SH_SKYLIGHT
flat out vec3 skySh[9];
#else
flat out mat3 skyColors;
#endif

flat out mat2x3 illuminance; // Sun/moon illuminance

uniform sampler2D colortex4; // Sky capture

uniform sampler3D depthtex0; // Atmospheric scattering LUT

uniform float sunAngle;

uniform int worldTime;

uniform float rainStrength;

uniform vec3 lightDir;
uniform vec3 sunDir;
uniform vec3 moonDir;

uniform float timeSunrise;
uniform float timeNoon;
uniform float timeSunset;
uniform float timeMidnight;

#define ATMOSPHERE_SCATTERING_LUT depthtex0
#define WORLD_OVERWORLD

#include "/include/utility/random.glsl"
#include "/include/utility/sampling.glsl"
#include "/include/utility/sphericalHarmonics.glsl"

#include "/include/atmosphere.glsl"
#include "/include/palette.glsl"
#include "/include/skyProjection.glsl"

void main() {
	uv = gl_MultiTexCoord0.xy;

	illuminance[0] = getSunBrightness() * getSunTint();
	illuminance[1] = getMoonBrightness() * getMoonTint();

	lightColor = getLightColor();

	float skylightBoost = getSkylightBoost();

#ifdef SH_SKYLIGHT
	// Initialize SH to 0
	for (uint band = 0; band < 9; ++band) skySh[band] = vec3(0.0);

	// Sample into SH
	const uint stepCount = 256;
	for (uint i = 0; i < stepCount; ++i) {
		vec3 direction = uniformHemisphereSample(vec3(0.0, 1.0, 0.0), R2(int(i)));
		vec3 radiance  = texture(colortex4, projectSky(direction)).rgb;
		float[9] coeff = getSphericalHarmonicsCoefficientsOrder2(direction);

		for (uint band = 0; band < 9; ++band) skySh[band] += radiance * coeff[band];
	}

	// Apply skylight boost and normalize SH
	const float stepSolidAngle = tau / float(stepCount);
	for (uint band = 0; band < 9; ++band) skySh[band] *= skylightBoost * stepSolidAngle;
#else
	vec3 dir0 = normalize(vec3(0.0, 1.0, -0.8));              // Up
	vec3 dir1 = normalize(vec3(sunDir.xz + 0.1, 0.066).xzy);  // Sun-facing horizon
	vec3 dir2 = normalize(vec3(moonDir.xz + 0.1, 0.066).xzy); // Opposite horizon

	skyColors[0] = illuminance[0] * atmosphereScattering(dir0, sunDir)
	             + illuminance[1] * atmosphereScattering(dir0, moonDir);
	skyColors[1] = illuminance[0] * atmosphereScattering(dir1, sunDir)
	             + illuminance[1] * atmosphereScattering(dir1, moonDir);
	skyColors[2] = illuminance[0] * atmosphereScattering(dir2, sunDir)
	             + illuminance[1] * atmosphereScattering(dir2, moonDir);

	skyColors[0] *= skylightBoost;
	skyColors[1] *= skylightBoost;
	skyColors[2] *= skylightBoost;
#endif

	vec2 vertexPos = gl_Vertex.xy * taauRenderScale;
	gl_Position = vec4(vertexPos * 2.0 - 1.0, 0.0, 1.0);
}
