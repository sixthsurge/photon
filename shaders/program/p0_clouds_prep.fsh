/*p0_cl
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/p0_clouds_prep:
  Create cloud cumulus coverage map and cloud shadow map

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

/* RENDERTARGETS: 8 */
layout (location = 0) out vec3 fragment_color;

in vec2 uv;

#ifndef IS_IRIS 
flat in vec3 sun_dir_fixed;
flat in vec3 moon_dir_fixed;
flat in vec3 light_dir_fixed;
#endif

#include "/include/sky/clouds/parameters.glsl"
flat in CloudsParameters clouds_params;

// ------------
//   Uniforms
// ------------

uniform sampler2D noisetex;

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
uniform float sunAngle;

uniform int frameCounter;
uniform float frameTimeCounter;

uniform int isEyeInWater;
uniform float eyeAltitude;
uniform float rainStrength;
uniform float blindness;

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

const vec3 sun_color  = vec3(0.0);
const vec3 moon_color = vec3(0.0);
const vec3 sky_color  = vec3(0.0);

#ifdef DISTANT_HORIZONS
uniform int dhRenderDistance;
#endif

#ifndef IS_IRIS 
    #define sun_dir sun_dir_fixed 
    #define moon_dir moon_dir_fixed
    #define light_dir light_dir_fixed
#endif

#include "/include/lighting/cloud_shadows.glsl"
#include "/include/sky/clouds/coverage_map.glsl"

void main() {
    // Cloud shadow map

#ifdef CLOUD_SHADOWS
    #ifndef BLOCKY_CLOUDS
    fragment_color.xy = render_cloud_shadow_map(uv);
    #else
    fragment_color.xy = vec2(1.0);
    #endif
#endif

    // Cumulus coverage map

#ifdef CLOUDS_CUMULUS_PRECOMPUTE_LOCAL_COVERAGE
    fragment_color.z = render_clouds_cumulus_coverage_map(uv);
#endif
}

