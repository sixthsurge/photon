/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/d0_sky_map:
  Render omnidirectional sky map for reflections and SH lighting

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

layout(location = 0) out vec3 sky_map;

/* RENDERTARGETS: 4 */

in vec2 uv;

flat in vec3 ambient_color;
flat in vec3 light_color;

#if defined WORLD_OVERWORLD
flat in vec3 sun_color;
flat in vec3 moon_color;
flat in vec3 sky_color;

flat in mat2x4 aurora_data;

float aurora_amount;
mat2x3 aurora_colors;
float rainbow_amount;

#include "/include/sky/clouds/parameters.glsl"
flat in CloudsParameters clouds_params;

#include "/include/fog/overworld/parameters.glsl"
flat in OverworldFogParameters fog_params;
#endif

// ------------
//   Uniforms
// ------------

uniform sampler3D colortex6; // 3D bubbly worley noise
#define SAMPLER_WORLEY_BUBBLY colortex6
uniform sampler3D colortex7; // 3D swirley worley noise
#define SAMPLER_WORLEY_SWIRLEY colortex7

#if defined WORLD_OVERWORLD && defined GALAXY
uniform sampler2D colortex13;
#define galaxy_sampler colortex13
#endif

uniform sampler3D depthtex0; // atmospheric scattering LUT
uniform sampler2D depthtex1;

uniform sampler2D colortex8; // cloud shadow map

uniform sampler2D noisetex;

#if defined WORLD_OVERWORLD && defined SH_SKYLIGHT_FRAGMENT
uniform sampler2D colortex4; // previous frame sky map, for sky SH
#endif

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform float near;
uniform float far;

uniform int worldTime;
uniform int moonPhase;
uniform float sunAngle;

uniform int frameCounter;
uniform float frameTimeCounter;

uniform int isEyeInWater;
uniform float eyeAltitude;
uniform float rainStrength;
uniform float blindness;
uniform float darknessFactor;

uniform vec3 light_dir;
uniform vec3 sun_dir;
uniform vec3 moon_dir;

uniform vec2 view_res;
uniform vec2 view_pixel_size;
uniform vec2 taa_offset;

uniform float world_age;
uniform float eye_skylight;

uniform float time_sunrise;
uniform float time_noon;
uniform float time_sunset;
uniform float time_midnight;

uniform float biome_cave;
uniform float biome_may_snow;

// ------------
//   Includes
// ------------

#define ATMOSPHERE_SCATTERING_LUT depthtex0
#define CLOUDS_USE_LOCAL_COVERAGE_MAP

#ifdef CLOUDS_CUMULUS_PRECOMPUTE_LOCAL_COVERAGE
#define CLOUDS_USE_LOCAL_COVERAGE_MAP
#endif

#if defined WORLD_OVERWORLD
#include "/include/fog/overworld/analytic.glsl"
#include "/include/sky/aurora.glsl"
#endif

#include "/include/sky/projection.glsl"
#include "/include/sky/sky.glsl"

#if defined WORLD_OVERWORLD && defined SH_SKYLIGHT_FRAGMENT
#include "/include/utility/random.glsl"
#include "/include/utility/sampling.glsl"
#include "/include/utility/spherical_harmonics.glsl"

// Fragment shader version of deferred4_a (d4a_generate_sky_sh.csh), for
// platforms without compute shaders (Apple Silicon). Projects the previous
// frame's sky map onto SH; the one frame of latency is not visible.
// index 0-8: SH coefficients, 9: irradiance facing up
vec3 generate_sky_sh(int index) {
    const int sample_count = 256;

    float skylight_boost = get_skylight_boost();

    vec3 sh[9];
    for (int band = 0; band < 9; ++band) {
        sh[band] = vec3(0.0);
    }

    for (int i = 0; i < sample_count; ++i) {
        vec3 direction
            = uniform_hemisphere_sample(vec3(0.0, 1.0, 0.0), r2(i));
        vec3 radiance
            = texture(colortex4, project_sky(direction)).rgb * skylight_boost;
        float[9] coeff = sh_coeff_order_2(direction);

        for (int band = 0; band < 9; ++band) {
            sh[band] += radiance * coeff[band] * (tau / float(sample_count));
        }
    }

    if (index < 9) {
        return sh[index];
    } else {
        return sh_evaluate_irradiance(sh, vec3(0.0, 1.0, 0.0), 1.0);
    }
}
#endif

void main() {
#if defined WORLD_OVERWORLD
    aurora_amount = aurora_data[0].w;
    aurora_colors = mat2x3(aurora_data[0].xyz, aurora_data[1].xyz);
    rainbow_amount = aurora_data[1].w;
#endif

    ivec2 texel = ivec2(gl_FragCoord.xy);

    if (texel.x == sky_map_res.x) { // Store lighting colors
        sky_map = vec3(0.0);
        switch (texel.y) {
            case 0:
                sky_map = light_color;
                break;

            case 1:
                sky_map = ambient_color;
                break;
        }

#if defined WORLD_OVERWORLD && defined SH_SKYLIGHT_FRAGMENT
        // Sky SH (normally written by deferred4_a)
        if (texel.y >= 2 && texel.y <= 11) {
            sky_map = generate_sky_sh(texel.y - 2);
        }
#endif
    } else { // Draw sky map
        vec3 ray_dir = unproject_sky(uv);

        sky_map = draw_sky(ray_dir);

#if defined WORLD_OVERWORLD
        // Apply analytic fog over sky
        mat2x3 fog = air_fog_analytic(
            cameraPosition,
            cameraPosition + ray_dir,
            true,
            eye_skylight,
            1.0
        );
        sky_map = sky_map * fog[1] + fog[0];
#endif
    }
}
