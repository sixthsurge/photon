/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/d4a_generate_sky_sh.csh:
  Generate skylight SH using parallel reduction

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

layout (local_size_x = 256) in;

const ivec3 workGroups = ivec3(1, 1, 1);

layout (rgba16f) writeonly uniform image2D colorimg4;

uniform sampler2D colortex4;

shared vec3 shared_memory[256][9];

#include "/include/sky/projection.glsl"
#include "/include/utility/random.glsl"
#include "/include/utility/sampling.glsl"
#include "/include/utility/spherical_harmonics.glsl"

void main() {
#ifndef SH_SKYLIGHT
	return;
#endif

	const uint sample_count = 256;
	uint i = uint(gl_LocalInvocationID.x);

	// Calculate SH coefficients for each sample

	vec3 direction = uniform_hemisphere_sample(vec3(0.0, 1.0, 0.0), r2(int(i)));
	vec3 radiance  = texture(colortex4, project_sky(direction)).rgb;
	float[9] coeff = sh_coeff_order_2(direction);

	for (uint band = 0u; band < 9u; ++band) {
		shared_memory[i][band] = radiance * coeff[band] * (tau / float(sample_count));
	}
	
	barrier();

	// Sum samples using parallel reduction

	/*
	for (uint stride = sample_count / 2u; stride > 0u; stride /= 2u) {
		if (i < stride) {
			for (uint band = 0u; band < 9u; ++band) {
				shared_memory[i][band] += shared_memory[i + stride][band];
			}
		}

		barrier();
	}
	*/

	// Loop manually unrolled as Intel doesn't seem to like barrier() calls in loops
	#define PARALLEL_REDUCTION_ITER(STRIDE)                                  \
		if (i < (STRIDE)) {                                                  \
			for (uint band = 0u; band < 9u; ++band) {                        \
				shared_memory[i][band] += shared_memory[i + (STRIDE)][band]; \
			}                                                                \
		}                                                                    \
		barrier();                          

	PARALLEL_REDUCTION_ITER(128u)
	PARALLEL_REDUCTION_ITER(64u)
	PARALLEL_REDUCTION_ITER(32u)
	PARALLEL_REDUCTION_ITER(16u)
	PARALLEL_REDUCTION_ITER(8u)
	PARALLEL_REDUCTION_ITER(4u)
	PARALLEL_REDUCTION_ITER(2u)
	PARALLEL_REDUCTION_ITER(1u)

	#undef PARALLEL_REDUCTION_ITER

	// Save SH coeff in colorimg4

	if (i == 0u) {
		for (uint band = 0u; band < 9u; ++band) {
			vec3 sh_coeff = shared_memory[0][band];
			imageStore(colorimg4, ivec2(191, 2 + band), vec4(sh_coeff, 0.0));
		}

		// Store irradiance facing up for forward lighting 
		vec3 irradiance_up = sh_evaluate_irradiance(shared_memory[0], vec3(0.0, 1.0, 0.0), 1.0);
		imageStore(colorimg4, ivec2(191, 2 + 9), vec4(irradiance_up, 0.0));
	}
}
