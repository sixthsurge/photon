/*
--------------------------------------------------------------------------------

  Photon Shaders by SixthSurge

  program/post/bloom/merge.fsh
  Copy bloom tiles from read buffer to write buffer

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

/* DRAWBUFFERS:0 */
layout (location = 0) out vec3 bloomTiles;

in vec2 uv;

uniform sampler2D colortex0;

void main() {
	int tileIndex = int(-log2(1.0 - uv.x));

	if ((tileIndex & 1) == 1) {
		bloomTiles = texelFetch(colortex0, ivec2(gl_FragCoord.xy), 0).rgb;
	} else {
		discard;
	}
}
