#if !defined INCLUDE_ATMOSPHERE_ATMOSPHERE
#define INCLUDE_ATMOSPHERE_ATMOSPHERE

#include "/include/atmospherics/phaseFunctions.glsl"

#include "/include/fragment/aces/matrices.glsl"

#include "/include/utility/color.glsl"
#include "/include/utility/fastMath.glsl"
#include "/include/utility/geometry.glsl"

// These have to be macros so that they can be used by constant expressions
#define coneAngleToSolidAngle(theta) (tau * (1.0 - cos(theta)))
#define solidAngleToConeAngle(theta) acos(1.0 - (theta) / tau)

//--// Constants //-----------------------------------------------------------//

const vec3 airViewerPos = vec3(0.0, 6371e3, 0.0); // Position of the viewer in planet-space

const ivec3 transmittanceRes = ivec3(/* mu */ 256, /* r */ 64, /* turbidity */ 8);
const ivec4 scatteringRes    = ivec4(/* nu */ 16, /* mu */ 64, /* muS */ 32, /* turbidity */ 8);

const float minMuS = -0.35;

const float minTurbidity = 0.1;
const float maxTurbidity = 8.0;

//--// Atmosphere boundaries

const float planetRadius = 6371e3; // m

const float atmosphereLowerLimitAltitude = -1e3; // m
const float atmosphereUpperLimitAltitude = 110e3; // m
const float atmosphereLowerLimitRadius = planetRadius + atmosphereLowerLimitAltitude;
const float atmosphereUpperLimitRadius = planetRadius + atmosphereUpperLimitAltitude;

const float atmosphereThickness = atmosphereUpperLimitRadius - atmosphereLowerLimitRadius;
const float atmosphereLowerLimitRadiusSq = atmosphereLowerLimitRadius * atmosphereLowerLimitRadius;
const float atmosphereUpperLimitRadiusSq = atmosphereUpperLimitRadius * atmosphereUpperLimitRadius;

//--// Atmosphere coefficients

const float airMieAlbedo = 0.9;
const float airMieEnergyParameter = 3000.0; // Energy parameter for Klein-Nishina phase function

const vec2 airScaleHeights = vec2(8.4e3, 1.25e3); // m

//*
// Coefficients for rec.709 primaries transformed to AP1
const vec3 airRayleighCoefficient = vec3(8.059375432e-06, 1.671209429e-05, 4.080133294e-05) * r709ToAp1Unlit;
const vec3 airMieCoefficient      = vec3(1.666442358e-06, 1.812685127e-06, 1.958927896e-06) * r709ToAp1Unlit;
const vec3 airOzoneCoefficient    = vec3(8.304280072e-07, 1.314911970e-06, 5.440679729e-08) * r709ToAp1Unlit;
/*/
// Coefficients for AP1 primaries
const vec3 airRayleighCoefficient = vec3(8.059375432e-06, 1.671209429e-05, 4.080133294e-05);
const vec3 airMieCoefficient      = vec3(1.666442358e-06, 1.812685127e-06, 1.958927896e-06);
const vec3 airOzoneCoefficient    = vec3(8.304280072e-07, 1.31491197e-06,  5.440679729e-08);
//*/

const mat2x3 airScatteringCoefficients = mat2x3(airRayleighCoefficient, airMieAlbedo * airMieCoefficient);
const mat3x3 airExtinctionCoefficients = mat3x3(airRayleighCoefficient, airMieCoefficient, airOzoneCoefficient);

//--// Sun and moon

const float sunAngularRadius  = SUN_ANGULAR_RADIUS * tau / 360.0;
const float moonAngularRadius = MOON_ANGULAR_RADIUS * tau / 360.0;

const vec3 sunColor = vec3(1.026186824, 0.9881671071, 1.015787125); // Color of sunlight in space, obtained from AM0 solar irradiance spectrum from https://www.nrel.gov/grid/solar-resource/spectra-astm-e490.html using the CIE (2006) 2-deg LMS cone fundamentals
const vec3 sunTint  = vec3(SUNLIGHT_TINT_R, SUNLIGHT_TINT_G, SUNLIGHT_TINT_B);
const vec3 moonTint = vec3(MOONLIGHT_TINT_R, MOONLIGHT_TINT_G, MOONLIGHT_TINT_B);

const vec3 sunIrradiance  = 70.0 * SUNLIGHT_INTENSITY * sunColor * sunTint;
const vec3 moonIrradiance = 1.0 * MOONLIGHT_INTENSITY * sunColor * moonTint;

const vec3 sunRadiance  = sunIrradiance / coneAngleToSolidAngle(sunAngularRadius);
const vec3 moonRadiance = moonIrradiance / coneAngleToSolidAngle(moonAngularRadius);

//--// Functions //-----------------------------------------------------------//

/*
 * Mapping functions are from Eric Bruneton's 2020 atmosphere implementation
 * https://ebruneton.github.io/precomputed_atmospheric_scattering/atmosphere/functions.glsl.html
 *
 * nu: cos view-light angle
 * mu: cos view-zenith angle
 * muS: cos light-zenith angle
 * r: distance to planet centre
 */

vec3 getAtmosphereDensity(float r) {
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

float getAtmosphereTurbidityTexCoord(float turbidity) {
	turbidity = linearStep(minTurbidity, maxTurbidity, turbidity);
	turbidity = sqrt(turbidity);
	turbidity = getTexCoordFromUnitRange(turbidity, scatteringRes.w);
	return turbidity;
}

#if defined ATMOSPHERE_SCATTERING_LUT
vec3 getAtmosphereScatteringTexCoord(float nu, float mu, float muS) {
	//--// Improved mapping for nu from Spectrum by Zombye

	float halfRangeNu = sqrt((1.0 - mu * mu) * (1.0 - muS * muS));
	float nuMin = mu * muS - halfRangeNu;
	float nuMax = mu * muS + halfRangeNu;

	float uNu = (nuMin == nuMax) ? nuMin : (nu - nuMin) / (nuMax - nuMin);
	      uNu = getTexCoordFromUnitRange(uNu, scatteringRes.x);

	//--// Mapping for mu

	const float r = planetRadius; // distance to the planet centre
	const float H = sqrt(atmosphereUpperLimitRadiusSq - atmosphereLowerLimitRadiusSq); // distance to the atmosphere upper limit for a horizontal ray at ground level
	const float rho = sqrt(max0(planetRadius * planetRadius - atmosphereLowerLimitRadiusSq)); // distance to the horizon

	// Discriminant of the quadratic equation for the intersections of the ray (r, mu) with the
	// ground
	float rmu = r * mu;
	float discriminant = rmu * rmu - r * r + atmosphereLowerLimitRadiusSq;

	float uMu;
	if (mu < 0.0 && discriminant >= 0.0) { // Ray (r, mu) intersects ground
		// Distance to the ground for the ray (r, mu) and its minimum and maximum values over all mu
		float d = -rmu - sqrt(max0(discriminant));
		float dMin = r - atmosphereLowerLimitRadius;
		float dMax = rho;

		uMu = dMax == dMin ? 0.0 : (d - dMin) / (dMax - dMin);
		uMu = getTexCoordFromUnitRange(uMu, scatteringRes.y / 2);
		uMu = 0.5 - 0.5 * uMu;
	} else {
		// Distance to exit the atmosphere outer limit for the ray (r, mu) and its minimum and
		// maximum values over all mu
		float d = -rmu + sqrt(discriminant + H * H);
		float dMin = atmosphereUpperLimitRadius - r;
		float dMax = rho + H;

		uMu = (d - dMin) / (dMax - dMin);
		uMu = getTexCoordFromUnitRange(uMu, scatteringRes.y / 2);
		uMu = 0.5 + 0.5 * uMu;
	}

	//--// Mapping for muS

	// Distance to the atmosphere outer limit for the ray (atmosphereLowerLimitRadius, muS)
	float d = intersectSphere(muS, atmosphereLowerLimitRadius, atmosphereUpperLimitRadius).y;
	float dMin = atmosphereThickness;
	float dMax = H;
	float a = (d - dMin) / (dMax - dMin);

	// Distance to the atmosphere upper limit for the ray (atmosphereLowerLimitRadius, minMuS)
	float D = intersectSphere(minMuS, atmosphereLowerLimitRadius, atmosphereUpperLimitRadius).y;
	float A = (D - dMin) / (dMax - dMin);

	// An ad-hoc function equal to 0 for muS = minMuS (because then d = D and thus a = A, equal
	// to 1 for muS = 1 (because then d = dMin and thus a = 0), and with a large slope around
	// muS = 0, to get more texture samples near the horizon
	float uMuS = getTexCoordFromUnitRange(max0(1.0 - a / A) / (1.0 + a), scatteringRes.z);

	return vec3(uNu, uMu, uMuS);
}

vec4 texture4D(sampler3D sampler, vec4 coord, const ivec4 res) {
	float i, f = modf(coord.w * res.w - 0.5, i);
	coord.z += i;
	float texel = 1.0 / float(res.w);

	vec4 s0 = texture(sampler, vec3(coord.xy, coord.z * texel));
	vec4 s1 = texture(sampler, vec3(coord.xy, coord.z * texel + texel));

	return mix(s0, s1, f);
}

vec3 getAtmosphereScattering(float nu, float mu, float muS) {
#ifdef HIDE_PLANET_SURFACE
	const float minMu = 0.01;
	mu = max(mu, minMu);
#endif

	vec4 coord;
	coord.xyz = getAtmosphereScatteringTexCoord(nu, mu, muS);
	coord.w   = getAtmosphereTurbidityTexCoord(1.0);

	vec3 scattering;

	// Rayleigh + multiple scattering
	coord.x *= 0.5;
	scattering  = texture4D(ATMOSPHERE_SCATTERING_LUT, coord, scatteringRes).rgb;

	// Single mie scattering
	coord.x += 0.5;
	scattering += texture4D(ATMOSPHERE_SCATTERING_LUT, coord, scatteringRes).rgb * kleinNishinaPhase(nu, airMieEnergyParameter);

	return scattering;
}

vec3 getAtmosphereScattering(vec3 rayDir, vec3 lightDir) {
	float nu = dot(rayDir, lightDir);
	float mu = rayDir.y;
	float muS = lightDir.y;

	return getAtmosphereScattering(nu, mu, muS);
}
#endif

#if defined ATMOSPHERE_TRANSMITTANCE_LUT
vec2 getAtmosphereTransmittanceTexCoord(float mu, float r) {
	// Distance to the atmosphere outer limit for a horizontal ray at ground level
	const float H = sqrt(atmosphereUpperLimitRadiusSq - atmosphereLowerLimitRadiusSq);

	// Distance to the horizon
	float rho = sqrt(max0(r * r - atmosphereLowerLimitRadiusSq));

	// Distance to the atmosphere upper limit and its minimum and maximum values over all mu
	float d = intersectSphere(mu, r, atmosphereUpperLimitRadius).y;
	float dMin = atmosphereUpperLimitRadius - r;
	float dMax = rho + H;

	float uMu = getTexCoordFromUnitRange((d - dMin) / (dMax - dMin), transmittanceRes.x);
	float uR  = getTexCoordFromUnitRange(rho / H, transmittanceRes.y);

	return vec2(uMu, uR);
}

vec3 getAtmosphereTransmittance(float mu, float r) {
	vec3 coord;
	coord.xy = getAtmosphereTransmittanceTexCoord(mu, r);
	coord.z  = getAtmosphereTurbidityTexCoord(1.0);

	return texture(ATMOSPHERE_TRANSMITTANCE_LUT, coord).rgb;
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

vec3 getAtmosphereTransmittance(float mu, float r) {
	// Transmittance is 0 if ray intersects ground
	float discriminant = r * r * (mu * mu - 1.0) + atmosphereLowerLimitRadiusSq;
	if (mu < 0.0 && discriminant >= 0.0) return vec3(0.0);

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

vec3 getAtmosphereTransmittance(vec3 rayOrigin, vec3 rayDir) {
	float rSq = dot(rayOrigin, rayOrigin);
	float rcpR = inversesqrt(rSq);
	float mu = dot(rayOrigin, rayDir) * rcpR;
	float r = rSq * rcpR;

	return getAtmosphereTransmittance(mu, r);
}

#endif // INCLUDE_ATMOSPHERE_ATMOSPHERE
