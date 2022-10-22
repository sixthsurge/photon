/*
--------------------------------------------------------------------------------

  Photon Shaders by SixthSurge

  program/bloom0.fsh:
  Downsample + horizontal blur

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

/* DRAWBUFFERS:0 */
layout (location = 0) out vec3 bloomTile;

in vec2 uv;

uniform sampler2D colortex5; // Scene color

uniform vec2 viewSize;
uniform vec2 texelSize;

#include "/include/utility/color.glsl"

/*
const bool colortex5MipmapEnabled = true;
*/

const vec4 binomialWeights7 = vec4(0.3125, 0.234375, 0.09375, 0.015625);

vec3 bloomContrast(vec3 color) {
	return color * sqr(getLuminance(color));
}

void main() {
	float tileIndex = ceil(-log2(uv.x));
	float tileScale = exp2(tileIndex);
	float tileOffset = rcp(tileScale);

	vec2 windowCoord = (uv - tileOffset) * tileScale;

	if (clamp01(windowCoord) != windowCoord || tileIndex > float(BLOOM_TILES)) { bloomTile = vec3(0.0); return; };

	vec2 padAmount = 3.0 * texelSize * tileScale;
	windowCoord = linearStep(padAmount, 1.0 - padAmount, windowCoord);

	float pixelSize = tileScale * texelSize.x;

	bloomTile = vec3(0.0);

	for (int x = -3; x <= 3; ++x) {
		float weight = binomialWeights7[abs(x)];

		vec2 sampleCoord = clamp01(windowCoord + vec2(x * pixelSize, 0.0));

		bloomTile += bloomContrast(texture(colortex5, sampleCoord).rgb) * weight;
	}
}

#ifndef BLOOM
	#error "This program should be disabled if bloom is disabled"
#endif
