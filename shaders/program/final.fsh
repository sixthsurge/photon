/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/program/final.glsl:
  CAS, dithering, debug views

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

layout (location = 0) out vec3 fragment_color;

in vec2 uv;

// ------------
//   Uniforms
// ------------

uniform sampler2D colortex0; // Scene color

#if DEBUG_VIEW == DEBUG_VIEW_SAMPLER
uniform sampler2D DEBUG_SAMPLER;
#endif

uniform float viewHeight;
uniform float frameTimeCounter;

#ifdef COLORED_LIGHTS
uniform sampler2D shadowtex0;
#endif

#include "/include/utility/bicubic.glsl"
#include "/include/utility/color.glsl"
#include "/include/utility/dithering.glsl"
#include "/include/utility/text_rendering.glsl"

#ifdef DISTANCE_VIEW
uniform sampler2D depthtex0;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform vec2 view_res;
uniform vec2 taa_offset;

uniform float near;
uniform float far;

#include "/include/misc/distant_horizons.glsl"
#include "/include/utility/space_conversion.glsl"
#endif

const int debug_text_scale = 2;
ivec2 debug_text_position = ivec2(0, int(viewHeight) / debug_text_scale);

#if DEBUG_VIEW == DEBUG_VIEW_WEATHER 
#include "/include/misc/debug_weather.glsl"
#endif

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

void draw_iris_required_error_message() {
	fragment_color = vec3(sqr(sin(uv.xy + vec2(0.4, 0.2) * frameTimeCounter)) * 0.5 + 0.3, 1.0);
	begin_text(ivec2(gl_FragCoord.xy) / 3, ivec2(0, viewHeight / 3));
	text.fg_col = vec4(0.0, 0.0, 0.0, 1.0);
	text.bg_col = vec4(0.0);
	print((_I, _r, _i, _s, _space, _i, _s, _space, _r, _e, _q, _u, _i, _r, _e, _d, _space, _f, _o, _r, _space, _f, _e, _a, _t, _u, _r, _e, _space, _quote, _C, _o, _l, _o, _r, _e, _d, _space, _L, _i, _g, _h, _t, _s, _quote));
	print_line(); print_line(); print_line();
	print((_H, _o, _w, _space, _t, _o, _space, _f, _i, _x, _colon));
	print_line();
	print((_space, _space, _minus, _space, _D, _i, _s, _a, _b, _l, _e, _space, _C, _o, _l, _o, _r, _e, _d, _space, _L, _i, _g, _h, _t, _s, _space, _i, _n, _space, _t, _h, _e, _space, _L, _i, _g, _h, _t, _i, _n, _g, _space, _m, _e, _n, _u));
	print_line();
	print((_space, _space, _minus, _space, _I, _n, _s, _t, _a, _l, _l, _space, _I, _r, _i, _s, _space, _1, _dot, _6, _space, _o, _r, _space, _a, _b, _o, _v, _e));
	print_line();
	end_text(fragment_color);
}

void main() {
#if defined COLORED_LIGHTS && !defined IS_IRIS
	draw_iris_required_error_message();
	return;
#endif

    ivec2 texel = ivec2(gl_FragCoord.xy);

	if (abs(MC_RENDER_QUALITY - 1.0) < 0.01) {
		fragment_color = cas_filter(colortex0, texel, CAS_INTENSITY * 2.0 - 1.0);
	} else {
		fragment_color = catmull_rom_filter_fast_rgb(colortex0, uv, 0.6);
	    fragment_color = display_eotf(fragment_color);
	}

	fragment_color = dither_8bit(fragment_color, bayer16(vec2(texel)));

#if   DEBUG_VIEW == DEBUG_VIEW_SAMPLER
	if (clamp(texel, ivec2(0), ivec2(textureSize(DEBUG_SAMPLER, 0))) == texel) {
		fragment_color = texelFetch(DEBUG_SAMPLER, texel, 0).rgb;
		fragment_color = display_eotf(fragment_color);
	}
#elif DEBUG_VIEW == DEBUG_VIEW_WEATHER 
	debug_weather(fragment_color);
#endif

#ifdef DISTANCE_VIEW 
	float depth = texelFetch(depthtex0, ivec2(uv * view_res * taau_render_scale), 0).x;

	vec3 position_screen = vec3(uv, depth);
	vec3 position_view = screen_to_view_space(gbufferProjectionInverse, position_screen, true);

	bool is_sky = depth == 1.0;

	#ifdef DISTANT_HORIZONS
    float depth_dh = texelFetch(dhDepthTex, texel, 0).x;
	bool is_dh_terrain = is_distant_horizons_terrain(depth, depth_dh);

	if (is_dh_terrain) {
		position_view = screen_to_view_space(dhProjectionInverse, vec3(uv, depth_dh), true);
	}

	is_sky = is_sky && depth_dh == 1.0;
	#endif

	#if DISTANCE_VIEW_METHOD == DISTANCE_VIEW_DISTANCE
	float dist = length(position_view);
	#elif DISTANCE_VIEW_METHOD == DISTANCE_VIEW_DEPTH 
	float dist = -position_view.z;
	#endif

	fragment_color = is_sky 
		? vec3(1.0)
		: vec3(clamp01(dist * rcp(DISTANCE_VIEW_MAX_DISTANCE)));
#endif

#if defined COLORED_LIGHTS && (defined WORLD_NETHER || !defined SHADOW)
	// Must sample shadowtex0 so that the shadow map is rendered
	if (uv.x < 0.0) {
		fragment_color = texture(shadowtex0, uv).rgb;
	}
#endif
}

#include "/include/buffers.glsl"
