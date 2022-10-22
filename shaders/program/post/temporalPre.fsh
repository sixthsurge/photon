/*
--------------------------------------------------------------------------------

  Photon Shaders by SixthSurge

  program/post/temporalPre.fsh:
  Calculate neighborhood limits for TAAU

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

/* DRAWBUFFERS:67 */
layout (location = 0) out vec3 minColor;
layout (location = 1) out vec3 maxColor;

in vec2 uv;

uniform sampler2D colortex0;

#include "/include/utility/color.glsl"

vec3 minOf(vec3 a, vec3 b, vec3 c, vec3 d, vec3 f) {
    return min(a, min(b, min(c, min(d, f))));
}

vec3 maxOf(vec3 a, vec3 b, vec3 c, vec3 d, vec3 f) {
    return max(a, max(b, max(c, max(d, f))));
}

void main() {
	ivec2 texel = ivec2(gl_FragCoord.xy);

	// Fetch 3x3 neighborhood
	// a b c
	// d e f
	// g h i
	vec3 a = texelFetch(colortex0, texel + ivec2(-1,  1), 0).rgb;
	vec3 b = texelFetch(colortex0, texel + ivec2( 0,  1), 0).rgb;
	vec3 c = texelFetch(colortex0, texel + ivec2( 1,  1), 0).rgb;
	vec3 d = texelFetch(colortex0, texel + ivec2(-1,  0), 0).rgb;
	vec3 e = texelFetch(colortex0, texel, 0).rgb;
	vec3 f = texelFetch(colortex0, texel + ivec2( 1,  0), 0).rgb;
	vec3 g = texelFetch(colortex0, texel + ivec2(-1, -1), 0).rgb;
	vec3 h = texelFetch(colortex0, texel + ivec2( 0, -1), 0).rgb;
	vec3 i = texelFetch(colortex0, texel + ivec2( 1, -1), 0).rgb;

	// Convert to YCoCg
	a = rgbToYcocg(a);
	b = rgbToYcocg(b);
	c = rgbToYcocg(c);
	d = rgbToYcocg(d);
	e = rgbToYcocg(e);
	f = rgbToYcocg(f);
	g = rgbToYcocg(g);
	h = rgbToYcocg(h);
	i = rgbToYcocg(i);

	// Soft minimum and maximum ("Hybrid Reconstruction Antialiasing")
	//        b         a b c
	// (min d e f + min d e f) / 2
	//        h         g h i
	minColor  = minOf(b, d, e, f, h);
	minColor += minOf(minColor, a, c, g, i);
	minColor *= 0.5;

	maxColor  = maxOf(b, d, e, f, h);
	maxColor += maxOf(maxColor, a, c, g, i);
	maxColor *= 0.5;
}

#ifndef TAAU
	#error "This program should be disabled if TAAU is disabled"
#endif
