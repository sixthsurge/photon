/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/post/bloom/merge_buffers.fsh
  Copy bloom tiles from read buffer to write buffer

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

/* DRAWBUFFERS:0 */
layout (location = 0) out vec3 bloom_tiles;

in vec2 uv;

uniform sampler2D colortex0;

void main() {
	int tile_index = int(-log2(1.0 - uv.x));

	if ((tile_index & 1) == 1) {
		bloom_tiles = texelFetch(colortex0, ivec2(gl_FragCoord.xy), 0).rgb;
	} else {
		discard;
	}
}
