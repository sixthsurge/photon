/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/post/temporal_pre.glsl:
  Calculate neighborhood limits for TAAU

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"


//----------------------------------------------------------------------------//
#if defined vsh

out vec2 uv;

void main() {
	uv = gl_MultiTexCoord0.xy;

	vec2 vertex_pos = gl_Vertex.xy * taau_render_scale;
	gl_Position = vec4(vertex_pos * 2.0 - 1.0, 0.0, 1.0);
}

#endif
//----------------------------------------------------------------------------//



//----------------------------------------------------------------------------//
#if defined fsh

layout (location = 0) out vec3 min_color;
layout (location = 1) out vec3 max_color;

/* RENDERTARGETS: 13,14 */

in vec2 uv;

uniform sampler2D colortex0;

#include "/include/utility/color.glsl"

vec3 min_of(vec3 a, vec3 b, vec3 c, vec3 d, vec3 f) {
    return min(a, min(b, min(c, min(d, f))));
}

vec3 max_of(vec3 a, vec3 b, vec3 c, vec3 d, vec3 f) {
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
	a = rgb_to_ycocg(a);
	b = rgb_to_ycocg(b);
	c = rgb_to_ycocg(c);
	d = rgb_to_ycocg(d);
	e = rgb_to_ycocg(e);
	f = rgb_to_ycocg(f);
	g = rgb_to_ycocg(g);
	h = rgb_to_ycocg(h);
	i = rgb_to_ycocg(i);

	// Soft minimum and maximum ("Hybrid Reconstruction Antialiasing")
	//        b         a b c
	// (min d e f + min d e f) / 2
	//        h         g h i
	min_color  = min_of(b, d, e, f, h);
	min_color += min_of(min_color, a, c, g, i);
	min_color *= 0.5;

	max_color  = max_of(b, d, e, f, h);
	max_color += max_of(max_color, a, c, g, i);
	max_color *= 0.5;
}

#endif
//----------------------------------------------------------------------------//

#ifndef TAAU
	#error "This program should be disabled if TAAU is disabled"
#endif
