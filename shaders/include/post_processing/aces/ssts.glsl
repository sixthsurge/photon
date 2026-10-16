#if !defined INCLUDE_ACES_SSTS
#define INCLUDE_ACES_SSTS

#include "utility.glsl"

struct TsPoint {
    float x; // ACES
    float y; // luminance
    float slope;
};

struct TsParams {
    TsPoint min_point;
    TsPoint mid_point;
    TsPoint max_point;
    float coefs_low[6];
    float coefs_high[6];
};

const float min_stop_sdr = -6.5;
const float max_stop_sdr = 6.5;
const float min_stop_rrt = -15.0;
const float max_stop_rrt = 18.0;
const float min_lum_sdr = 0.02;
const float max_lum_sdr = 48.0;
const float min_lum_rrt = 0.0001;
const float max_lum_rrt = 10000.0;
const float half_min = 1e-10;

const mat3 m1 = mat3(0.5, -1.0, 0.5, -1.0, 1.0, 0.5, 0.5, 0.0, 0.0);

float interpolate1d(float x0, float y0, float x1, float y1, float x) {
    float t = (x - x0) / (x1 - x0);
    return mix(y0, y1, t);
}

float lookup_aces_min(float min_lum) {
    float x0 = log10(min_lum_rrt);
    float y0 = min_stop_rrt;
    float x1 = log10(min_lum_sdr);
    float y1 = min_stop_sdr;
    float interp = interpolate1d(x0, y0, x1, y1, log10(min_lum));
    return 0.18 * pow(2.0, interp);
}

float lookup_aces_max(float max_lum) {
    float x0 = log10(max_lum_sdr);
    float y0 = max_stop_sdr;
    float x1 = log10(max_lum_rrt);
    float y1 = max_stop_rrt;
    float interp = interpolate1d(x0, y0, x1, y1, log10(max_lum));
    return 0.18 * pow(2.0, interp);
}

void init_coefs_low(
    TsPoint ts_point_low,
    TsPoint ts_point_mid,
    out float coefs_low[5]
) {
    float knot_inc_low = (log10(ts_point_mid.x) - log10(ts_point_low.x)) / 3.0;

    coefs_low[0]
        = (ts_point_low.slope * (log10(ts_point_low.x) - 0.5 * knot_inc_low))
        + (log10(ts_point_low.y) - ts_point_low.slope * log10(ts_point_low.x));
    coefs_low[1]
        = (ts_point_low.slope * (log10(ts_point_low.x) + 0.5 * knot_inc_low))
        + (log10(ts_point_low.y) - ts_point_low.slope * log10(ts_point_low.x));

    coefs_low[3]
        = (ts_point_mid.slope * (log10(ts_point_mid.x) - 0.5 * knot_inc_low))
        + (log10(ts_point_mid.y) - ts_point_mid.slope * log10(ts_point_mid.x));
    coefs_low[4]
        = (ts_point_mid.slope * (log10(ts_point_mid.x) + 0.5 * knot_inc_low))
        + (log10(ts_point_mid.y) - ts_point_mid.slope * log10(ts_point_mid.x));

    float x0 = min_stop_rrt;
    float y0 = 0.18;
    float x1 = min_stop_sdr;
    float y1 = 0.35;
    float pct_low = interpolate1d(x0, y0, x1, y1, log2(ts_point_low.x / 0.18));
    coefs_low[2] = log10(ts_point_low.y)
        + pct_low * (log10(ts_point_mid.y) - log10(ts_point_low.y));
}

void init_coefs_high(
    TsPoint ts_point_mid,
    TsPoint ts_point_max,
    out float coefs_high[5]
) {
    float knot_inc_high = (log10(ts_point_max.x) - log10(ts_point_mid.x)) / 3.0;

    coefs_high[0]
        = (ts_point_mid.slope * (log10(ts_point_mid.x) - 0.5 * knot_inc_high))
        + (log10(ts_point_mid.y) - ts_point_mid.slope * log10(ts_point_mid.x));
    coefs_high[1]
        = (ts_point_mid.slope * (log10(ts_point_mid.x) + 0.5 * knot_inc_high))
        + (log10(ts_point_mid.y) - ts_point_mid.slope * log10(ts_point_mid.x));

    coefs_high[3]
        = (ts_point_max.slope * (log10(ts_point_max.x) - 0.5 * knot_inc_high))
        + (log10(ts_point_max.y) - ts_point_max.slope * log10(ts_point_max.x));
    coefs_high[4]
        = (ts_point_max.slope * (log10(ts_point_max.x) + 0.5 * knot_inc_high))
        + (log10(ts_point_max.y) - ts_point_max.slope * log10(ts_point_max.x));

    float x0 = max_stop_sdr;
    float y0 = 0.89;
    float x1 = max_stop_rrt;
    float y1 = 0.90;
    float pct_high = interpolate1d(x0, y0, x1, y1, log2(ts_point_max.x / 0.18));
    coefs_high[2] = log10(ts_point_mid.y)
        + pct_high * (log10(ts_point_max.y) - log10(ts_point_mid.y));
}

float shift(float in_, float exp_shift) {
    return pow(2.0, (log2(in_) - exp_shift));
}

TsParams init_ts_params(float min_lum, float max_lum, float exp_shift) {
    TsPoint min_pt;
    min_pt.x = lookup_aces_min(min_lum);
    min_pt.y = min_lum;
    min_pt.slope = 0.0;

    TsPoint mid_pt;
    mid_pt.x = 0.18;
    mid_pt.y = 4.8;
    mid_pt.slope = 1.55;

    TsPoint max_pt;
    max_pt.x = lookup_aces_max(max_lum);
    max_pt.y = max_lum;
    max_pt.slope = 0.0;

    float c_low[5];
    float c_high[5];
    init_coefs_low(min_pt, mid_pt, c_low);
    init_coefs_high(mid_pt, max_pt, c_high);

    min_pt.x = shift(lookup_aces_min(min_lum), exp_shift);
    mid_pt.x = shift(0.18, exp_shift);
    max_pt.x = shift(lookup_aces_max(max_lum), exp_shift);

    TsParams p;
    p.min_point = min_pt;
    p.mid_point = mid_pt;
    p.max_point = max_pt;

    for (int i = 0; i < 5; i++) {
        p.coefs_low[i] = c_low[i];
        p.coefs_high[i] = c_high[i];
    }
    p.coefs_low[5] = c_low[4];
    p.coefs_high[5] = c_high[4];

    return p;
}

float ssts(float x, TsParams c) {
    const int n_knots_low = 4;
    const int n_knots_high = 4;

    float log_x = log10(max(x, half_min));

    float log_y;

    if (log_x <= log10(c.min_point.x)) {
        log_y = log_x * c.min_point.slope
            + (log10(c.min_point.y) - c.min_point.slope * log10(c.min_point.x));
    } else if ((log_x > log10(c.min_point.x)) && (log_x < log10(c.mid_point.x))) {
        float knot_coord = (n_knots_low - 1) * (log_x - log10(c.min_point.x))
            / (log10(c.mid_point.x) - log10(c.min_point.x));
        int j = int(floor(knot_coord));
        float t = knot_coord - float(j);

        vec3 cf = vec3(c.coefs_low[j], c.coefs_low[j + 1], c.coefs_low[j + 2]);
        vec3 monomials = vec3(t * t, t, 1.0);
        log_y = dot(monomials, m1 * cf);
    } else if (
        (log_x >= log10(c.mid_point.x)) && (log_x < log10(c.max_point.x))
    ) {
        float knot_coord = (n_knots_high - 1) * (log_x - log10(c.mid_point.x))
            / (log10(c.max_point.x) - log10(c.mid_point.x));
        int j = int(floor(knot_coord));
        float t = knot_coord - float(j);

        vec3 cf
            = vec3(c.coefs_high[j], c.coefs_high[j + 1], c.coefs_high[j + 2]);
        vec3 monomials = vec3(t * t, t, 1.0);
        log_y = dot(monomials, m1 * cf);
    } else {
        log_y = log_x * c.max_point.slope
            + (log10(c.max_point.y) - c.max_point.slope * log10(c.max_point.x));
    }

    return pow(10.0, log_y);
}

float inv_ssts(float y, TsParams c) {
    const int n_knots_low = 4;
    const int n_knots_high = 4;

    float knot_inc_low = (log10(c.mid_point.x) - log10(c.min_point.x))
        / float(n_knots_low - 1);
    float knot_inc_high = (log10(c.max_point.x) - log10(c.mid_point.x))
        / float(n_knots_high - 1);

    float knot_y_low[4];
    for (int i = 0; i < 4; i++) {
        knot_y_low[i] = (c.coefs_low[i] + c.coefs_low[i + 1]) / 2.0;
    }
    float knot_y_high[4];
    for (int i = 0; i < 4; i++) {
        knot_y_high[i] = (c.coefs_high[i] + c.coefs_high[i + 1]) / 2.0;
    }

    float log_y = log10(max(y, 1e-10));
    float log_x;

    if (log_y <= log10(c.min_point.y)) {
        log_x = log10(c.min_point.x);
    } else if (
        (log_y > log10(c.min_point.y)) && (log_y <= log10(c.mid_point.y))
    ) {
        int j;
        vec3 cf;
        if (log_y > knot_y_low[0] && log_y <= knot_y_low[1]) {
            cf = vec3(c.coefs_low[0], c.coefs_low[1], c.coefs_low[2]);
            j = 0;
        } else if (log_y > knot_y_low[1] && log_y <= knot_y_low[2]) {
            cf = vec3(c.coefs_low[1], c.coefs_low[2], c.coefs_low[3]);
            j = 1;
        } else if (log_y > knot_y_low[2] && log_y <= knot_y_low[3]) {
            cf = vec3(c.coefs_low[2], c.coefs_low[3], c.coefs_low[4]);
            j = 2;
        } else {
            cf = vec3(0.0);
            j = 0;
        }

        vec3 tmp = m1 * cf;
        float a = tmp.x;
        float b = tmp.y;
        float cc = tmp.z;
        cc = cc - log_y;

        float d = sqrt(b * b - 4.0 * a * cc);
        float t = (2.0 * cc) / (-d - b);
        log_x = log10(c.min_point.x) + (t + float(j)) * knot_inc_low;
    } else if ((log_y > log10(c.mid_point.y)) && (log_y < log10(c.max_point.y))) {
        int j;
        vec3 cf;
        if (log_y >= knot_y_high[0] && log_y <= knot_y_high[1]) {
            cf = vec3(c.coefs_high[0], c.coefs_high[1], c.coefs_high[2]);
            j = 0;
        } else if (log_y > knot_y_high[1] && log_y <= knot_y_high[2]) {
            cf = vec3(c.coefs_high[1], c.coefs_high[2], c.coefs_high[3]);
            j = 1;
        } else if (log_y > knot_y_high[2] && log_y <= knot_y_high[3]) {
            cf = vec3(c.coefs_high[2], c.coefs_high[3], c.coefs_high[4]);
            j = 2;
        } else {
            cf = vec3(0.0);
            j = 0;
        }

        vec3 tmp = m1 * cf;
        float a = tmp.x;
        float b = tmp.y;
        float cc = tmp.z;
        cc = cc - log_y;

        float d = sqrt(b * b - 4.0 * a * cc);
        float t = (2.0 * cc) / (-d - b);
        log_x = log10(c.mid_point.x) + (t + float(j)) * knot_inc_high;
    } else {
        log_x = log10(c.max_point.x);
    }

    return pow(10.0, log_x);
}

vec3 ssts_f3(vec3 x, TsParams c) {
    return vec3(ssts(x.x, c), ssts(x.y, c), ssts(x.z, c));
}

vec3 inv_ssts_f3(vec3 x, TsParams c) {
    return vec3(inv_ssts(x.x, c), inv_ssts(x.y, c), inv_ssts(x.z, c));
}
#endif
// INCLUDE_ACES_SSTS