#ifndef INCLUDE_TONEMAPPING_AGX
#define INCLUDE_TONEMAPPING_AGX

/*
*   Minimal implementation of Troy Sobotka's AgX display transform by bwrensch
*   Source: https://www.shadertoy.com/view/cd3XWr
*           https://iolite-engine.com/blog_posts/minimal_agx_implementation
*   Original: https://github.com/sobotka/AgX
*/

#include "/include/utility/color.glsl"

#ifdef AGX_HIGHER_PRECISION // Mean error^2: 1.85907662e-06
vec3 agx_default_contrast_approx(vec3 x) {
    vec3 x2 = x * x;
    vec3 x4 = x2 * x2;
    vec3 x6 = x4 * x2;

    return - 17.86     * x6 * x
           + 78.01     * x6
           - 126.7     * x4 * x
           + 92.06     * x4
           - 28.72     * x2 * x
           + 4.361     * x2
           - 0.1718    * x
           + 0.002857;
}
#else // Mean error^2: 3.6705141e-06
vec3 agx_default_contrast_approx(vec3 x) {
    vec3 x2 = x * x;
    vec3 x4 = x2 * x2;

    return + 15.5     * x4 * x2
           - 40.14    * x4 * x
           + 31.96    * x4
           - 6.868    * x2 * x
           + 0.4298   * x2
           + 0.1191   * x
           - 0.00232;
}
#endif

vec3 agx_eotf(vec3 val) {
    const mat3 agx_mat_inv = mat3(
        1.19687900512017, -0.0528968517574562, -0.0529716355144438,
        -0.0980208811401368, 1.15190312990417, -0.0980434501171241,
        -0.0990297440797205, -0.0989611768448433, 1.15107367264116
    );

    // Undo input transform
    val = agx_mat_inv * val;

    // sRGB IEC 61966-2-1 2.2 Exponent Reference EOTF Display
    //val = pow(val, vec3(2.2));

    return val;
}

vec3 agx_look(vec3 val) {
    const vec3 lw = vec3(0.2126, 0.7152, 0.0722);
    float luma = dot(val, lw);

    // Default
    vec3 offset = vec3(0.0);
    vec3 slope = vec3(1.0);
    vec3 power = vec3(1.0);
    float sat = 1.0;

#if AGX_LOOK == 1
	  // Golden
    slope = vec3(1.0, 0.9, 0.5);
    power = vec3(0.8);
    sat = 0.8;
#elif AGX_LOOK == 2
	  // Punchy
    slope = vec3(1.0);
    power = vec3(1.35, 1.35, 1.35);
    sat = 1.4;
#elif AGX_LOOK == -1
	  // Custom
    offset = vec3(AGX_OFFSET_R, AGX_OFFSET_G, AGX_OFFSET_B);
    slope = vec3(AGX_SLOPE_R, AGX_SLOPE_G, AGX_SLOPE_B);
    power = vec3(AGX_POWER_R, AGX_POWER_G, AGX_POWER_B);
    sat = AGX_SATURATION;
#endif

	// ASC CDL
    val = pow(val * slope + offset, power);
    return luma + sat * (val - luma);
    // Equation: luma + Saturation * [(color * Slope + Offset)^Power - luma]
}

vec3 agx_pre(vec3 rgb) {
    //rgb = srgb_eotf(rgb);
    const mat3 agx_mat = mat3(
        0.842479062253094, 0.0423282422610123, 0.0423756549057051,
        0.0784335999999992,  0.878468636469772,  0.0784336,
        0.0792237451477643, 0.0791661274605434, 0.879142973793104
    );

    const float min_ev = -12.47393f;
    const float max_ev = 4.026069f;

    // Input transform
    rgb = agx_mat * rgb;

    // Log2 space encoding
    rgb = clamp(log2(rgb), min_ev, max_ev);
    rgb = (rgb - min_ev) / (max_ev - min_ev);

	return rgb;
}

#endif  // INCLUDE_TONEMAPPING_AGX
