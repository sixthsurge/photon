#include "/include/global.glsl"

//--// Outputs //-------------------------------------------------------------//

out vec2 coord;

flat out vec3 ambientIrradiance;
flat out vec3 directIrradiance;

#ifdef SH_SKYLIGHT
flat out vec3[9] skySh;
#else
flat out vec3 skyIrradiance;
#endif

//--// Uniforms //------------------------------------------------------------//

uniform sampler2D colortex4; // Sky capture, lighting color palette, dynamic weather properties

//--// Includes //-----------------------------------------------------------//

#include "/include/atmospherics/skyProjection.glsl"

#include "/include/utility/random.glsl"
#include "/include/utility/sampling.glsl"
#include "/include/utility/sphericalHarmonics.glsl"

//--// Functions //-----------------------------------------------------------//

void main() {
	coord = gl_MultiTexCoord0.xy;

	ambientIrradiance = texelFetch(colortex4, ivec2(255, 0), 0).rgb;
	directIrradiance  = texelFetch(colortex4, ivec2(255, 1), 0).rgb;

#ifndef SH_SKYLIGHT
	skyIrradiance     = texelFetch(colortex4, ivec2(255, 2), 0).rgb;
#else
	// Initialize SH to 0
	for (uint band = 0; band < 9; ++band) skySh[band] = vec3(0.0);

	// Sample into SH
	const uint sampleCount = 128;
	for (uint i = 0; i < sampleCount; ++i) {
		vec3 direction = uniformHemisphereSample(vec3(0.0, 1.0, 0.0), R2(int(i)));
		vec3 radiance  = texture(colortex4, projectSky(direction)).rgb;
		float[9] coeff = getSphericalHarmonicsCoefficientsOrder2(direction);

		for (uint band = 0; band < 9; ++band) skySh[band] += radiance * coeff[band];
	}

	// Normalize SH
	const float sampleSolidAngle = tau / float(sampleCount);
	for (uint band = 0; band < 9; ++band) skySh[band] *= sampleSolidAngle;
#endif

	gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 0.0, 1.0);
}
