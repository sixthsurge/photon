/*
 * Program description:
 * Downsample + horizontal blur
 */

#include "/include/global.glsl"

//--// Outputs //-------------------------------------------------------------//

/* RENDERTARGETS: 2 */
layout (location = 0) out vec3 bloomTile;

//--// Inputs //--------------------------------------------------------------//

in vec2 coord;

//--// Uniforms //------------------------------------------------------------//

uniform sampler2D colortex8;

//--// Custom uniforms

uniform vec2 windowSize;
uniform vec2 windowTexelSize;

//--// Functions //-----------------------------------------------------------//

/*
const bool colortex8MipmapEnabled = true;
*/

const vec4 binomialWeights7 = vec4(0.3125, 0.234375, 0.09375, 0.015625);

void main() {
#ifndef BLOOM
	#error "This program should be disabled if bloom is disabled"
#endif

	float tileIndex = ceil(-log2(coord.x));
	float tileScale = exp2(tileIndex);
	float tileOffset = rcp(tileScale);

	vec2 windowCoord = (coord - tileOffset) * tileScale;

	if (clamp01(windowCoord) != windowCoord || tileIndex > float(BLOOM_TILES)) { bloomTile = vec3(0.0); return; };

	vec2 padAmount = 1.0 * windowTexelSize * tileScale;
	windowCoord = linearStep(padAmount, 1.0 - padAmount, windowCoord);

	float pixelSize = tileScale * windowTexelSize.x;

	bloomTile = vec3(0.0);

	for (int x = -3; x <= 3; ++x) {
		float weight = binomialWeights7[abs(x)];

		vec2 sampleCoord = clamp01(windowCoord + vec2(x * pixelSize, 0.0));

		bloomTile += texture(colortex8, sampleCoord).rgb * weight;
	}
}
