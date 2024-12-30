/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/post/fxaa.fsh
  FXAA v3.11 from http://blog.simonrodriguez.fr/articles/2016/07/implementing_fxaa.html

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

out vec2 uv;

void main() {
	uv = gl_MultiTexCoord0.xy;

	gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 0.0, 1.0);
}

