/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/c16_motion_blur:
  Apply motion blur

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

out vec2 uv;

void main() {
	uv = gl_MultiTexCoord0.xy;

	gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 0.0, 1.0);
}

