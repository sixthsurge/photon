/*
--------------------------------------------------------------------------------

  Photon Shaders by SixthSurge

  program/vertexSimple.vsh:
  Simple vertex shader for fullscreen passes

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

out vec2 uv;

void main() {
	uv = gl_MultiTexCoord0.xy;

#if defined PROGRAM_SCALE
	vec2 vertexPos = gl_Vertex.xy * PROGRAM_SCALE;
#else
	vec2 vertexPos = gl_Vertex.xy;
#endif

	gl_Position = vec4(vertexPos * 2.0 - 1.0, 0.0, 1.0);
}
