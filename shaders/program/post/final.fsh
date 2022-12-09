/*
--------------------------------------------------------------------------------

  Photon Shaders by SixthSurge

  program/post/final.fsh:
  CAS, dithering, debug views

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

out vec3 fragColor;

in vec2 uv;

uniform sampler2D colortex0; // Scene color

#if DEBUG_VIEW == DEBUG_VIEW_SAMPLER
uniform sampler2D DEBUG_SAMPLER;
#endif

uniform float viewHeight;

#include "/include/utility/bicubic.glsl"
#include "/include/utility/color.glsl"
#include "/include/utility/dithering.glsl"
#include "/include/utility/textRendering.glsl"

const int debugTextScale = 2;
ivec2 debugTextPosition = ivec2(0, int(viewHeight) / debugTextScale);

vec3 minOf(vec3 a, vec3 b, vec3 c, vec3 d, vec3 f) {
	return min(a, min(b, min(c, min(d, f))));
}

vec3 maxOf(vec3 a, vec3 b, vec3 c, vec3 d, vec3 f) {
	return max(a, max(b, max(c, max(d, f))));
}

// FidelityFX contrast-adaptive sharpening filter
// https://github.com/GPUOpen-Effects/FidelityFX-CAS
vec3 textureCas(sampler2D sampler, ivec2 texel, const float sharpness) {
#ifndef CAS
	return linearToSrgb(texelFetch(sampler, texel, 0).rgb);
#endif

	// Fetch 3x3 neighborhood
	// a b c
	// d e f
	// g h i
	vec3 a = texelFetch(sampler, texel + ivec2(-1, -1), 0).rgb;
	vec3 b = texelFetch(sampler, texel + ivec2( 0, -1), 0).rgb;
	vec3 c = texelFetch(sampler, texel + ivec2( 1, -1), 0).rgb;
	vec3 d = texelFetch(sampler, texel + ivec2(-1,  0), 0).rgb;
	vec3 e = texelFetch(sampler, texel, 0).rgb;
	vec3 f = texelFetch(sampler, texel + ivec2( 1,  0), 0).rgb;
	vec3 g = texelFetch(sampler, texel + ivec2(-1,  1), 0).rgb;
	vec3 h = texelFetch(sampler, texel + ivec2( 0,  1), 0).rgb;
	vec3 i = texelFetch(sampler, texel + ivec2( 1,  1), 0).rgb;

    // Convert to sRGB before performing CAS
    a = linearToSrgb(a);
    b = linearToSrgb(b);
    c = linearToSrgb(c);
    d = linearToSrgb(d);
    e = linearToSrgb(e);
    f = linearToSrgb(f);
    g = linearToSrgb(g);
    h = linearToSrgb(h);
    i = linearToSrgb(i);

	// Soft min and max. These are 2x bigger (factored out the extra multiply)
	vec3 minColor  = minOf(d, e, f, b, h);
	     minColor += minOf(minColor, a, c, g, i);

	vec3 maxColor  = maxOf(d, e, f, b, h);
	     maxColor += maxOf(maxColor, a, c, g, i);

	// Smooth minimum distance to the signal limit divided by smooth max
	vec3 w  = clamp01(min(minColor, 2.0 - maxColor) / maxColor);
	     w  = 1.0 - sqr(1.0 - w); // Shaping amount of sharpening
	     w *= -1.0 / mix(8.0, 5.0, sharpness);

	// Filter shape:
	// 0 w 0
	// w 1 w
	// 0 w 0
	vec3 weightSum = 1.0 + 4.0 * w;
	return clamp01((b + d + f + h) * w + e) / weightSum;
}

void main() {
    ivec2 texel = ivec2(gl_FragCoord.xy);

	if (abs(MC_RENDER_QUALITY - 1.0) < 0.01) {
		fragColor = textureCas(colortex0, texel, CAS_INTENSITY * 2.0 - 1.0);
	} else {
		fragColor = textureCatmullRomFastRgb(colortex0, uv, 0.6);
	    fragColor = linearToSrgb(fragColor);
	}

	fragColor = dither8Bit(fragColor, bayer16(vec2(texel)));

#if   DEBUG_VIEW == DEBUG_VIEW_SAMPLER
	if (clamp(texel, ivec2(0), ivec2(textureSize(DEBUG_SAMPLER, 0))) == texel) {
		fragColor = texelFetch(DEBUG_SAMPLER, texel, 0).rgb;
		fragColor = linearToSrgb(fragColor);
	}
#endif
}
