/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/c11_bloom_merge_buffers:
  Copy bloom tiles from read buffer to write buffer

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

out vec2 uv;

void main() {
	uv = gl_MultiTexCoord0.xy;

	gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 0.0, 1.0);
}

