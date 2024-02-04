#ifndef INCLUDE_TONEMAPPING_ZCAM_JUSTJOHN
#define INCLUDE_TONEMAPPING_ZCAM_JUSTJOHN

#include "/include/utility/color.glsl"

/*
*   MIT License
*
*   Copyright (c) 2023 John Payne
*
*   Permission is hereby granted, free of charge, to any person obtaining a copy
*   of this software and associated documentation files (the "Software"), to deal
*   in the Software without restriction, including without limitation the rights
*   to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
*   copies of the Software, and to permit persons to whom the Software is
*   furnished to do so, subject to the following conditions:
*
*   The above copyright notice and this permission notice shall be included in all
*   copies or substantial portions of the Software.
*
*   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
*   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
*   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
*   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
*   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
*   OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
*   SOFTWARE.
*/

// eotf_pq parameters
const float Lp = 10000.0;
const float m1 = 2610.0 / 16384.0;
const float m2 = 1.7 * 2523.0 / 32.0;
const float c1 = 107.0 / 128.0;
const float c2 = 2413.0 / 128.0;
const float c3 = 2392.0 / 128.0;

vec3 eotf_pq(vec3 x) {
    x = sign(x) * pow(abs(x), vec3(1.0 / m2));
    x = sign(x) * pow((abs(x) - c1) / (c2 - c3 * abs(x)), vec3(1.0 / m1)) * Lp;
    return x;
}

vec3 eotf_pq_inverse(vec3 x) {
    x /= Lp;
    x = sign(x) * pow(abs(x), vec3(m1));
    x = sign(x) * pow((c1 + c2 * abs(x)) / (1.0 + c3 * abs(x)), vec3(m2));
    return x;
}

// XYZ <-> ICh parameters
const float W = 140.0;
const float b = 1.15;
const float g = 0.66;

vec3 XYZ_to_ICh(vec3 XYZ) {
    XYZ *= W;
    XYZ.xy = vec2(b, g) * XYZ.xy - (vec2(b, g) - 1.0) * XYZ.zx;

    const mat3 XYZ_to_LMS = transpose(mat3(
     0.41479,   0.579999, 0.014648,
    -0.20151,   1.12065,  0.0531008,
    -0.0166008, 0.2648,   0.66848));

    vec3 LMS = XYZ_to_LMS * XYZ;
    LMS = eotf_pq_inverse(LMS);

    const mat3 LMS_to_Iab = transpose(mat3(
     0.0,       1.0,      0.0,
     3.524,    -4.06671,  0.542708,
     0.199076,  1.0968,  -1.29588));

    vec3 Iab = LMS_to_Iab * LMS;

    float I = eotf_pq(vec3(Iab.x)).x / W;
    float C = length(Iab.yz);
    float h = atan(Iab.z, Iab.y);
    return vec3(I, C, h);
}

vec3 ICh_to_XYZ(vec3 ICh) {
    vec3 Iab;
    Iab.x = eotf_pq_inverse(vec3(ICh.x * W)).x;
    Iab.y = ICh.y * cos(ICh.z);
    Iab.z = ICh.y * sin(ICh.z);

    const mat3 Iab_to_LMS = transpose(mat3(
         1.0, 0.2772,  0.1161,
         1.0, 0.0,     0.0,
         1.0, 0.0426, -0.7538));

    vec3 LMS = Iab_to_LMS * Iab;
    LMS = eotf_pq(LMS);

    const mat3 LMS_to_XYZ = transpose(mat3(
         1.92423, -1.00479,  0.03765,
         0.35032,  0.72648, -0.06538,
        -0.09098, -0.31273,  1.52277));

    vec3 XYZ = LMS_to_XYZ * LMS;
    XYZ.x = (XYZ.x + (b - 1.0) * XYZ.z) / b;
    XYZ.y = (XYZ.y + (g - 1.0) * XYZ.x) / g;
    return XYZ / W;
}

const mat3 XYZ_to_sRGB = transpose(mat3(
     3.2404542, -1.5371385, -0.4985314,
    -0.9692660,  1.8760108,  0.0415560,
     0.0556434, -0.2040259,  1.0572252));

const mat3 sRGB_to_XYZ = transpose(mat3(
     0.4124564, 0.3575761, 0.1804375,
     0.2126729, 0.7151522, 0.0721750,
     0.0193339, 0.1191920, 0.9503041));

bool in_sRGB_gamut(vec3 ICh) {
    vec3 sRGB = XYZ_to_sRGB * ICh_to_XYZ(ICh);
    return all(greaterThanEqual(sRGB, vec3(0.0))) && all(lessThanEqual(sRGB, vec3(1.0)));
}

bool in_rec2020_gamut(vec3 ICh) {
	vec3 rec2020 = ICh_to_XYZ(ICh) * xyz_to_rec2020;
	return all(greaterThanEqual(rec2020, vec3(0.0))) && all(lessThanEqual(rec2020, vec3(1.0)));
}

vec3 zcam_tonemap_rec2020(vec3 rec2020) {
	vec3 ICh = XYZ_to_ICh(rec2020 * rec2020_to_xyz);
	
	const float s0 = 0.71;
    const float s1 = 1.04;
    const float p = 1.40;
    const float t0 = 0.01;
    float n = s1 * pow(ICh.x / (ICh.x + s0), p);
    ICh.x = clamp(n * n / (n + t0), 0.0, 1.0);
	
	if (!in_rec2020_gamut(ICh)) {
        float C = ICh.y;
        ICh.y -= 0.5 * C;

        for (float i = 0.25; i >= 1.0 / 256.0; i *= 0.5) {
            ICh.y += (in_rec2020_gamut(ICh) ? i : -i) * C;
        }
    }
	
	return ICh_to_XYZ(ICh) * xyz_to_rec2020;
}

vec3 zcam_tonemap(vec3 sRGB) {
    vec3 ICh = XYZ_to_ICh(sRGB_to_XYZ * sRGB);

    const float s0 = 0.71;
    const float s1 = 1.04;
    const float p = 1.40;
    const float t0 = 0.01;
    float n = s1 * pow(ICh.x / (ICh.x + s0), p);
    ICh.x = clamp(n * n / (n + t0), 0.0, 1.0);

    if (!in_sRGB_gamut(ICh))
    {
        float C = ICh.y;
        ICh.y -= 0.5 * C;

        for (float i = 0.25; i >= 1.0 / 256.0; i *= 0.5)
        {
            ICh.y += (in_sRGB_gamut(ICh) ? i : -i) * C;
        }
    }

    return XYZ_to_sRGB * ICh_to_XYZ(ICh);
}

vec3 zcam_gamma_correct(vec3 linear) {
    bvec3 cutoff = lessThan(linear, vec3(0.0031308));
    vec3 higher = 1.055 * pow(linear, vec3(1.0 / 2.4)) - 0.055;
    vec3 lower = linear * 12.92;
    return mix(higher, lower, cutoff);
}

#endif // INCLUDE_TONEMAPPING_ZCAM_JUSTJOHN
