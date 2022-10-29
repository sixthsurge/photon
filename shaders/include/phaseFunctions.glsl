#if !defined PHASEFUNCTIONS_INCLUDED
#define PHASEFUNCTIONS_INCLUDED

#include "/include/utility/fastMath.glsl"

const float isotropicPhase = 0.25 / pi;

vec3 rayleighPhase(float nu) {
	const vec3 depolarization = vec3(2.786, 2.842, 2.899) * 1e-2;
	const vec3 gamma = depolarization / (2.0 - depolarization);
	const vec3 k = 3.0 / (16.0 * pi * (1.0 + 2.0 * gamma));

	vec3 phase = (1.0 + 3.0 * gamma) + (1.0 - gamma) * sqr(nu);

	return k * phase;
}

float henyeyGreensteinPhase(float nu, float g) {
	float gg = g * g;

	return (isotropicPhase - isotropicPhase * gg) / pow1d5(1.0 + gg - 2.0 * g * nu);
}

float cornetteShanksPhase(float nu, float g) {
	float gg = g * g;

	float p1 = 1.5 * (1.0 - gg) / (2.0 + gg);
	float p2 = (1.0 + nu * nu) / pow1d5((1.0 + gg - 2.0 * g * nu));

	return p1 * p2 * isotropicPhase;
}

// Far closer to an actual aerosol phase function than Henyey-Greenstein or Cornette-Shanks
float kleinNishinaPhase(float nu, float e) {
	return e / (tau * (e - e * nu + 1.0) * log(2.0 * e + 1.0));
}

// A phase function specifically designed for leaves. kD is the diffuse reflection, and smaller
// values returns a brighter phase value. Thanks to Jessie for sharing this in the #snippets channel
// of the shaderLABS discord server
float bilambertianPlatePhase(float nu, float kD) {
	float phase = 2.0 * (-pi * nu * kD + sqrt(clamp01(1.0 - sqr(nu))) + nu * fastAcos(-nu));
	return phase * rcp(3.0 * pi * pi);
}

#endif // PHASEFUNCTIONS_INCLUDED
