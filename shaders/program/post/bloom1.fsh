/*
 * Program description:
 * Downsample + blur horizontally
 */

#include "/include/global.glsl"

//--// Outputs //-------------------------------------------------------------//

/* RENDERTARGETS: 15 */
layout (location = 0) out vec3 bloom;

//--// Inputs //--------------------------------------------------------------//

in vec2 coord;

//--// Uniforms //------------------------------------------------------------//

uniform sampler2D colortex15; // Bloom buffer

//--// Functions //-----------------------------------------------------------//

/*
const bool colortex15MipmapEnabled = true;
*/

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

	vec2 padAmount = 1.0 * rcp(vec2(960.0, 540.0)) * tileScale;
	tileCoord = linearStep(padAmount, 1.0 - padAmount, tileCoord);

	float pixelSize = tileScale.x * rcp(960.0);

	bloom = vec3(0.0);

	for (int x = -3; x <= 3; ++x) {
		float weight = binomialWeights7[abs(x)];

		vec2 sampleCoord = clamp01(tileCoord + vec2(x * pixelSize, 0.0));

		bloom += textureLod(colortex15, sampleCoord * vec2(1.0, 0.5), int(tileIndex - 1.0)).rgb * weight;
	}
}
