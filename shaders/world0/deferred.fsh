#version 400 compatibility

/*
--------------------------------------------------------------------------------

  Photon Shaders by SixthSurge

  world0/deferred.fsh:
  Render sky capture

--------------------------------------------------------------------------------

  Magic constants, please don't remove these!

  const int colortex0Format = R11F_G11F_B10F; // Scene color (deferred3 -> temporal), bloom tiles (composite4 -> composite6), final color (composite7 -> final)
  const int colortex1Format = RGBA16;         // Gbuffer 0 (solid -> composite1)
  const int colortex2Format = RGBA16;         // Gbuffer 1 (solid -> composite1)
  const int colortex3Format = RGBA8;          // Animated overlays/vanilla sky (solid -> deferred3), translucent color (translucent -> composite1)
  const int colortex4Format = R11F_G11F_B10F; // Sky capture (deferred -> composite1)
  const int colortex5Format = RGBA16F;        // Scene history (always), clouds (deferred1 -> deferred3 +flip), fog scattering (composite -> composite1 +flip)
  const int colortex6Format = RGBA16F;        // Ambient occlusion history (always), fog transmittance (composite -> composite1), TAAU min color (composite2 -> composite3 +flip)
  const int colortex7Format = RGBA16F;        // Clouds history (always), TAAU max color (composite2 -> composite3 +flip)

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
layout (location = 0) out vec3 fragColor;

in vec2 uv;

flat in mat2x3 illuminance;

uniform sampler3D depthtex0; // Atmosphere scattering LUT

#ifdef SHADOW
uniform mat4 shadowModelViewInverse;
#endif

uniform int worldTime;
uniform float sunAngle;

uniform int frameCounter;
uniform float frameTimeCounter;

uniform vec3 lightDir;
uniform vec3 sunDir;
uniform vec3 moonDir;

uniform float biomeCave;

uniform float timeSunrise;
uniform float timeNoon;
uniform float timeSunset;
uniform float timeMidnight;

#define ATMOSPHERE_SCATTERING_LUT depthtex0
#define PROGRAM_DEFERRED
#define WORLD_OVERWORLD

#include "/include/sky.glsl"
#include "/include/skyProjection.glsl"

void main() {
	ivec2 texel = ivec2(gl_FragCoord.xy);

	vec3 rayDir = unprojectSky(uv);

	fragColor = renderSky(rayDir);
}
