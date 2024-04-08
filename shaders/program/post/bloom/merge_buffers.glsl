/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/post/bloom/merge_buffers.glsl:
  Copy bloom tiles from read buffer to write buffer

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"


//----------------------------------------------------------------------------//
#if defined vsh

out vec2 uv;

void main() {
	uv = gl_MultiTexCoord0.xy;

	gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 0.0, 1.0);
}

#endif
//----------------------------------------------------------------------------//



//----------------------------------------------------------------------------//
#if defined fsh

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

#endif
//----------------------------------------------------------------------------//
