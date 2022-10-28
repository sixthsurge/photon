/*
--------------------------------------------------------------------------------

  Photon Shaders by SixthSurge

  program/post/bloom/downsample.vsh
  Position the bloom tile in the bloom buffer
  You must define BLOOM_TILE_INDEX before including this file

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

out vec2 uv;

const float tileSize   = 0.5 * exp2(-BLOOM_TILE_INDEX);
const float tileOffset = 1.0 - exp2(-BLOOM_TILE_INDEX);

void main() {
	uv = gl_MultiTexCoord0.xy;

	vec2 vertexPos = gl_Vertex.xy * tileSize + tileOffset;

	gl_Position = vec4(vertexPos * 2.0 - 1.0, 0.0, 1.0);
}
