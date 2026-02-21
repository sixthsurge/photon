#if !defined INCLUDE_UTILITY_SPHERICAL_HARMONICS
#define INCLUDE_UTILITY_SPHERICAL_HARMONICS

// Intel just can't handle arrays (as parameters or returned values) properly.
// Provide a fallback implementation using mat/vec types and structs.
vec4 sh_coeff_order_1(vec3 direction) {
    float x = direction.x;
    float y = direction.y;
    float z = direction.z;

    return vec4(
        0.2820947918,
        0.4886025119 * x,
        0.4886025119 * z,
        0.4886025119 * y
    );
}

mat3 sh_coeff_order_2(vec3 direction) {
    float x = direction.x;
    float y = direction.y;
    float z = direction.z;

    return mat3(
        0.2820947918,
        0.4886025119 * x,
        0.4886025119 * z,
        0.4886025119 * y,
        1.0925484310 * x * y,
        1.0925484310 * y * z,
        0.3153915653 * (3.0 * z * z - 1.0),
        0.7725484040 * x * z,
        0.3862742020 * (x * x - y * y)
    );
}

vec3 sh_evaluate(mat4x3 f, vec3 direction) {
    vec4 coeff = sh_coeff_order_1(direction);

    return coeff.x * f[0] + coeff.y * f[1] + coeff.z * f[2] + coeff.w * f[3];
}

struct sh3 {
    mat3 f1;
    mat3 f2;
    mat3 f3;
};

vec3 sh_evaluate(sh3 f, vec3 direction) {
    mat3 coeff = sh_coeff_order_2(direction);

    return coeff[0].x * f.f1[0] + coeff[0].y * f.f1[1] + coeff[0].z * f.f1[2] +
        coeff[1].x * f.f2[0] + coeff[1].y * f.f2[1] + coeff[1].z * f.f2[2] +
        coeff[2].x * f.f3[0] + coeff[2].y * f.f3[1] + coeff[2].z * f.f3[2];
}

// Convolve SH using circularly symmetric kernel
sh3 sh_convolve(sh3 f, vec3 kernel) {
    const vec3 k = sqrt(4.0 * pi / vec3(1.0, 3.0, 5.0));

    vec3 mul = k * kernel;

    sh3 result;
    result.f1 = mat3(f.f1[0] * mul.x, f.f1[1] * mul.y, f.f1[2] * mul.y);
    result.f2 = mat3(f.f2[0] * mul.y, f.f2[1] * mul.z, f.f2[2] * mul.z);
    result.f3 = mat3(f.f3[0] * mul.z, f.f3[1] * mul.z, f.f3[2] * mul.z);
    return result;
}

vec3 sh_evaluate_convolved(sh3 f, vec3 kernel, vec3 direction) {
    const vec3 k = sqrt(4.0 * pi / vec3(1.0, 3.0, 5.0));

    vec3 mul = k * kernel;
    mat3 coeff = sh_coeff_order_2(direction);

    return coeff[0].x * f.f1[0] * mul.x + coeff[0].y * f.f1[1] * mul.y +
        coeff[0].z * f.f1[2] * mul.y + coeff[1].x * f.f2[0] * mul.y +
        coeff[1].y * f.f2[1] * mul.z + coeff[1].z * f.f2[2] * mul.z +
        coeff[2].x * f.f3[0] * mul.z + coeff[2].y * f.f3[1] * mul.z +
        coeff[2].z * f.f3[2] * mul.z;
}

// https://www.activision.com/cdn/research/Practical_Real_Time_Strategies_for_Accurate_Indirect_Occlusion_NEW%20VERSION_COLOR.pdf
// section 5
vec3 sh_evaluate_irradiance(sh3 sh, vec3 bent_normal, float visibility) {
    float aperture_angle_sin_sq = clamp01(visibility);
    float aperture_angle_cos_sq = 1.0 - aperture_angle_sin_sq;

    // Zonal harmonics expansion of visibility cone
    vec3 kernel;
    kernel.x = (sqrt(1.0 * pi) / 2.0) * aperture_angle_sin_sq;
    kernel.y = (sqrt(3.0 * pi) / 3.0) *
        (1.0 - aperture_angle_cos_sq * sqrt(aperture_angle_cos_sq));
    kernel.z = (sqrt(5.0 * pi) / 16.0) * aperture_angle_sin_sq *
        (2.0 + 6.0 * aperture_angle_cos_sq);

    return sh_evaluate_convolved(sh, kernel, bent_normal);
}

#endif // INCLUDE_UTILITY_SPHERICAL_HARMONICS
