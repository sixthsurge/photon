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

flat out vec3 lightCol;
flat out vec3 skySh[9];
flat out mat2x3 illuminance;

uniform sampler2D colortex4; // Sky capture

uniform sampler2D depthtex2; // Atmospheric sun color LUT

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

#define ATMOSPHERE_SUN_COLOR_LUT depthtex2
#define WORLD_OVERWORLD

#include "/include/utility/random.glsl"
#include "/include/utility/sampling.glsl"
#include "/include/utility/sphericalHarmonics.glsl"

#include "/include/palette.glsl"
#include "/include/skyProjection.glsl"

void main() {
	uv = gl_MultiTexCoord0.xy;

	illuminance[0] = getSunBrightness() * getSunTint();
	illuminance[1] = getMoonBrightness() * getMoonTint();

	lightCol = getLightColor();

#ifdef SH_SKYLIGHT
	float skylightBoost = getSkylightBoost();

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
#endif

	vec2 vertexPos = gl_Vertex.xy * taauRenderScale;
	gl_Position = vec4(vertexPos * 2.0 - 1.0, 0.0, 1.0);
}
