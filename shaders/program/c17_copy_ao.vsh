/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/program/c17_copy_ao.vsh:
  manally copies colortex6 alt to main to fix ao on intel

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

void main() {
  gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 0.0, 1.0);
}
