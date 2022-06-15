/*
 * Program description:
 * Calculate neighborhood limits for TAA history rectification. Also write out current frame's depth
 * for next frame
 */

#include "/include/global.glsl"

//--// Outputs //-------------------------------------------------------------//

/* RENDERTARGETS: 6,7,13 */
layout (location = 0) out vec3 aabbMin;
layout (location = 1) out vec3 aabbMax;
layout (location = 2) out vec2 depthStore;

//--// Uniforms //------------------------------------------------------------//

uniform sampler2D colortex3; // Scene color

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

//--// Includes //------------------------------------------------------------//

#include "/include/utility/color.glsl"

//--// Functions //-----------------------------------------------------------//

vec3 minOf(vec3 a, vec3 b, vec3 c, vec3 d, vec3 f) {
    return min(a, min(b, min(c, min(d, f))));
}

vec3 maxOf(vec3 a, vec3 b, vec3 c, vec3 d, vec3 f) {
    return max(a, max(b, max(c, max(d, f))));
}

void main() {
	ivec2 texel = ivec2(gl_FragCoord.xy);

	depthStore.x = 1.0 - texelFetch(depthtex0, texel, 0).x;
	depthStore.y = 1.0 - texelFetch(depthtex1, texel, 0).x;

    // Fetch 3x3 neighborhood
    // a b c
    // d e f
    // g h i
    vec3 a = texelFetch(colortex3, texel + ivec2(-1, -1), 0).rgb;
    vec3 b = texelFetch(colortex3, texel + ivec2( 0, -1), 0).rgb;
    vec3 c = texelFetch(colortex3, texel + ivec2( 1, -1), 0).rgb;
    vec3 d = texelFetch(colortex3, texel + ivec2(-1,  0), 0).rgb;
    vec3 e = texelFetch(colortex3, texel, 0).rgb;
    vec3 f = texelFetch(colortex3, texel + ivec2( 1,  0), 0).rgb;
    vec3 g = texelFetch(colortex3, texel + ivec2(-1,  1), 0).rgb;
    vec3 h = texelFetch(colortex3, texel + ivec2( 0,  1), 0).rgb;
    vec3 i = texelFetch(colortex3, texel + ivec2( 1,  1), 0).rgb;

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
	aabbMin  = minOf(b, d, e, f, h);
	aabbMin += minOf(aabbMin, a, c, g, i);
	aabbMin *= 0.5;

	aabbMax  = maxOf(b, d, e, f, h);
	aabbMax += maxOf(aabbMax, a, c, g, i);
	aabbMax *= 0.5;

#ifdef TAA_VARIANCE_CLIPPING
	// Variance clipping ("An Excursion in Temporal Supersampling")
	mat2x3 moments;
	moments[0] = (1.0 / 9.0) * (a + b + c + d + e + f + g + h + i);
	moments[1] = (1.0 / 9.0) * (a * a + b * b + c * c + d * d + e * e + f * f + g * g + h * h + i * i);

	const float gamma = 1.25; // Strictness parameter, higher gamma => less ghosting but more flickering and worse image quality
	vec3 mu = moments[0];
	vec3 sigma = sqrt(moments[1] - moments[0] * moments[0]);

	aabbMin = max(aabbMin, mu - gamma * sigma);
	aabbMax = min(aabbMax, mu + gamma * sigma);
#endif
}
