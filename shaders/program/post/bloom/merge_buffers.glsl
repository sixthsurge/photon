/*
--------------------------------------------------------------------------------

  Photon Shaders by SixthSurge

  program/post/bloom/merge_buffers.glsl:
  Copy bloom tiles from read buffer to write buffer

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

varying vec2 uv;

// ------------
//   uniforms
// ------------

uniform sampler2D colortex0;

uniform vec2 view_res;


//----------------------------------------------------------------------------//
#if defined STAGE_VERTEX

void main()
{
	uv = gl_MultiTexCoord0.xy;

	gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 0.0, 1.0);
}

#endif
//----------------------------------------------------------------------------//



//----------------------------------------------------------------------------//
#if defined STAGE_FRAGMENT

layout (location = 0) out vec3 bloom_tiles;

/* DRAWBUFFERS:0 */

void main()
{
	int tile_index = int(-log2(1.0 - uv.x));

	if ((tile_index & 1) == 1) {
		bloom_tiles = texelFetch(colortex0, ivec2(gl_FragCoord.xy), 0).rgb;
	} else {
		discard;
	}
}

#endif
//----------------------------------------------------------------------------//
