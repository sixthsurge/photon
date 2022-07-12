/*
 * Program description:
 * Blur vertically
 */

#include "/include/global.glsl"

//--// Outputs //-------------------------------------------------------------//

/* RENDERTARGETS: 15 */
layout (location = 0) out vec3 bloom;

//--// Inputs //--------------------------------------------------------------//

in vec2 coord;

//--// Uniforms //------------------------------------------------------------//

uniform sampler2D colortex15; // Bloom tiles

//--// Program //-------------------------------------------------------------//

const vec4 binomialWeights7 = vec4(0.3125, 0.234375, 0.09375, 0.015625);

void main() {
#ifndef BLOOM
	#error "This program should be disabled if bloom is disabled"
#endif

	float tileIndex = ceil(-log2(coord.y));

	vec2 tileScale = exp2(tileIndex) * vec2(0.5, 1.0);
	vec2 tileOffset = vec2(0.0, rcp(tileScale.y));

	vec2 tileCoord = (coord - tileOffset) * tileScale;

	if (clamp01(tileCoord) != tileCoord || tileIndex > float(BLOOM_TILES)) { bloom = vec3(0.0); return; };

	vec2 padAmount = 1.0 * rcp(vec2(960.0, 1080.0)) * tileScale;
	tileCoord = linearStep(padAmount, 1.0 - padAmount, tileCoord);

	float pixelSize = rcp(1080.0);

	bloom = vec3(0.0);

	for (int y = -3; y <= 3; ++y) {
		float weight = binomialWeights7[abs(y)];

		vec2 offset = vec2(0.0, y * pixelSize) * tileScale;

		vec2 sampleCoord = tileCoord + offset;
		     sampleCoord = clamp(sampleCoord, padAmount, 1.0 - padAmount);
			 sampleCoord = sampleCoord * rcp(tileScale) + tileOffset;

		bloom += textureLod(colortex15, sampleCoord, 0).rgb * weight;
	}
}
