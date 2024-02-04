/*
--------------------------------------------------------------------------------

  Photon Shaders by SixthSurge

  program/post/grade.glsl:
  Apply bloom, color grading and tone mapping then convert to rec. 709

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

/* DRAWBUFFERS:0 */

in vec2 uv;

// ------------
//   Uniforms
// ------------

uniform sampler2D colortex0; // bloom tiles
uniform sampler2D colortex3; // fog transmittance
uniform sampler2D colortex5; // scene color

uniform float aspectRatio;
uniform float blindness;
uniform float darknessFactor;
uniform float frameTimeCounter;

uniform float biome_cave;
uniform float time_noon;
uniform float eye_skylight;

uniform vec2 view_pixel_size;

#include "/include/tonemapping/aces/aces.glsl"
#include "/include/tonemapping/agx.glsl"
#include "/include/tonemapping/zcam_justjohn.glsl"
#include "/include/utility/bicubic.glsl"
#include "/include/utility/color.glsl"

// Bloom

vec3 get_bloom(out vec3 fog_bloom) {
	const int tile_count = 6;
	const float radius  = 1.0;

	vec3 tile_sum = vec3(0.0);

	float weight = 1.0;
	float weight_sum = 0.0;

#if defined BLOOMY_FOG || defined BLOOMY_RAIN
	const float fog_bloom_radius = 1.5;

	fog_bloom = vec3(0.0); // large-scale bloom for bloomy fog
	float fog_bloom_weight = 1.0;
	float fog_bloom_weight_sum = 0.0;
#endif

	for (int i = 0; i < tile_count; ++i) {
		float a = exp2(float(-i));

		float tile_scale = 0.5 * a;
		vec2 tile_offset = vec2(1.0 - a, float(i & 1) * (1.0 - 0.5 * a));

		vec2 tile_coord = uv * tile_scale + tile_offset;

		vec3 tile = bicubic_filter(colortex0, tile_coord).rgb;

		tile_sum += tile * weight;
		weight_sum += weight;

		weight *= radius;

#if defined BLOOMY_FOG || defined BLOOMY_RAIN
		fog_bloom += tile * fog_bloom_weight;

		fog_bloom_weight_sum += fog_bloom_weight;
		fog_bloom_weight *= fog_bloom_radius;
#endif
	}

#if defined BLOOMY_FOG || defined BLOOMY_RAIN
	fog_bloom /= fog_bloom_weight_sum;
#endif

	return tile_sum / weight_sum;
}

// Color grading

vec3 gain(vec3 x, float k) {
    vec3 a = 0.5 * pow(2.0 * mix(x, 1.0 - x, step(0.5, x)), vec3(k));
    return mix(a, 1.0 - a, step(0.5, x));
}

// Color grading applied before tone mapping
// rgb := color in acescg [0, inf]
vec3 grade_input(vec3 rgb) {
	float brightness = 0.83 * GRADE_BRIGHTNESS;
	float contrast   = 1.00 * GRADE_CONTRAST;
	float saturation = 0.98 * GRADE_SATURATION;

	// Brightness
	rgb *= brightness;

	// Contrast
	const float log_midpoint = log2(0.18);
	rgb = log2(rgb + eps);
	rgb = contrast * (rgb - log_midpoint) + log_midpoint;
	rgb = max0(exp2(rgb) - eps);

	// Saturation
	float lum = dot(rgb, luminance_weights);
	rgb = max0(mix(vec3(lum), rgb, saturation));

#if GRADE_WHITE_BALANCE != 6500
	// White balance (slow)
	vec3 src_xyz = blackbody(float(GRADE_WHITE_BALANCE)) * rec2020_to_xyz;
	vec3 dst_xyz = blackbody(                    6500.0) * rec2020_to_xyz;
	mat3 cat = get_chromatic_adaptation_matrix(src_xyz, dst_xyz);

	rgb = rgb * rec2020_to_xyz;
	rgb = rgb * cat;
	rgb = rgb * xyz_to_rec2020;
#endif

	return rgb;
}

// Color grading applied after tone mapping
// rgb := color in linear rec.709 [0, 1]
vec3 grade_output(vec3 rgb) {
	// Convert to roughly perceptual RGB for color grading
	rgb = sqrt(rgb);

	// HSL color grading inspired by Tech's color grading setup in Lux Shaders

	const float orange_sat_boost = GRADE_ORANGE_SAT_BOOST;
	const float teal_sat_boost   = GRADE_TEAL_SAT_BOOST;
	const float green_sat_boost  = GRADE_GREEN_SAT_BOOST;
	const float green_hue_shift  = GRADE_GREEN_HUE_SHIFT / 360.0;

	vec3 hsl = rgb_to_hsl(rgb);

	// Oranges
	float orange = isolate_hue(hsl, 30.0, 20.0); //isolate_hue(hsl, 30.0, 20.0) // custom : 20.0, 30.0
	hsl.y *= 1.0 + orange_sat_boost * orange;

	// Teals
	float teal = isolate_hue(hsl, 210.0, 20.0);
	hsl.y *= 1.0 + teal_sat_boost * teal;

	// Greens
	float green = isolate_hue(hsl, 90.0, 53.0); //isolate_hue(hsl, 90.0, 44.0) // custom : 90.0, 53.0
	hsl.x += green_hue_shift * green;
	hsl.y *= 1.0 + green_sat_boost * green;

	rgb = hsl_to_rgb(hsl);

	rgb = gain(rgb, 1.05);

	return sqr(rgb);
}

// Tonemapping operators

vec3 tonemap_none(vec3 rgb) { return rgb; }

// ACES RRT and ODT
vec3 academy_rrt(vec3 rgb) {
	rgb *= 1.6; // Match the exposure to the RRT

	rgb = rgb * rec709_to_ap0;

#if ACES_LMT != ACES_LMT_NONE
	rgb = aces_lmt(rgb);
#endif
	rgb = aces_rrt(rgb);
	rgb = aces_odt(rgb);

	return rgb * ap1_to_rec709;
}

// ACES RRT and ODT approximation
vec3 academy_fit(vec3 rgb) {
	rgb *= 1.6; // Match the exposure to the RRT

	rgb = rgb * rec709_to_ap0;

#if ACES_LMT != ACES_LMT_NONE
	rgb = aces_lmt(rgb);
#endif
	rgb = rrt_sweeteners(rgb);
	rgb = rrt_and_odt_fit(rgb);

	// Global desaturation
	vec3 grayscale = vec3(dot(rgb, luminance_weights));
	rgb = mix(grayscale, rgb, odt_sat_factor);

	return rgb * ap1_to_rec709;
}

vec3 tonemap_hejl_2015(vec3 rgb) {
	const float white_point = 5.0;

	vec4 vh = vec4(rgb, white_point);
	vec4 va = (1.425 * vh) + 0.05; // eval filmic curve
	vec4 vf = ((vh * va + 0.004) / ((vh * (va + 0.55) + 0.0491))) - 0.0821;

	return vf.rgb / vf.www; // white point correction
}

// Filmic tonemapping operator made by Jim Hejl and Richard Burgess
// Modified by Tech to not lose color information below 0.004
vec3 tonemap_hejl_burgess(vec3 rgb) {
	rgb = rgb * min(vec3(1.0), 1.0 - 0.8 * exp(rcp(-0.004) * rgb));
	rgb = (rgb * (6.2 * rgb + 0.5)) / (rgb * (6.2 * rgb + 1.7) + 0.06);
	return srgb_eotf_inv(rgb); // Revert built-in s_r_g_b conversion
}

// Timothy Lottes 2016, "Advanced Techniques and Optimization of HDR Color Pipelines"
// https://gpuopen.com/wp-content/uploads/2016/03/GdcVdrLottes.pdf
vec3 tonemap_lottes(vec3 rgb) {
	const vec3 a      = vec3(1.5); // Contrast
	const vec3 d      = vec3(0.91); // Shoulder contrast
	const vec3 hdr_max = vec3(8.0);  // White point
	const vec3 mid_in  = vec3(0.26); // Fixed midpoint x
	const vec3 mid_out = vec3(0.32); // Fixed midput y

	const vec3 b =
		(-pow(mid_in, a) + pow(hdr_max, a) * mid_out) /
		((pow(hdr_max, a * d) - pow(mid_in, a * d)) * mid_out);
	const vec3 c =
		(pow(hdr_max, a * d) * pow(mid_in, a) - pow(hdr_max, a) * pow(mid_in, a * d) * mid_out) /
		((pow(hdr_max, a * d) - pow(mid_in, a * d)) * mid_out);

	return pow(rgb, a) / (pow(rgb, a * d) * b + c);
}

// Filmic tonemapping operator made by John Hable for Uncharted 2
vec3 tonemap_uncharted_2_partial(vec3 rgb) {
	const float a = 0.15;
	const float b = 0.50;
	const float c = 0.10;
	const float d = 0.20;
	const float e = 0.02;
	const float f = 0.30;
	const float w = 11.2;

	return ((rgb * (a * rgb + (c * b)) + (d * e)) / (rgb * (a * rgb + b) + d * f)) - e / f;
}

vec3 tonemap_uncharted_2_filmic(vec3 rgb) {
	float exposure_bias = 2.0;
	vec3 curr = tonemap_uncharted_2_partial(rgb * exposure_bias);
	
	vec3 W = vec3(11.2);
	vec3 white_scale = vec3(1.0) / tonemap_uncharted_2_partial(W);
	return curr * white_scale;
}

vec3 tonemap_uncharted_2(vec3 rgb) {
#ifdef UNCHARTED_2_PARTIAL
	rgb *= 3.0;
	return tonemap_uncharted_2_partial(rgb);
#else
	return tonemap_uncharted_2_filmic(rgb);
#endif
}

// Tone mapping operator made by Tech for his shader pack Lux
vec3 tonemap_tech(vec3 rgb) {
	vec3 a = rgb * min(vec3(1.0), 1.0 - exp(-1.0 / 0.038 * rgb));
	a = mix(a, rgb, rgb * rgb);
	return a / (a + 0.6);
}

// Tonemapping operator made by Zombye for his old shader pack Ozius
// It was given to me by Jessie
vec3 tonemap_ozius(vec3 rgb) {
    const vec3 a = vec3(0.46, 0.46, 0.46);
    const vec3 b = vec3(0.60, 0.60, 0.60);

	rgb *= 1.6;

    vec3 cr = mix(vec3(dot(rgb, luminance_weights_ap1)), rgb, 0.5) + 1.0;

    rgb = pow(rgb / (1.0 + rgb), a);
    return pow(rgb * rgb * (-2.0 * rgb + 3.0), cr / b);
}

vec3 tonemap_reinhard(vec3 rgb) {
	return rgb / (rgb + 1.0);
}

vec3 tonemap_reinhard_jodie(vec3 rgb) {
	vec3 reinhard = rgb / (rgb + 1.0);
	return mix(rgb / (dot(rgb, luminance_weights) + 1.0), reinhard, reinhard);
}

// Uchimura 2017, "HDR theory and practice"
// Math: https://www.desmos.com/calculator/gslcdxvipg
// Source: https://www.slideshare.net/nikuque/hdr-theory-and-practicce-jp
vec3 tonemap_uchimura(vec3 rgb) {
	const float P = UCHIMURA_MAX_BRIGHTNESS;  // max display brightness
	const float a = UCHIMURA_CONTRAST;  // contrast
	const float m = UCHIMURA_LINEAR_SECTION_START; // linear section start
	const float l = UCHIMURA_LINEAR_SECTION_LENGTH;  // linear section length
	const float c = UCHIMURA_BLACK_TIGHTNESS; // black
	const float b = UCHIMURA_BLACK_PEDESTAL;  // pedestal

	float l0 = ((P - m) * l) / a;
	float L0 = m - m / a;
	float L1 = m + (1.0 - m) / a;
	float S0 = m + l0;
	float S1 = m + a * l0;
	float C2 = (a * P) / (P - S1);
	float CP = -C2 / P;

	vec3 w0 = vec3(1.0 - smoothstep(0.0, m, rgb));
	vec3 w2 = vec3(step(m + l0, rgb));
	vec3 w1 = vec3(1.0 - w0 - w2);

	vec3 T = vec3(m * pow(rgb / m, vec3(c)) + b);
	vec3 S = vec3(P - (P - S1) * exp(CP * (rgb - S0)));
	vec3 L = vec3(m + a * (rgb - m));

	return T * w0 + L * w1 + S * w2;
}

vec3 tonemap_justjohn(vec3 rgb) {
	rgb *= 1.6;
#ifdef JJS_ZCAM_REC2020
	rgb = zcam_tonemap_rec2020(rgb);
#else
	vec3 sRGB = rgb * working_to_display_color;
	sRGB = zcam_tonemap(sRGB);
	//sRGB = zcam_gamma_correct(sRGB);
	rgb = sRGB * display_to_working_color;
#endif
	return rgb;
}

// Minimal implementation of Troy Sobotka's AgX display transform by bwrensch
// Source: https://www.shadertoy.com/view/cd3XWr
//         https://iolite-engine.com/blog_posts/minimal_agx_implementation
// Original: https://github.com/sobotka/AgX
vec3 tonemap_agx(vec3 rgb) {
	//rgb = srgb_eotf(rgb);

	rgb = agx_pre(rgb);

	// Apply sigmoid function approximation
	rgb = agx_default_contrast_approx(rgb);
#if AGX_LOOK != 0
	rgb = agx_look(rgb);
#endif
#ifdef AGX_EOTF
	rgb = agx_eotf(rgb);
#endif

	return srgb_eotf_inv(rgb);
}


float vignette(vec2 uv) {
    const float vignette_size = 16.0;
    const float vignette_intensity = 0.08 * VIGNETTE_INTENSITY;

	float darkness_pulse = 1.0 - dampen(abs(cos(2.0 * frameTimeCounter)));

    float vignette = vignette_size * (uv.x * uv.y - uv.x) * (uv.x * uv.y - uv.y);
          vignette = pow(vignette, vignette_intensity + 0.1 * biome_cave + 0.3 * blindness + 0.2 * darkness_pulse * darknessFactor);

    return vignette;
}

void main() {
	ivec2 texel = ivec2(gl_FragCoord.xy);

	scene_color = texelFetch(colortex5, texel, 0).rgb;

	float exposure = texelFetch(colortex5, ivec2(0), 0).a;

#ifdef BLOOM
	vec3 fog_bloom;
	vec3 bloom = get_bloom(fog_bloom);
	float bloom_intensity = 0.12 * BLOOM_INTENSITY;

	scene_color = mix(scene_color, bloom, bloom_intensity);

#ifdef BLOOMY_FOG
	float fog_transmittance = texture(colortex3, uv * taau_render_scale).x;
	scene_color = mix(fog_bloom, scene_color, pow(fog_transmittance, BLOOMY_FOG_INTENSITY));
#endif
#endif

	scene_color *= exposure;

#ifdef VIGNETTE
	scene_color *= vignette(uv);
#endif

	scene_color = grade_input(scene_color);

/* "/include/tonemapping/zcam_justjohn.glsl" */
#ifdef JJS_ZCAM_COLORTEST
	vec2 position = vec2(uv.x - frameTimeCounter * 0.2, uv.y);
	vec3 ICh = vec3(exp(position.y * 3.0) - 1.0, 0.07, position.x * 5.0);
    vec3 sRGB = max(vec3(0.0), XYZ_to_sRGB * ICh_to_XYZ(ICh));
	sRGB = sRGB * display_to_working_color;
	scene_color = sRGB;
	scene_color = uv.x < 0.5 ? tonemap_left(scene_color) : tonemap_right(scene_color);
#endif

#ifdef TONEMAP_COMPARISON
	scene_color = uv.x < 0.5 ? tonemap_left(scene_color) : tonemap_right(scene_color);
#else
	scene_color = tonemap(scene_color);
#endif

	scene_color = clamp01(scene_color * working_to_display_color);
	scene_color = grade_output(scene_color);

#ifdef TONEMAP_PLOT // Tonemap plot
	const float scale = 2.0;
	vec2 uv_scaled = uv * scale * vec2(1.0, 1.0 / aspectRatio);
	float x = uv_scaled.x;
	float y = tonemap(vec3(x)).x;

	if (abs(uv_scaled.x - 1.0) < 0.001 * scale) scene_color = vec3(1.0, 0.0, 0.0);
	if (abs(uv_scaled.y - 1.0) < 0.001 * scale) scene_color = vec3(1.0, 0.0, 0.0);
	if (abs(uv_scaled.y - y) < 0.001 * scale) scene_color = vec3(1.0);
#endif
}

#endif
//----------------------------------------------------------------------------//
