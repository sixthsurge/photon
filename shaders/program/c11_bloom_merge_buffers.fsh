/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/c11_bloom_merge_buffers:
  Copy bloom tiles from read buffer to write buffer

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

layout (location = 0) out vec3 bloom_tiles;

/* RENDERTARGETS: 0 */

in vec2 uv;

uniform sampler2D colortex0;

uniform vec2 view_res;

void main() {
	int tile_index = int(-log2(1.0 - uv.x));

	if ((tile_index & 1) == 1) {
		bloom_tiles = texelFetch(colortex0, ivec2(gl_FragCoord.xy), 0).rgb;
	} else {
		discard;
	}
}

