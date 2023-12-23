#version 400 compatibility

/*
--------------------------------------------------------------------------------

  Photon Shaders by SixthSurge

  world0/prepare.vsh:
  Render cloud shadow map

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

/* RENDERTARGETS: 8 */
layout (location = 0) out float cloud_shadow_map;

in vec2 uv;

flat in vec2 clouds_cumulus_coverage;
flat in vec2 clouds_altocumulus_coverage;
flat in vec2 clouds_cirrus_coverage;
flat in float clouds_cumulus_congestus_amount;
flat in float clouds_cumulonimbus_amount;
flat in float clouds_stratus_amount;

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

#define PROGRAM_PREPARE
#include "/include/light/cloud_shadows.glsl"
#include "/include/sky/clouds.glsl"

void main() {
	vec3 scene_pos = unproject_cloud_shadow_map(uv);
	cloud_shadow_map = render_cloud_shadow_map(scene_pos);
}

#ifndef CLOUD_SHADOWS
#error "This program should be disabled if Cloud Shadows are disabled"
#endif
