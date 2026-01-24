/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/program/c17_copy_ao.fsh:
  manally copies colortex6 alt to main to fix ao on intel

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

layout(location = 0) out vec4 ao_history;

/* RENDERTARGETS: 6 */

uniform sampler2D colortex6;

void main() {
    ivec2 texel = ivec2(gl_FragCoord.xy);
    ao_history = texelFetch(colortex6, texel, 0);
}
