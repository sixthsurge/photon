#if !defined INCLUDE_UTILITY_PHASE_FUNCTIONS
#define INCLUDE_UTILITY_PHASE_FUNCTIONS

#include "fast_math.glsl"

const float isotropic_phase = 0.25 / pi;

vec3 rayleigh_phase(float nu) {
	const vec3 depolarization = vec3(2.786, 2.842, 2.899) * 1e-2;
	const vec3 gamma = depolarization / (2.0 - depolarization);
	const vec3 k = 3.0 / (16.0 * pi * (1.0 + 2.0 * gamma));

	vec3 phase = (1.0 + 3.0 * gamma) + (1.0 - gamma) * sqr(nu);

	return k * phase;
}

float henyey_greenstein_phase(float nu, float g) {
	float gg = g * g;

	return (isotropic_phase - isotropic_phase * gg) / pow1d5(1.0 + gg - 2.0 * g * nu);
}

float cornette_shanks_phase(float nu, float g) {
	float gg = g * g;

	float p1 = 1.5 * (1.0 - gg) / (2.0 + gg);
	float p2 = (1.0 + nu * nu) / pow1d5((1.0 + gg - 2.0 * g * nu));

	return p1 * p2 * isotropic_phase;
}

// Far closer to an actual aerosol phase function than Henyey-Greenstein or Cornette-Shanks
float klein_nishina_phase(float nu, float e) {
	return e / (tau * (e - e * nu + 1.0) * log(2.0 * e + 1.0));
}

float klein_nishina_phase_area(float nu, float e, float radius) {
	//quick and dirty area light approximation by xyber
    float radius_eff=max(radius,0.05);//Prevent divide by 0 and fix small sizes (angular_size <= 0.2)
    float energy_scale = e / (6000.0);// use 6000 because its the prior default energy to give artistic control, scaled down by 2 as artistic control and to offset the clamping
    float e_area = energy_scale / (1.0 - cos(radius_eff)); //calculate percieved "energy" due to area 
    float cosr = cos(radius);
    float sinr = sin(radius);
    // shifted cosine with clamp to avoid dark hole
    float mu = nu * cosr + sqrt(max(0.0, 1.0 - nu * nu)) * sinr;
    if (nu > cosr) {
        mu = 1.0; // keep center bright
    }
    return e_area / (tau * (e_area - e_area * mu + 1.0) * log(2.0 * e_area + 1.0));
}

float nvidia_phase(float nu, float g, float a){
    float gg = g*g;
    return ((1 - gg)*(1 + a*nu*nu))/(pi * pow1d5(1+gg-(2*g*nu))*4.0*(1 + (a*(1 + 2*gg))/3.0));
}

float nvidia_phase_area(float nu, float g, float a,float radius){
    float radius_eff=max(radius,eps);//Prevent divide by 0 
    float cosr = cos(radius_eff);
    float sinr = sin(radius_eff);
    float mu = nu * cosr + sqrt(max(0.0, 1.0 - nu * nu)) * sinr;
    if (nu > cosr) {
        mu = 1.0; // keep center bright
    }
    float gg = g*g;
    return ((1 - gg)*(1 + a*mu*mu))/(pi * pow1d5(1+gg-(2*g*mu))*4.0*(1 + (a*(1 + 2*gg))/3.0));
}



// A phase function specifically designed for leaves. k_d is the diffuse reflection, and smaller
// values returns a brighter phase value. Thanks to Jessie for sharing this in the #snippets channel
// of the shader_l_a_b_s discord server
float bilambertian_plate_phase(float nu, float k_d) {
	float phase = 2.0 * (-pi * nu * k_d + sqrt(clamp01(1.0 - sqr(nu))) + nu * fast_acos(-nu));
	return phase * rcp(3.0 * pi * pi);
}

#endif // INCLUDE_UTILITY_PHASE_FUNCTIONS
