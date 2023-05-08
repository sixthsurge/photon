/*
--------------------------------------------------------------------------------

  Photon Shaders by SixthSurge

  program/program/final.glsl:
  CAS, dithering, debug views

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"


//----------------------------------------------------------------------------//
#if defined vsh

out vec2 uv;

void main() {
	uv = gl_MultiTexCoord0.xy;

	gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 0.0, 1.0);
}

#endif
//----------------------------------------------------------------------------//



//----------------------------------------------------------------------------//
#if defined fsh

layout (location = 0) out vec3 scene_color;

in vec2 uv;

// ------------
//   Uniforms
// ------------

uniform sampler2D colortex0; // Scene color

#if DEBUG_VIEW == DEBUG_VIEW_SAMPLER
uniform sampler2D DEBUG_SAMPLER;
#endif

uniform float viewHeight;

#include "/include/utility/bicubic.glsl"
#include "/include/utility/color.glsl"
#include "/include/utility/dithering.glsl"
#include "/include/utility/text_rendering.glsl"

const int debug_text_scale = 2;
ivec2 debug_text_position = ivec2(0, int(viewHeight) / debug_text_scale);

vec3 min_of(vec3 a, vec3 b, vec3 c, vec3 d, vec3 f) {
	return min(a, min(b, min(c, min(d, f))));
}

vec3 max_of(vec3 a, vec3 b, vec3 c, vec3 d, vec3 f) {
	return max(a, max(b, max(c, max(d, f))));
}

// FidelityFX contrast-adaptive sharpening filter
// https://github.com/GPUOpen-Effects/FidelityFX-CAS
vec3 cas_filter(sampler2D sampler, ivec2 texel, const float sharpness) {
#ifndef CAS
	return display_eotf(texelFetch(sampler, texel, 0).rgb);
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
    a = display_eotf(a);
    b = display_eotf(b);
    c = display_eotf(c);
    d = display_eotf(d);
    e = display_eotf(e);
    f = display_eotf(f);
    g = display_eotf(g);
    h = display_eotf(h);
    i = display_eotf(i);

	// Soft min and max. These are 2x bigger (factored out the extra multiply)
	vec3 min_color  = min_of(d, e, f, b, h);
	     min_color += min_of(min_color, a, c, g, i);

	vec3 max_color  = max_of(d, e, f, b, h);
	     max_color += max_of(max_color, a, c, g, i);

	// Smooth minimum distance to the signal limit divided by smooth max
	vec3 w  = clamp01(min(min_color, 2.0 - max_color) / max_color);
	     w  = 1.0 - sqr(1.0 - w); // Shaping amount of sharpening
	     w *= -1.0 / mix(8.0, 5.0, sharpness);

	// Filter shape:
	// 0 w 0
	// w 1 w
	// 0 w 0
	vec3 weight_sum = 1.0 + 4.0 * w;
	return clamp01((b + d + f + h) * w + e) / weight_sum;
}

void main() {
    ivec2 texel = ivec2(gl_FragCoord.xy);

	if (abs(MC_RENDER_QUALITY - 1.0) < 0.01) {
		scene_color = cas_filter(colortex0, texel, CAS_INTENSITY * 2.0 - 1.0);
	} else {
		scene_color = catmull_rom_filter_fast_rgb(colortex0, uv, 0.6);
	    scene_color = display_eotf(scene_color);
	}

	scene_color = dither_8bit(scene_color, bayer16(vec2(texel)));

#if   DEBUG_VIEW == DEBUG_VIEW_SAMPLER
	texel;
	if (clamp(texel, ivec2(0), ivec2(textureSize(DEBUG_SAMPLER, 0))) == texel) {
		scene_color = texelFetch(DEBUG_SAMPLER, texel, 0).rgb;
		scene_color = display_eotf(scene_color);
	}
#endif
}

#endif
//----------------------------------------------------------------------------//
