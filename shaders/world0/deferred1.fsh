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

flat in vec3 lightColor;
flat in vec3 skyColor;

void main() {

}
