/*
--------------------------------------------------------------------------------

  Photon Shaders by SixthSurge

  program/bloom0.fsh:
  Vertical blur

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

/* DRAWBUFFERS:0 */
layout (location = 0) out vec3 bloomTile;

in vec2 uv;

uniform sampler2D colortex0; // Bloom tiles

uniform vec2 viewSize;
uniform vec2 texelSize;

const vec4 binomialWeights7 = vec4(0.3125, 0.234375, 0.09375, 0.015625);

void main() {
	float tileIndex = ceil(-log2(uv.x));
	float tileScale = exp2(tileIndex);
	float tileOffset = rcp(tileScale);

	vec2 windowCoord = (uv - tileOffset) * tileScale;

	if (clamp01(windowCoord) != windowCoord || tileIndex > float(BLOOM_TILES)) { bloomTile = vec3(0.0); return; };

	vec2 padAmount = 3.0 * texelSize * tileScale;
	windowCoord = linearStep(padAmount, 1.0 - padAmount, windowCoord);

	float pixelSize = tileScale * texelSize.y;

	bloomTile = vec3(0.0);

	for (int y = -3; y <= 3; ++y) {
		float weight = binomialWeights7[abs(y)];

		vec2 sampleCoord = clamp01(windowCoord + vec2(0.0, y * pixelSize));

		bloomTile += texture(colortex0, sampleCoord * rcp(tileScale) + tileOffset).rgb * weight;
	}
}

#ifndef BLOOM
	#error "This program should be disabled if bloom is disabled"
#endif
