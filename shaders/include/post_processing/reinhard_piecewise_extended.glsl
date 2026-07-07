#if !defined _INCLUDE_POST_PROCESSING_REINHARD_PIECEWISE_EXTENDED
#define _INCLUDE_POST_PROCESSING_REINHARD_PIECEWISE_EXTENDED
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
#endif // _INCLUDE_POST_PROCESSING_REINHARD_PIECEWISE_EXTENDED