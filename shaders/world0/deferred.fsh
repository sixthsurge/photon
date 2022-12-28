#version 400 compatibility

/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  world0/deferred.fsh:
  Render sky capture

--------------------------------------------------------------------------------

  Magic constants, please don't remove these!

  const int colortex0Format = R11F_G11F_B10F; // scene color (deferred3 -> temporal), bloom tiles (composite5 -> composite14), final color (composite14 -> final)
  const int colortex1Format = RGBA16;         // gbuffer data 0 (solid -> composite1)
  const int colortex2Format = RGBA16;         // gbuffer data 1 (solid -> composite1)
  const int colortex3Format = RGBA8;          // animated overlays/vanilla sky (solid -> deferred3), blended translucent color (translucent -> composite1)
  const int colortex4Format = R11F_G11F_B10F; // sky capture (deferred -> composite1)
  const int colortex5Format = RGBA16F;        // scene history (always), low-res clouds (deferred1 -> deferred2 +flip), fog scattering (composite -> composite1 +flip)
  const int colortex6Format = RGBA16F;        // ambient occlusion history & clouds pixel age (always), fog transmittance (composite -> composite1), TAAU min color (composite2 -> composite3 +flip)
  const int colortex7Format = RGBA16F;        // clouds history (always), TAAU max color (composite2 -> composite3 +flip)

  const bool colortex0Clear = false;
  const bool colortex1Clear = false;
  const bool colortex2Clear = false;
  const bool colortex3Clear = true;
  const bool colortex4Clear = false;
  const bool colortex5Clear = false;
  const bool colortex6Clear = false;
  const bool colortex7Clear = false;

  const vec4 colortex3ClearColor = vec4(0.0, 0.0, 0.0, 0.0);

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

/* DRAWBUFFERS:4 */
layout (location = 0) out vec3 scene_color;

in vec2 uv;

flat in vec3 sun_color;
flat in vec3 moon_color;

uniform sampler3D depthtex0; // atmosphere scattering LUT

#ifdef SHADOW
uniform mat4 shadowModelViewInverse;
#endif

uniform int worldTime;
uniform float sunAngle;

uniform int frameCounter;
uniform float frameTimeCounter;

uniform vec3 light_dir;
uniform vec3 sun_dir;
uniform vec3 moon_dir;

uniform float biome_cave;

uniform float time_sunrise;
uniform float time_noon;
uniform float time_sunset;
uniform float time_midnight;

#define ATMOSPHERE_SCATTERING_LUT depthtex0
#define PROGRAM_DEFERRED
#define WORLD_OVERWORLD

#include "/include/sky.glsl"
#include "/include/sky_projection.glsl"

void main() {
	ivec2 texel = ivec2(gl_FragCoord.xy);

	vec3 ray_dir = unproject_sky(uv);

	scene_color = draw_sky(ray_dir, vec4(vec3(0.0), 1.0));
}
