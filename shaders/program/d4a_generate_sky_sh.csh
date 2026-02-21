/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/d4a_generate_sky_sh.csh:
  Generate skylight SH using parallel reduction

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

layout(local_size_x = 256) in;

const ivec3 workGroups = ivec3(1, 1, 1);

layout(rgba16f) writeonly uniform image2D colorimg4;

uniform sampler2D colortex4;

shared vec3 shared_memory[256][9];

uniform int worldTime;
uniform int worldDay;
uniform int moonPhase;
uniform float sunAngle;
uniform float rainStrength;
uniform float wetness;

uniform int frameCounter;
uniform float frameTimeCounter;

uniform int isEyeInWater;
uniform float blindness;
uniform float nightVision;
uniform float darknessFactor;

uniform vec3 light_dir;
uniform vec3 sun_dir;
uniform vec3 moon_dir;

uniform float biome_cave;
uniform float biome_may_rain;
uniform float biome_may_snow;
uniform float biome_snowy;
uniform float biome_temperate;
uniform float biome_arid;
uniform float biome_taiga;
uniform float biome_jungle;
uniform float biome_swamp;
uniform float biome_temperature;
uniform float biome_humidity;
uniform float desert_sandstorm;

uniform float world_age;
uniform float time_sunrise;
uniform float time_noon;
uniform float time_sunset;
uniform float time_midnight;

#include "/include/lighting/colors/light_color.glsl"
#include "/include/sky/projection.glsl"
#include "/include/utility/random.glsl"
#include "/include/utility/sampling.glsl"
#ifdef MC_GL_RENDERER_INTEL
#include "/include/utility/spherical_harmonics_fallback.glsl"
#else
#include "/include/utility/spherical_harmonics.glsl"
#endif
void main() {
#ifndef SH_SKYLIGHT
    return;
#endif

    const uint sample_count = 256;
    uint i = uint(gl_LocalInvocationID.x);

    // Calculate SH coefficients for each sample

    float skylight_boost = get_skylight_boost();

    vec3 direction = uniform_hemisphere_sample(vec3(0.0, 1.0, 0.0), r2(int(i)));
    vec3 radiance =
        texture(colortex4, project_sky(direction)).rgb * skylight_boost;
#ifdef MC_GL_RENDERER_INTEL
    mat3 coeff = sh_coeff_order_2(direction);

    for (uint band = 0u; band < 9u; ++band) {
        shared_memory[i][band] = radiance * coeff[band / 3u][band % 3u] *
            (tau / float(sample_count));
    }
#else
    float[9] coeff = sh_coeff_order_2(direction);

    for (uint band = 0u; band < 9u; ++band) {
        shared_memory[i][band] =
            radiance * coeff[band] * (tau / float(sample_count));
    }
#endif
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
#define PARALLEL_REDUCTION_ITER(STRIDE) \
    if (i < (STRIDE)) { \
        for (uint band = 0u; band < 9u; ++band) { \
            shared_memory[i][band] += shared_memory[i + (STRIDE)][band]; \
        } \
    } \
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
#ifdef MC_GL_RENDERER_INTEL
        sh3 sh;
        for (uint band = 0u; band < 3u; ++band) {
            sh.f1[band] = shared_memory[0][band];
            sh.f2[band] = shared_memory[0][band + 3u];
            sh.f3[band] = shared_memory[0][band + 6u];
        }
        vec3 irradiance_up =
            sh_evaluate_irradiance(sh, vec3(0.0, 1.0, 0.0), 1.0);
#else
        vec3 irradiance_up =
            sh_evaluate_irradiance(shared_memory[0], vec3(0.0, 1.0, 0.0), 1.0);
#endif
        imageStore(colorimg4, ivec2(191, 2 + 9), vec4(irradiance_up, 0.0));
    }
}
