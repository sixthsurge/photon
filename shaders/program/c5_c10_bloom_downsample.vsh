/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/c5_c10_bloom_downsample
  Progressively downsample bloom tiles
  You must define BLOOM_TILE_INDEX before including this file

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

#define bloom_tile_scale(i) 0.5 * exp2(-(i))
#define bloom_tile_offset(i) vec2(            \
	1.0 - exp2(-(i)),                       \
	float((i) & 1) * (1.0 - 0.5 * exp2(-(i))) \
)

out vec2 uv;

uniform vec2 view_pixel_size;

const float tile_scale = bloom_tile_scale(BLOOM_TILE_INDEX);
const vec2 tile_offset = bloom_tile_offset(BLOOM_TILE_INDEX);

void main() {
	uv = gl_MultiTexCoord0.xy;

	vec2 vertex_pos = gl_Vertex.xy * tile_scale + tile_offset;

	gl_Position = vec4(vertex_pos * 2.0 - 1.0, 0.0, 1.0);
}

