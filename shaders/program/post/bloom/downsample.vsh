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

#define bloomTileScale(i) 0.5 * exp2(-(i))
#define bloomTileOffset(i) vec2(            \
	1.0 - exp2(-(i)),                       \
	float((i) & 1) * (1.0 - 0.5 * exp2(-(i))) \
)

const float tileScale = bloomTileScale(BLOOM_TILE_INDEX);
const vec2 tileOffset = bloomTileOffset(BLOOM_TILE_INDEX);

void main() {
	uv = gl_MultiTexCoord0.xy;

	vec2 vertexPos = gl_Vertex.xy * tileScale + tileOffset;

	gl_Position = vec4(vertexPos * 2.0 - 1.0, 0.0, 1.0);
}
