/*
--------------------------------------------------------------------------------

  Photon Shaders by SixthSurge

  program/post/bloom/gaussY.fsh
  1D vertical gaussian blur pass for bloom tiles

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

/* DRAWBUFFERS:0 */
layout (location = 0) out vec3 bloomTiles;

in vec2 uv;

uniform sampler2D colortex0;

uniform vec2 viewSize;

#define bloomTileScale(i) 0.5 * exp2(-(i))
#define bloomTileOffset(i) vec2(            \
	1.0 - exp2(-(i)),                       \
	float((i) & 1) * (1.0 - 0.5 * exp2(-(i))) \
)

const float[5] binomialWeights9 = float[5](
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
	int tileIndex = int(a);

	float tileScale = bloomTileScale(tileIndex);
	vec2 tileOffset = bloomTileOffset(tileIndex);

	ivec2 boundsMin = ivec2(viewSize * tileOffset);
	ivec2 boundsMax = ivec2(viewSize * (tileOffset + tileScale));

	// Apply padding around bloom tiles

	if (clamp(texel.y, boundsMin.y, boundsMax.y) != texel.y || tileIndex > 5) {
		// Get index of closest tile
		int closestTile = (uv.y < 0.66)
			? int(0.5 * a + 0.25) * 2
			: int(0.5 * a - 0.25) * 2 + 1;

		// Get bounds of closest tile
		float closestScale = bloomTileScale(closestTile);
		vec2 closestOffset = bloomTileOffset(closestTile);
		ivec2 closestBoundsMin = ivec2(viewSize * closestOffset + 1);
		ivec2 closestBoundsMax = ivec2(viewSize * (closestOffset + closestScale) - 1);

		// Clamp to closest tile
		bloomTiles = texelFetch(colortex0, clamp(texel, closestBoundsMin, closestBoundsMax), 0).rgb;

		return;
	}

	// Vertical 9-tap gaussian blur

	bloomTiles = vec3(0.0);
	float weightSum = 0.0;

	for (int i = -4; i <= 4; ++i) {
		ivec2 pos    = texel + ivec2(0, i);
		float weight = binomialWeights9[abs(i)] * float(clamp(pos.y, boundsMin.y + 2, boundsMax.y - 2) == pos.y);
		bloomTiles  += texelFetch(colortex0, pos, 0).rgb * weight;
		weightSum   += weight;
	}

	bloomTiles /= weightSum;
}
