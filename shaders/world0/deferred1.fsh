#version 400 compatibility

/*
--------------------------------------------------------------------------------

  Photon Shaders by SixthSurge

  world0/deferred1.fsh:
  Render clouds

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

/* DRAWBUFFERS:8 */
layout (location = 0) out vec4 clouds;

in vec2 uv;

flat in vec3 light_color;
flat in vec3 sky_color;

uniform sampler2D noisetex;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;

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
uniform float blindness;
uniform float nightVision;

uniform vec3 light_dir;
uniform vec3 sun_dir;
uniform vec3 moon_dir;

uniform vec2 view_res;
uniform vec2 view_pixel_size;
uniform vec2 taa_offset;

uniform float biome_cave;

uniform vec2 clouds_coverage_cu;
uniform vec2 clouds_coverage_ac;
uniform vec2 clouds_coverage_cc;
uniform vec2 clouds_coverage_ci;

#include "/include/atmosphere.glsl"
#include "/include/clouds.glsl"

void main() {

}
