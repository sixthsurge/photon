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

	float tileIndex = floor(-log2(1.0 - uv.x));

	float tileSize   = 0.5 * exp2(-tileIndex);
	float tileOffset = 1.0 - exp2(-tileIndex);

	ivec2 boundsMin = ivec2(viewSize * tileOffset);
	ivec2 boundsMax = ivec2(viewSize * (tileOffset + tileSize));

	// Discard fragments that aren't part of a bloom tile

	if (clamp(texel.y, boundsMin.y, boundsMax.y) != texel.y) { bloomTiles = vec3(0.0); return; }

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
