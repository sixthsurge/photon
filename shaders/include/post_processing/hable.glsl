#if !defined _INCLUDE_POST_PROCESSING_HABLE
#define _INCLUDE_POST_PROCESSING_HABLE

#include "/include/post_processing/reinhard_piecewise_extended.glsl"

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
    float w,
    float a,
    float b,
    float c,
    float d,
    float e,
    float f
) {
    // 1. Recover raw ApplyCurve output: y_raw = y * ApplyCurve(W)
    float raw_w = apply_hable_curve(w, a, b, c, d, e, f);
    float y_raw = y * raw_w;

    // 2. Solve inverse of ApplyCurve analytically (quadratic)
    float ef = e / f;
    float yp = y_raw + ef;

    // Quadratic coefficients:
    // A_q x^2 + B_q x + C_q = 0
    float a_q = a * (yp - 1.0f);
    float b_q = b * (yp - c);
    float c_q = d * (f * yp - e);

    // Quadratic discriminant
    float disc = b_q * b_q - 4.0f * a_q * c_q;
    disc = max(disc, 0.0f);
    float sqrt_d = sqrt(disc);

    float x1 = (-b_q + sqrt_d) / (2.0f * a_q);
    float x2 = (-b_q - sqrt_d) / (2.0f * a_q);

    // pick the physically meaningful root (positive, usually x1)
    return max(x1, x2);
}

vec3 apply_hable_inverse_uncharted2(
    vec3 color,
    float w,
    float a,
    float b,
    float c,
    float d,
    float e,
    float f
) {
    return vec3(
        apply_hable_inverse_uncharted2(color.r, w, a, b, c, d, e, f),
        apply_hable_inverse_uncharted2(color.g, w, a, b, c, d, e, f),
        apply_hable_inverse_uncharted2(color.b, w, a, b, c, d, e, f)
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
    float num = -a * b * (c - 1.0f) * x * x + 2.0f * a * d * (f - e) * x
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
    float aq = a * b * (1.0f - c); // -a*b*(c-1)
    float bq = 2.0f * a * d * (f - e);
    float cq = b * d * (c * f - e);

    // Discriminant
    float disc = bq * bq - 4.0f * aq * cq;
    disc = max(disc, 0.0f); // just in case of tiny negatives

    float sqrt_disc = sqrt(disc);

    float r1 = (-bq + sqrt_disc) / (2.0f * aq);
    float r2 = (-bq - sqrt_disc) / (2.0f * aq);

    // Larger root of the quadratic
    float root = max(r1, r2);

    // Only care about non-negative x in our domain
    return max(root, 0.0f);
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
    float sqrt_ab = sqrt(a * b * b * c * c - 2.0f * a * b * b * c + a * b * b);

    // sqrt(a d^2 e^2 - 2 a d^2 e f + a d^2 f^2
    //    + b^2 c^2 d f + b^2 (-c) d e - b^2 c d f + b^2 d e)
    float sqrt_df = sqrt(
        a * d * d * e * e - 2.0f * a * d * d * e * f + a * d * d * f * f
        + b * b * c * c * d * f + b * b * (-c) * d * e - b * b * c * d * f
        + b * b * d * e
    );

    // Precompute (d e - d f)
    float de_df = d * e - d * f;

    // Inner big piece: sqrt_ab * (...) / (8 * sqrt_df)
    float term_top = 64.0f
        * (a * d * d * e * f - a * d * d * f * f + b * b * c * d * f
           - b * b * d * e)
        / (a * a * b * (c - 1.0f));

    float term_mid = 96.0f * de_df * (c * d * f - d * e)
        / (a * b * (c - 1.0f) * (c - 1.0f));

    float de_df2 = de_df * de_df;
    float de_df3 = de_df2 * de_df;

    float term_tail
        = 64.0f * de_df3 / (b * b * b * (c - 1.0f) * (c - 1.0f) * (c - 1.0f));

    float tfrac
        = sqrt_ab * (term_top - term_mid - term_tail) / (8.0f * sqrt_df);

    // (12 a^2 b c d f - 12 a^2 b d e) / (6 (a^3 b c - a^3 b))
    float tmid2_num = 12.0f * a * a * b * c * d * f - 12.0f * a * a * b * d * e;
    float tmid2_den = 6.0f * (a * a * a * b * c - a * a * a * b);
    float tmid2 = tmid2_num / tmid2_den;

    // (6 (c d f - d e))/(a (c - 1))
    float t3 = 6.0f * (c * d * f - d * e) / (a * (c - 1.0f));

    // (8 (d e - d f)^2)/(b^2 (c - 1)^2)
    float t4 = 8.0f * de_df2 / (b * b * (c - 1.0f) * (c - 1.0f));

    // Centers for the ± branches
    float center_neg = -tfrac + tmid2 + t3 + t4; // used with sqrt(-center_neg)
    float center_pos = tfrac + tmid2 + t3 + t4; // used with sqrt( center_pos)

    // Branch square roots: use SignSqrt for robustness and correct branch
    // behaviour
    float s_neg = sqrt(abs(center_neg)) * sign(-center_neg);
    float s_pos = sqrt(abs(center_pos)) * sign(center_pos);

    // Shifts:
    //  - first two roots use:  - sqrt_df/sqrt_ab - (d e - d f)/(b (c - 1))
    //  - last two use:          sqrt_df/sqrt_ab - (d e - d f)/(b (c - 1))
    float shift1
        = sqrt_df / sqrt_ab + de_df / (b * (c - 1.0f)); // we subtract this
    float shift2 = sqrt_df / sqrt_ab - de_df / (b * (c - 1.0f)); // we add this

    // The four analytic roots from WA, mapped to floats:
    float r1 = -0.5f * s_neg - shift1; // -1/2 * sqrt(-center_neg) - shift1
    float r2 = 0.5f * s_neg - shift1; //  1/2 * sqrt(-center_neg) - shift1
    float r3 = -0.5f * s_pos + shift2; // -1/2 * sqrt( center_pos) + shift2
    float r4 = 0.5f * s_pos + shift2; //  1/2 * sqrt( center_pos) + shift2

    // Max root seems to be always be the right one
    float root = clamp(max(r1, max(r2, max(r3, r4))), 0.0f, 1.0f);

    return root;
}

struct HableUncharted2ExtendedConfig {
    float pivot_point;
    float white_precompute;
    float coeffs[6]; // A,B,C,D,E,F
};

HableUncharted2ExtendedConfig hable_create_uncharted2_extended_config(
    float pivot_point,
    float coeffs[6],
    float white_precompute
) {
    HableUncharted2ExtendedConfig cfg;
    cfg.pivot_point = pivot_point;
    cfg.white_precompute = white_precompute;
    cfg.coeffs = coeffs;

    return cfg;
}

HableUncharted2ExtendedConfig hable_create_uncharted2_extended_config(
    float coeffs[6],
    float white_precompute
) {
    float pivot_point = hable_find_third_derivative_root(
        coeffs[0],
        coeffs[1],
        coeffs[2],
        coeffs[3],
        coeffs[4],
        coeffs[5]
    );
    return hable_create_uncharted2_extended_config(
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
    float a,
    float b,
    float c,
    float d,
    float e,
    float f
) {
    float pivot_x = pivot_point;
    float pivot_y
        = apply_hable_curve(pivot_x, a, b, c, d, e, f) * white_precompute;
    float slope
        = hable_derivative(pivot_x, a, b, c, d, e, f) * white_precompute;
    float offset = pivot_y - slope * pivot_x;

    float extended = slope * x + offset;

    return mix(base, extended, step(pivot_x, x));
}

float apply_hable_extended(
    float x,
    float base,
    HableUncharted2ExtendedConfig uc2_config
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

float apply_hable_extended(float x, HableUncharted2ExtendedConfig uc2_config) {
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
    float a,
    float b,
    float c,
    float d,
    float e,
    float f
) {
    float pivot_x = pivot_point;
    float pivot_y
        = apply_hable_curve(pivot_x, a, b, c, d, e, f) * white_precompute;
    float slope
        = hable_derivative(pivot_x, a, b, c, d, e, f) * white_precompute;
    vec3 offset = vec3(pivot_y - slope * pivot_x);

    vec3 extended = vec3(slope) * x + offset;

    return mix(base, extended, step(vec3(pivot_x), x));
}

vec3 apply_hable_extended(
    vec3 x,
    vec3 base,
    HableUncharted2ExtendedConfig uc2_config
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

vec3 apply_hable_extended(vec3 x, HableUncharted2ExtendedConfig uc2_config) {
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
#endif // _INCLUDE_POST_PROCESSING_HABLE
