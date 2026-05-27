#if !defined INCLUDE_MISC_TONEMAP_OPERATORS
#define INCLUDE_MISC_TONEMAP_OPERATORS

#include "/include/post_processing/aces/aces.glsl"
#include "/include/utility/color.glsl"

// ACES RRT and ODT
vec3 tonemap_aces_full(vec3 rgb) {
    rgb *= 1.6; // Match the exposure to the RRT

    rgb = rgb * rec2020_to_ap0;

#ifdef HDR_ENABLED
    rgb = aces_output_transform(rgb, 0.0001f, 15.0f, HdrGamePeakBrightness)
        * HdrGamePeakBrightness / HdrGamePaperWhiteBrightness;
#else

    rgb = aces_rrt(rgb);
    rgb = aces_odt(rgb);
#endif

    return rgb * ap1_to_rec2020;
}

// ACES RRT and ODT approximation
vec3 tonemap_aces_fit(vec3 rgb) {
    rgb *= 1.6; // Match the exposure to the RRT

    rgb = rgb * rec2020_to_ap0;

    rgb = rrt_sweeteners(rgb);
    rgb = rrt_and_odt_fit(rgb);

    // Global desaturation
    vec3 grayscale = vec3(dot(rgb, luminance_weights));
    rgb = mix(grayscale, rgb, odt_sat_factor);

    return rgb * ap1_to_rec2020;
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
    return srgb_eotf_inv(rgb); // Revert built-in sRGB conversion
}

// Timothy Lottes 2016, "Advanced Techniques and Optimization of HDR Color
// Pipelines" https://gpuopen.com/wp-content/uploads/2016/03/GdcVdrLottes.pdf
vec3 tonemap_lottes(vec3 rgb) {
    const vec3 a = vec3(1.5); // Contrast
    const vec3 d = vec3(0.91); // Shoulder contrast
    const vec3 hdr_max = vec3(8.0); // White point
    const vec3 mid_in = vec3(0.26); // Fixed midpoint x
    const vec3 mid_out = vec3(0.32); // Fixed midput y

    const vec3 b = (-pow(mid_in, a) + pow(hdr_max, a) * mid_out)
        / ((pow(hdr_max, a * d) - pow(mid_in, a * d)) * mid_out);
    const vec3 c = (pow(hdr_max, a * d) * pow(mid_in, a)
                    - pow(hdr_max, a) * pow(mid_in, a * d) * mid_out)
        / ((pow(hdr_max, a * d) - pow(mid_in, a * d)) * mid_out);

    return pow(rgb, a) / (pow(rgb, a * d) * b + c);
}

#ifdef HDR_ENABLED
vec3 reinhard_with_peak(vec3 x, float peak) { return x / (x / peak + 1.0); }

vec3 reinhard_extended(vec3 x, float white_max, float peak) {
    return reinhard_with_peak(x, peak)
        * (1.0 + (peak * x) / (white_max * white_max));
}

float compute_reinhard_extendable_scale(
    float w,
    float p,
    float m,
    float x,
    float y
) {
    return p * (w * w * y - (p * x * x)) / (w * w * x * (p - y));
}

vec3 reinhard_piecewise_extended(
    vec3 x,
    float white_max,
    float x_max,
    float shoulder
) {
    const float x_min = 0.0f;
    float exposure = compute_reinhard_extendable_scale(
        white_max,
        x_max,
        x_min,
        shoulder,
        shoulder
    );
    vec3 extended
        = reinhard_extended(x * exposure, white_max * exposure, x_max);
    extended = min(extended, x_max);
    return mix(x, extended, step(shoulder, x));
}

vec3 tonemap_reinhard_piecewise_extended(vec3 rgb) {
    return sign(rgb)
        * reinhard_piecewise_extended(
               abs(rgb),
               10000.0 / HdrGamePaperWhiteBrightness,
               HdrGamePeakBrightness / HdrGamePaperWhiteBrightness,
               36.0 / HdrGamePaperWhiteBrightness
        );
}

float apply_hable_curve(
    float x,
    float a,
    float b,
    float c,
    float d,
    float e,
    float f
) {
    float numerator
        = x * (a * x + c * b) + d * e; // x * (a * x + c * b) + d * e
    float denominator = x * (a * x + b) + d * f; // x * (a * x + b) + d * f
    return (numerator / denominator) - (e / f);
}

vec3 apply_hable_curve(
    vec3 x,
    float a,
    float b,
    float c,
    float d,
    float e,
    float f
) {
    vec3 numerator = x * (a * x + c * b) + d * e; // x * (a * x + c * b) + d * e
    vec3 denominator = x * (a * x + b) + d * f; // x * (a * x + b) + d * f
    return (numerator / denominator) - (e / f);
}

float apply_hable_inverse_uncharted2(
    float y,
    float W,
    float A,
    float B,
    float C,
    float D,
    float E,
    float F
) {
    // 1. Recover raw ApplyCurve output: y_raw = y * ApplyCurve(W)
    float rawW = apply_hable_curve(W, A, B, C, D, E, F);
    float y_raw = y * rawW;

    // 2. Solve inverse of ApplyCurve analytically (quadratic)
    float ef = E / F;
    float yp = y_raw + ef;

    // Quadratic coefficients:
    // A_q x^2 + B_q x + C_q = 0
    float A_q = A * (yp - 1.0);
    float B_q = B * (yp - C);
    float C_q = D * (F * yp - E);

    // Quadratic discriminant
    float disc = B_q * B_q - 4.0 * A_q * C_q;
    disc = max(disc, 0.0);
    float sqrtD = sqrt(disc);

    float x1 = (-B_q + sqrtD) / (2.0 * A_q);
    float x2 = (-B_q - sqrtD) / (2.0 * A_q);

    // pick the physically meaningful root (positive, usually x1)
    return max(x1, x2);
}

vec3 apply_hable_inverse_uncharted2(
    vec3 color,
    float W,
    float A,
    float B,
    float C,
    float D,
    float E,
    float F
) {
    return vec3(
        apply_hable_inverse_uncharted2(color.r, W, A, B, C, D, E, F),
        apply_hable_inverse_uncharted2(color.g, W, A, B, C, D, E, F),
        apply_hable_inverse_uncharted2(color.b, W, A, B, C, D, E, F)
    );
}

float hable_derivative(
    float x,
    float a,
    float b,
    float c,
    float d,
    float e,
    float f
) {
    float num = -a * b * (c - 1.0) * x * x + 2.0 * a * d * (f - e) * x
        + b * d * (c * f - e);

    float den = x * (a * x + b) + d * f;
    den = den * den;

    return num / den;
}

// Root of f'(x) = 0 for the raw ApplyCurve, using quadratic formula.
// With a,b,c,d,e,f > 0 and 0 < c < 1, this is well-defined.
float hable_find_derivative_root(
    float a,
    float b,
    float c,
    float d,
    float e,
    float f
) {
    // Quadratic coefficients for numerator of f'(x)
    // -a*b*(c - 1) * x^2 + 2*a*d*(f - e)*x + b*d*(c*f - e) = 0
    float Aq = a * b * (1.f - c); // -a*b*(c-1)
    float Bq = 2.f * a * d * (f - e);
    float Cq = b * d * (c * f - e);

    // Discriminant
    float disc = Bq * Bq - 4.f * Aq * Cq;
    disc = max(disc, 0.f); // just in case of tiny negatives

    float sqrtDisc = sqrt(disc);

    float r1 = (-Bq + sqrtDisc) / (2.f * Aq);
    float r2 = (-Bq - sqrtDisc) / (2.f * Aq);

    // Larger root of the quadratic
    float root = max(r1, r2);

    // Only care about non-negative x in our domain
    return max(root, 0.f);
}

// Analytic knee root of f'''(x) = 0 for Uncharted2/Hable ApplyCurve
// a,b,c,d,e,f > 0, typically 0 < c < 1.
// Returns the smallest positive real root ("first knee") in x > 0.
float hable_find_third_derivative_root(
    float a,
    float b,
    float c,
    float d,
    float e,
    float f
) {
    // sqrt(a b^2 c^2 - 2 a b^2 c + a b^2)
    float sqrt_ab = sqrt(a * b * b * c * c - 2.f * a * b * b * c + a * b * b);

    // sqrt(a d^2 e^2 - 2 a d^2 e f + a d^2 f^2
    //    + b^2 c^2 d f + b^2 (-c) d e - b^2 c d f + b^2 d e)
    float sqrt_df = sqrt(
        a * d * d * e * e - 2.f * a * d * d * e * f + a * d * d * f * f
        + b * b * c * c * d * f + b * b * (-c) * d * e - b * b * c * d * f
        + b * b * d * e
    );

    // Precompute (d e - d f)
    float de_df = d * e - d * f;

    // Inner big piece: sqrt_ab * (...) / (8 * sqrt_df)
    float term_top = 32.f
        * (a * d * d * e * f - a * d * d * f * f + b * b * c * d * f
           - b * b * d * e)
        / (a * a * b * (c - 1.f));

    float term_mid
        = 96.f * de_df * (c * d * f - d * e) / (a * b * (c - 1.f) * (c - 1.f));

    float de_df2 = de_df * de_df;
    float de_df3 = de_df2 * de_df;

    float term_tail
        = 64.f * de_df3 / (b * b * b * (c - 1.f) * (c - 1.f) * (c - 1.f));

    float Tfrac = sqrt_ab * (term_top - term_mid - term_tail) / (8.f * sqrt_df);

    // (12 a^2 b c d f - 12 a^2 b d e) / (6 (a^3 b c - a^3 b))
    float Tmid2_num = 12.f * a * a * b * c * d * f - 12.f * a * a * b * d * e;
    float Tmid2_den = 6.f * (a * a * a * b * c - a * a * a * b);
    float Tmid2 = Tmid2_num / Tmid2_den;

    // (6 (c d f - d e))/(a (c - 1))
    float T3 = 6.f * (c * d * f - d * e) / (a * (c - 1.f));

    // (8 (d e - d f)^2)/(b^2 (c - 1)^2)
    float T4 = 8.f * de_df2 / (b * b * (c - 1.f) * (c - 1.f));

    // Centers for the ± branches
    float centerNeg = -Tfrac + Tmid2 + T3 + T4; // used with sqrt(-centerNeg)
    float centerPos = Tfrac + Tmid2 + T3 + T4; // used with sqrt( centerPos)

    // Branch square roots: use SignSqrt for robustness and correct branch
    // behaviour
    float sNeg = sqrt(abs(centerNeg)) * sign(-centerNeg);
    float sPos = sqrt(abs(centerPos)) * sign(centerPos);

    // Shifts:
    //  - first two roots use:  - sqrt_df/sqrt_ab - (d e - d f)/(b (c - 1))
    //  - last two use:          sqrt_df/sqrt_ab - (d e - d f)/(b (c - 1))
    float shift1
        = sqrt_df / sqrt_ab + de_df / (b * (c - 1.f)); // we subtract this
    float shift2 = sqrt_df / sqrt_ab - de_df / (b * (c - 1.f)); // we add this

    // The four analytic roots from WA, mapped to floats:
    float r1 = -0.5f * sNeg - shift1; // -1/2 * sqrt(-centerNeg) - shift1
    float r2 = 0.5f * sNeg - shift1; //  1/2 * sqrt(-centerNeg) - shift1
    float r3 = -0.5f * sPos + shift2; // -1/2 * sqrt( centerPos) + shift2
    float r4 = 0.5f * sPos + shift2; //  1/2 * sqrt( centerPos) + shift2

    // Max root seems to be always be the right one
    float root = clamp(max(r1, max(r2, max(r3, r4))), 0, 1);

    return root;
}

struct Hable_Uncharted2ExtendedConfig {
    float pivot_point;
    float white_precompute;
    float coeffs[6]; // A,B,C,D,E,F
};

Hable_Uncharted2ExtendedConfig Hable_CreateUncharted2ExtendedConfig(
    float pivot_point,
    float coeffs[6],
    float white_precompute
) {
    Hable_Uncharted2ExtendedConfig cfg;
    cfg.pivot_point = pivot_point;
    cfg.white_precompute = white_precompute;
    cfg.coeffs = coeffs;

    return cfg;
}

Hable_Uncharted2ExtendedConfig
Hable_CreateUncharted2ExtendedConfig(float coeffs[6], float white_precompute) {
    float pivot_point = hable_find_third_derivative_root(
        coeffs[0],
        coeffs[1],
        coeffs[2],
        coeffs[3],
        coeffs[4],
        coeffs[5]
    );
    return Hable_CreateUncharted2ExtendedConfig(
        pivot_point,
        coeffs,
        white_precompute
    );
}

float apply_hable_extended(
    float x,
    float base,
    float pivot_point,
    float white_precompute,
    float A,
    float B,
    float C,
    float D,
    float E,
    float F
) {
    float pivot_x = pivot_point;
    float pivot_y
        = apply_hable_curve(pivot_x, A, B, C, D, E, F) * white_precompute;
    float slope
        = hable_derivative(pivot_x, A, B, C, D, E, F) * white_precompute;
    float offset = pivot_y - slope * pivot_x;

    float extended = slope * x + offset;

    return mix(base, extended, step(pivot_x, x));
}

float apply_hable_extended(
    float x,
    float base,
    Hable_Uncharted2ExtendedConfig uc2_config
) {
    return apply_hable_extended(
        x,
        base,
        uc2_config.pivot_point,
        uc2_config.white_precompute,
        uc2_config.coeffs[0],
        uc2_config.coeffs[1],
        uc2_config.coeffs[2],
        uc2_config.coeffs[3],
        uc2_config.coeffs[4],
        uc2_config.coeffs[5]
    );
}

float apply_hable_extended(float x, Hable_Uncharted2ExtendedConfig uc2_config) {
    float base
        = apply_hable_curve(
              x,
              uc2_config.coeffs[0],
              uc2_config.coeffs[1],
              uc2_config.coeffs[2],
              uc2_config.coeffs[3],
              uc2_config.coeffs[4],
              uc2_config.coeffs[5]
          )
        * uc2_config.white_precompute;
    return apply_hable_extended(x, base, uc2_config);
}

vec3 apply_hable_extended(
    vec3 x,
    vec3 base,
    float pivot_point,
    float white_precompute,
    float A,
    float B,
    float C,
    float D,
    float E,
    float F
) {
    float pivot_x = pivot_point;
    float pivot_y
        = apply_hable_curve(pivot_x, A, B, C, D, E, F) * white_precompute;
    float slope
        = hable_derivative(pivot_x, A, B, C, D, E, F) * white_precompute;
    vec3 offset = vec3(pivot_y - slope * pivot_x);

    vec3 extended = vec3(slope) * x + offset;

    return mix(base, extended, step(vec3(pivot_x), x));
}

vec3 apply_hable_extended(
    vec3 x,
    vec3 base,
    Hable_Uncharted2ExtendedConfig uc2_config
) {
    return apply_hable_extended(
        x,
        base,
        uc2_config.pivot_point,
        uc2_config.white_precompute,
        uc2_config.coeffs[0],
        uc2_config.coeffs[1],
        uc2_config.coeffs[2],
        uc2_config.coeffs[3],
        uc2_config.coeffs[4],
        uc2_config.coeffs[5]
    );
}

vec3 apply_hable_extended(vec3 x, Hable_Uncharted2ExtendedConfig uc2_config) {
    vec3 base
        = apply_hable_curve(
              x,
              uc2_config.coeffs[0],
              uc2_config.coeffs[1],
              uc2_config.coeffs[2],
              uc2_config.coeffs[3],
              uc2_config.coeffs[4],
              uc2_config.coeffs[5]
          )
        * uc2_config.white_precompute;
    return apply_hable_extended(x, base, uc2_config);
}

vec3 tonemap_uncharted_2(vec3 rgb) {
    const float a = 0.15;
    const float b = 0.50;
    const float c = 0.10;
    const float d = 0.20;
    const float e = 0.02;
    const float f = 0.30;
    const float exposure_bias = 2.0;
    const float w = 11.2;
    float[6] coeffs = float[6](a, b, c, d, e, f);
    float white_precompute = 1.f / apply_hable_curve(w, a, b, c, d, e, f);
    Hable_Uncharted2ExtendedConfig uc2_config
        = Hable_CreateUncharted2ExtendedConfig(coeffs, white_precompute);

    float peak = (HdrGamePeakBrightness / HdrGamePaperWhiteBrightness);
    float shoulder = (36.0 / HdrGamePaperWhiteBrightness);

    rgb *= exposure_bias;

    rgb = apply_hable_extended(abs(rgb), uc2_config) * sign(rgb);
    return reinhard_piecewise_extended(
        rgb,
        100,
        HdrGamePeakBrightness / HdrGamePaperWhiteBrightness,
        36.0 / HdrGamePaperWhiteBrightness
    );
}

#else
// Filmic tonemapping operator made by John Hable for Uncharted 2
vec3 tonemap_uncharted_2_partial(vec3 rgb) {
    const float a = 0.15;
    const float b = 0.50;
    const float c = 0.10;
    const float d = 0.20;
    const float e = 0.02;
    const float f = 0.30;

    return ((rgb * (a * rgb + (c * b)) + (d * e))
            / (rgb * (a * rgb + b) + d * f))
        - e / f;
}

vec3 tonemap_uncharted_2(vec3 rgb) {
    const float exposure_bias = 2.0;
    const vec3 w = vec3(11.2);

    vec3 curr = tonemap_uncharted_2_partial(rgb * exposure_bias);
    vec3 white_scale = vec3(1.0) / tonemap_uncharted_2_partial(w);
    return curr * white_scale;
}

#endif

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

vec3 tonemap_reinhard(vec3 rgb) { return rgb / (rgb + 1.0); }

vec3 tonemap_reinhard_jodie(vec3 rgb) {
    vec3 reinhard = rgb / (rgb + 1.0);
    return mix(rgb / (dot(rgb, luminance_weights) + 1.0), reinhard, reinhard);
}

vec3 tonemap_none(vec3 rgb) { return rgb; }

#endif // INCLUDE_MISC_TONEMAP_OPERATORS
