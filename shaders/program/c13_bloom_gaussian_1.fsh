/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/post/bloom/gaussian0.fsh
  1D vertical gaussian blur pass for bloom tiles

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

#define bloom_tile_scale(i) 0.5 * exp2(-(i))
#define bloom_tile_offset(i) vec2(            \
	1.0 - exp2(-(i)),                       \
	float((i) & 1) * (1.0 - 0.5 * exp2(-(i))) \
)

layout (location = 0) out vec3 bloom_tiles;

/* RENDERTARGETS: 0 */

in vec2 uv;

uniform sampler2D colortex0;

uniform vec2 view_res;

const float[5] binomial_weights_9 = float[5](
   0.2734375,
   0.21875,
   0.109375,
   0.03125,
   0.00390625
);

void main() {
	ivec2 texel = ivec2(gl_FragCoord.xy);

	// Calculate the bounds of the tile containing the fragment

	float a = -log2(1.0 - uv.x);
	int tile_index = int(a);

	float tile_scale = bloom_tile_scale(tile_index);
	vec2 tile_offset = bloom_tile_offset(tile_index);

	ivec2 bounds_min = ivec2(view_res * tile_offset);
	ivec2 bounds_max = ivec2(view_res * (tile_offset + tile_scale));

	// Apply padding around bloom tiles

	if (clamp(texel.y, bounds_min.y, bounds_max.y) != texel.y || tile_index > 5) {
		// Get index of closest tile
		int closest_tile = (uv.y < 0.66)
			? int(0.5 * a + 0.25) * 2
			: int(0.5 * a - 0.25) * 2 + 1;

		// Get bounds of closest tile
		float closest_scale = bloom_tile_scale(closest_tile);
		vec2 closest_offset = bloom_tile_offset(closest_tile);
		ivec2 closest_bounds_min = ivec2(view_res * closest_offset + 1);
		ivec2 closest_bounds_max = ivec2(view_res * (closest_offset + closest_scale) - 1);

		// Clamp to closest tile
		bloom_tiles = texelFetch(colortex0, clamp(texel, closest_bounds_min, closest_bounds_max), 0).rgb;

		return;
	}

	// Vertical 9-tap gaussian blur

	bloom_tiles = vec3(0.0);
	float weight_sum = 0.0;

	for (int i = -4; i <= 4; ++i) {
		ivec2 pos    = texel + ivec2(0, i);
		float weight = binomial_weights_9[abs(i)] * float(clamp(pos.y, bounds_min.y + 2, bounds_max.y - 2) == pos.y);
		bloom_tiles  += texelFetch(colortex0, pos, 0).rgb * weight;
		weight_sum   += weight;
	}

	bloom_tiles /= weight_sum;
}
