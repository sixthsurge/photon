#ifndef INCLUDE_TONEMAPPING_ACES_GAMUT_COMPRESS
#define INCLUDE_TONEMAPPING_ACES_GAMUT_COMPRESS

//
// Gamut compression algorithm to bring out-of-gamut scene-referred values into AP1
//

//
// Usage:
//  This transform is intended to be applied to AP0 data, immediately after the IDT, so
//  that all grading or compositing operations are downstream of the compression, and
//  therefore work only with positive AP1 values.
//
// Input and output: ACES2065-1
//

#include "/include/tonemapping/aces/matrices.glsl"

/* --- Gamut Compress Parameters --- */
// Distance from achromatic which will be compressed to the gamut boundary
// Values calculated to encompass the encoding gamuts of common digital cinema cameras
const float LIM_CYAN =  1.147;
const float LIM_MAGENTA = 1.264;
const float LIM_YELLOW = 1.312;

// Percentage of the core gamut to protect
// Values calculated to protect all the colors of the ColorChecker Classic 24 as given by
// ISO 17321-1 and Ohta (1997)
const float THR_CYAN = 0.815;
const float THR_MAGENTA = 0.803;
const float THR_YELLOW = 0.880;

// Aggressiveness of the compression curve
const float PWR = 1.2;

// Calculate compressed distance
float compress(float dist, float lim, float thr, float pwr) {
    float compr_dist;
    float scl;
    float nd;
    float p;

    if (dist < thr) {
        compr_dist = dist; // No compression below threshold
    } else {
        // Calculate scale factor for y = 1 intersect
        scl = (lim - thr) / pow(pow((1.0 - thr) / (lim - thr), -pwr) - 1.0, 1.0 / pwr);

        // Normalize distance outside threshold by scale factor
        nd = (dist - thr) / scl;
        p = pow(nd, pwr);

        compr_dist = thr + scl * nd / (pow(1.0 + p, 1.0 / pwr)); // Compress
    }

    return compr_dist;
}

vec3 gamut_compress(vec3 ap0) {
    // Convert to ACEScg
    vec3 lin_ap1 = ap0 * ap0_to_ap1;

    // Achromatic axis
    float ach = max_of(lin_ap1);

    // Distance from the achromatic axis for each color component aka inverse RGB ratios
    vec3 dist = (ach == 0.0) ? vec3(0.0) : (ach - lin_ap1) / abs(ach);

    // Compress distance with parameterized shaper function
    vec3 compr_dist = vec3(
        compress(dist.r, LIM_CYAN, THR_CYAN, PWR),
        compress(dist.g, LIM_MAGENTA, THR_MAGENTA, PWR),
        compress(dist.b, LIM_YELLOW, THR_YELLOW, PWR)
    );

    // Recalculate RGB from compressed distance and achromatic
    vec3 compr_lin_ap1 = ach - compr_dist * abs(ach);

    // Convert back to ACES2065-1
    ap0 = compr_lin_ap1 * ap1_to_ap0;
    return ap0;
}

#endif //INCLUDE_TONEMAPPING_ACES_GAMUT_COMPRESS
