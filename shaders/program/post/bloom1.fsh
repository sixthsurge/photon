/*
 * Program description:
 * Vertical blur for bloom
 */

#include "/include/global.glsl"

//--// Outputs //-------------------------------------------------------------//

/* RENDERTARGETS: 2 */
layout (location = 0) out vec3 bloomTile;

//--// Inputs //--------------------------------------------------------------//

in vec2 coord;

//--// Uniforms //------------------------------------------------------------//

uniform sampler2D colortex2; // Bloom tiles

//--// Custom uniforms

uniform vec2 windowSize;
uniform vec2 windowTexelSize;

//--// Functions //-----------------------------------------------------------//

const vec4 binomialWeights7 = vec4(0.3125, 0.234375, 0.09375, 0.015625);

void main() {
#ifndef BLOOM
	#error "This program should be disabled if bloom is disabled"
#endif

	ivec2 texel = ivec2(gl_FragCoord.xy);

	float tileIndex = ceil(-log2(coord.x));
	float tileSize = exp2(-tileIndex);

	ivec2[2] tileBounds;
	tileBounds[0] = ivec2(tileSize * windowSize);
	tileBounds[1] = ivec2((tileSize + tileSize) * windowSize - 1.0);
	if (clamp(texel, tileBounds[0], tileBounds[1]) != texel || tileIndex > BLOOM_TILES) return;

	bloomTile = vec3(0.0);
	for (int y = -3; y <= 3; ++y) {
		float weight = binomialWeights7[abs(y)];
		ivec2 texel = clamp(texel + ivec2(0, y), tileBounds[0], tileBounds[1]);
		bloomTile += texelFetch(colortex2, texel, 0).rgb * weight;
	}
}
