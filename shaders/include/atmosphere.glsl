#if !defined ATMOSPHERE_INCLUDED
#define ATMOSPHERE_INCLUDED

#include "/include/aces/matrices.glsl"

#include "/include/utility/color.glsl"
#include "/include/utility/fastMath.glsl"
#include "/include/utility/geometry.glsl"

#include "/include/phaseFunctions.glsl"

// These have to be macros so that they can be used by constant expressions
#define coneAngleToSolidAngle(theta) (tau * (1.0 - cos(theta)))
#define solidAngleToConeAngle(theta) acos(1.0 - (theta) / tau)

const vec3 airViewerPos = vec3(0.0, 6371e3, 0.0); // Position of the viewer in planet-space

const vec3 baseSunCol = vec3(1.051, 0.985, 0.940); // Color of sunlight in space, obtained from AM0 solar irradiance spectrum from https://www.nrel.gov/grid/solar-resource/spectra-astm-e490.html using the CIE (2006) 2-deg LMS cone fundamentals

const ivec2 transmittanceRes = ivec2(/* mu */ 256, /* r */ 64);
const ivec3 scatteringRes    = ivec3(/* nu */ 16, /* mu */ 64, /* muS */ 32);

const float minMuS = -0.35;

// Atmosphere boundaries

const float planetRadius = 6371e3; // m

const float atmosphereInnerRadius = planetRadius - 1e3; // m
const float atmosphereOuterRadius = planetRadius + 110e3; // m

const float planetRadiusSq = planetRadius * planetRadius;
const float atmosphereThickness = atmosphereOuterRadius - atmosphereInnerRadius;
const float atmosphereInnerRadiusSq = atmosphereInnerRadius * atmosphereInnerRadius;
const float atmosphereOuterRadiusSq = atmosphereOuterRadius * atmosphereOuterRadius;

// Atmosphere coefficients

const float airMieAlbedo = 0.9;
const float airMieEnergyParameter = 3000.0; // Energy parameter for Klein-Nishina phase function

const vec2 airScaleHeights = vec2(8.4e3, 1.25e3); // m

// Coefficients for Rec. 709 primaries transformed to Rec. 2020
const vec3 airRayleighCoefficient = vec3(8.059375432e-06, 1.671209429e-05, 4.080133294e-05) * rec709_to_rec2020;
const vec3 airMieCoefficient      = vec3(1.666442358e-06, 1.812685127e-06, 1.958927896e-06) * rec709_to_rec2020;
const vec3 airOzoneCoefficient    = vec3(8.304280072e-07, 1.314911970e-06, 5.440679729e-08) * rec709_to_rec2020;

const mat2x3 airScatteringCoefficients = mat2x3(airRayleighCoefficient, airMieAlbedo * airMieCoefficient);
const mat3x3 airExtinctionCoefficients = mat3x3(airRayleighCoefficient, airMieCoefficient, airOzoneCoefficient);

/*
 * Mapping functions from Eric Bruneton's 2020 atmosphere implementation
 * https://ebruneton.github.io/precomputed_atmospheric_scattering/atmosphere/functions.glsl.html
 *
 * nu: cos view-light angle
 * mu: cos view-zenith angle
 * muS: cos light-zenith angle
 * r: distance to planet centre
 */

vec3 atmosphereDensity(float r) {
	const vec2 rcpScaleHeights = rcp(airScaleHeights);
	const vec2 scaledPlanetRadius = planetRadius * rcpScaleHeights;

	vec2 rayleighMie = exp(r * -rcpScaleHeights + scaledPlanetRadius);

	// Ozone density distribution from Jessie - https://www.desmos.com/calculator/b66xr8madc
	float altitudeKm = r * 1e-3 - (planetRadius * 1e-3);
	float o1 = 12.5 * exp(rcp(  8.0) * ( 0.0 - altitudeKm));
	float o2 = 30.0 * exp(rcp( 80.0) * (18.0 - altitudeKm) * (altitudeKm - 18.0));
	float o3 = 75.0 * exp(rcp( 50.0) * (23.5 - altitudeKm) * (altitudeKm - 23.5));
	float o4 = 50.0 * exp(rcp(150.0) * (30.0 - altitudeKm) * (altitudeKm - 30.0));
	float ozone = 7.428e-3 * (o1 + o2 + o3 + o4);

	return vec3(rayleighMie, ozone);
}

#if defined ATMOSPHERE_SCATTERING_LUT
vec3 atmosphereScatteringUv(float nu, float mu, float muS) {
	// Improved mapping for nu from Spectrum by Zombye

	float halfRangeNu = sqrt((1.0 - mu * mu) * (1.0 - muS * muS));
	float nuMin = mu * muS - halfRangeNu;
	float nuMax = mu * muS + halfRangeNu;

	float uNu = (nuMin == nuMax) ? nuMin : (nu - nuMin) / (nuMax - nuMin);
	      uNu = getUvFromUnitRange(uNu, scatteringRes.x);

	// Mapping for mu

	const float r = planetRadius; // distance to the planet centre
	const float H = sqrt(atmosphereOuterRadiusSq - atmosphereInnerRadiusSq); // distance to the atmosphere upper limit for a horizontal ray at ground level
	const float rho = sqrt(max0(planetRadius * planetRadius - atmosphereInnerRadiusSq)); // distance to the horizon

	// Discriminant of the quadratic equation for the intersections of the ray (r, mu) with the
	// ground
	float rmu = r * mu;
	float discriminant = rmu * rmu - r * r + atmosphereInnerRadiusSq;

	float uMu;
	if (mu < 0.0 && discriminant >= 0.0) { // Ray (r, mu) intersects ground
		// Distance to the ground for the ray (r, mu) and its minimum and maximum values over all mu
		float d = -rmu - sqrt(max0(discriminant));
		float dMin = r - atmosphereInnerRadius;
		float dMax = rho;

		uMu = dMax == dMin ? 0.0 : (d - dMin) / (dMax - dMin);
		uMu = getUvFromUnitRange(uMu, scatteringRes.y / 2);
		uMu = 0.5 - 0.5 * uMu;
	} else {
		// Distance to exit the atmosphere outer limit for the ray (r, mu) and its minimum and
		// maximum values over all mu
		float d = -rmu + sqrt(discriminant + H * H);
		float dMin = atmosphereOuterRadius - r;
		float dMax = rho + H;

		uMu = (d - dMin) / (dMax - dMin);
		uMu = getUvFromUnitRange(uMu, scatteringRes.y / 2);
		uMu = 0.5 + 0.5 * uMu;
	}

	// Mapping for muS

	// Distance to the atmosphere outer limit for the ray (atmosphereInnerRadius, muS)
	float d = intersectSphere(muS, atmosphereInnerRadius, atmosphereOuterRadius).y;
	float dMin = atmosphereThickness;
	float dMax = H;
	float a = (d - dMin) / (dMax - dMin);

	// Distance to the atmosphere upper limit for the ray (atmosphereInnerRadius, minMuS)
	float D = intersectSphere(minMuS, atmosphereInnerRadius, atmosphereOuterRadius).y;
	float A = (D - dMin) / (dMax - dMin);

	// An ad-hoc function equal to 0 for muS = minMuS (because then d = D and thus a = A, equal
	// to 1 for muS = 1 (because then d = dMin and thus a = 0), and with a large slope around
	// muS = 0, to get more texture samples near the horizon
	float uMuS = getUvFromUnitRange(max0(1.0 - a / A) / (1.0 + a), scatteringRes.z);

	return vec3(uNu, uMu, uMuS);
}

vec3 atmosphereScattering(float nu, float mu, float muS) {
#ifndef SKY_GROUND
	float horizonMu = mix(-0.01, 0.03, smoothstep(-0.05, 0.2, muS));
	mu = max(mu, horizonMu);
#endif

	vec3 uv = atmosphereScatteringUv(nu, mu, muS);

	vec3 scattering;

	// Rayleigh + multiple scattering
	uv.x *= 0.5;
	scattering  = texture(ATMOSPHERE_SCATTERING_LUT, uv).rgb;

	// Single mie scattering
	uv.x += 0.5;
	scattering += texture(ATMOSPHERE_SCATTERING_LUT, uv).rgb * kleinNishinaPhase(nu, airMieEnergyParameter);

	return scattering;
}

vec3 atmosphereScattering(vec3 rayDir, vec3 lightDir) {
	float nu = dot(rayDir, lightDir);
	float mu = rayDir.y;
	float muS = lightDir.y;

	return atmosphereScattering(nu, mu, muS);
}
#endif

#if defined ATMOSPHERE_TRANSMITTANCE_LUT || defined ATMOSPHERE_SUN_COLOR_LUT
vec2 atmosphereTransmittanceUv(float mu, float r) {
	// Distance to the atmosphere outer limit for a horizontal ray at ground level
	const float H = sqrt(max(atmosphereOuterRadiusSq - atmosphereInnerRadiusSq, 0));

	// Distance to the horizon
	float rho = sqrt(max0(r * r - atmosphereInnerRadiusSq));

	// Distance to the atmosphere upper limit and its minimum and maximum values over all mu
	float d = intersectSphere(mu, r, atmosphereOuterRadius).y;
	float dMin = atmosphereOuterRadius - r;
	float dMax = rho + H;

	float uMu = getUvFromUnitRange((d - dMin) / (dMax - dMin), transmittanceRes.x);
	float uR  = getUvFromUnitRange(rho / H, transmittanceRes.y);

	return vec2(uMu, uR);
}
#endif

#if defined ATMOSPHERE_TRANSMITTANCE_LUT
vec3 atmosphereTransmittance(float mu, float r) {
	if (intersectSphere(mu, r, planetRadius).x >= 0.0) return vec3(0.0);

	vec2 uv = atmosphereTransmittanceUv(mu, r);
	return texture(ATMOSPHERE_TRANSMITTANCE_LUT, uv).rgb;
}
#else
// Source: http://www.thetenthplanet.de/archives/4519
float chapmanFunctionApprox(float x, float cosTheta) {
	float c = sqrt(halfPi * x);

	if (cosTheta >= 0.0) { // => theta <= 90 deg
		return c / ((c - 1.0) * cosTheta + 1.0);
	} else {
		float sinTheta = sqrt(clamp01(1.0 - sqr(cosTheta)));
		return c / ((c - 1.0) * cosTheta - 1.0) + 2.0 * c * exp(x - x * sinTheta) * sqrt(sinTheta);
	}
}

vec3 atmosphereTransmittance(float mu, float r) {
	if (intersectSphere(mu, r, planetRadius).x >= 0.0) return vec3(0.0);

	// Rayleigh and mie density at r
	const vec2 rcpScaleHeights = rcp(airScaleHeights);
	const vec2 scaledPlanetRadius = planetRadius * rcpScaleHeights;
	vec2 density = exp(r * -rcpScaleHeights + scaledPlanetRadius);

	// Estimate airmass along ray using chapman function approximation
	vec2 airmass = airScaleHeights * density;
	airmass.x *= chapmanFunctionApprox(r * rcpScaleHeights.x, mu);
	airmass.y *= chapmanFunctionApprox(r * rcpScaleHeights.y, mu);

	// Approximate ozone density as rayleigh density
	return clamp01(exp(-airExtinctionCoefficients * airmass.xyx));
}
#endif

vec3 atmosphereTransmittance(vec3 rayOrigin, vec3 rayDir) {
	float rSq = dot(rayOrigin, rayOrigin);
	float rcpR = inversesqrt(rSq);
	float mu = dot(rayOrigin, rayDir) * rcpR;
	float r = rSq * rcpR;

	return atmosphereTransmittance(mu, r);
}

#if defined ATMOSPHERE_SUN_COLOR_LUT
vec3 atmosphereSunColor(float mu, float r) {
	if (intersectSphere(mu, r, planetRadius).x >= 0.0) return vec3(0.0);

	vec2 uv = atmosphereTransmittanceUv(mu, r);
	return texture(ATMOSPHERE_SUN_COLOR_LUT, uv).rgb;
}
#else
vec3 atmosphereSunColor(float mu, float r) {
	return baseSunCol * atmosphereTransmittance(mu, r);
}
#endif

#endif // ATMOSPHERE_INCLUDED
