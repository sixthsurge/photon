#if !defined INCLUDE_ATMOSPHERE_SKY
#define INCLUDE_ATMOSPHERE_SKY

#include "/include/atmospherics/atmosphere.glsl"

#include "/include/lighting/bsdf.glsl"

#include "/include/utility/fastMath.glsl"
#include "/include/utility/geometry.glsl"
#include "/include/utility/random.glsl"

vec3 drawSun(vec3 rayDir) {
	float nu = dot(rayDir, sunDir);

	// Limb darkening model from http://www.physics.hmc.edu/faculty/esin/a101/limbdarkening.pdf
	const vec3 alpha = vec3(0.429, 0.522, 0.614); // for AP1 primaries
	float centerToEdge = max0(sunAngularRadius - acosApprox(nu));
	vec3 limbDarkening = pow(vec3(1.0 - sqr(1.0 - centerToEdge)), 0.5 * alpha);

	return 0.08 * step(0.0, centerToEdge) * sunRadiance * limbDarkening; // magically darkening the sun to prevent it from overloading bloom
}

vec3 drawMoon(vec3 rayDir) {
	const float moonAlbedo    = 0.3;
	const float moonF0        = 0.04;
	const float moonN         = (1.0 + sqrt(moonF0)) / (1.0 - sqrt(moonF0));
	const float moonRoughness = 0.8;

	const Material moonMaterial = Material(
		vec3(moonAlbedo), // albedo
		vec3(moonF0),     // f0
		vec3(0.0),        // emission
		moonRoughness,    // roughness
		moonN,            // n
		0.0,              // sssAmount
		0.0,              // porosity
		false,            // isMetal
		false             // isHardcodedMetal
	);

	float distanceToMoon = intersectSphere(-moonDir, rayDir, moonAngularRadius).x;

	if (distanceToMoon < 0.0) return vec3(0.0);

	// Get moon normal
	vec3 normal = normalize(rayDir * distanceToMoon - moonDir);

	// Get light direction which orbits around moon
	float lightAngle = 0.125 * tau * float(moonPhase);

	vec3 leftDir = normalize(cross(vec3(0.0, 1.0, 0.0), rayDir));
	vec3 lightDir = cos(lightAngle) * -rayDir + sin(lightAngle) * leftDir;

	float NoL = dot(normal, lightDir);
	float NoV = dot(normal, -rayDir);
	float LoV = dot(lightDir, -rayDir);
	float halfwayNorm = inversesqrt(2.0 * LoV + 2.0);
	float NoH = (NoL + NoV) * halfwayNorm;

	vec3 irradiance = sunIrradiance * max0(NoL);

	vec3 bsdf = diffuseHammon(moonMaterial, NoL, NoV, NoH, LoV);

	float glow = 0.04 * pow4(max0(-NoL)); // Subtle glow on dark side of the moon

	return (irradiance * bsdf + glow) * vec3(MOONLIGHT_TINT_R, MOONLIGHT_TINT_G, MOONLIGHT_TINT_B);
}

//----------------------------------------------------------------------------//
// based on https://www.shadertoy.com/view/Md2SR3

vec3 unstableStarField(vec2 coord) {
	const float threshold = 1.0 - 0.006 * STARS_COVERAGE;
	const float minTemp = STARS_TEMPERATURE - STARS_TEMPERATURE_VARIATION;
	const float maxTemp = STARS_TEMPERATURE + STARS_TEMPERATURE_VARIATION;

	vec2 noise = hash2(coord);

	float star = linearStep(threshold, 1.0, noise.x);
	      star = cube(star) * STARS_INTENSITY;

	float temp = mix(minTemp, maxTemp, noise.y);
	vec3 color = blackbody(temp);

	return star * color;
}

// Stabilizes the star field by only sampling at the four neighboring integer coordinates and
// interpolating
vec3 stableStarField(vec2 coord) {
	coord = abs(coord) + 33.3 * step(0.0, coord);
	vec2 i, f = modf(coord, i);

	f.x = cubicSmooth(f.x);
	f.y = cubicSmooth(f.y);

	return unstableStarField(i + vec2(0.0, 0.0)) * (1.0 - f.x) * (1.0 - f.y)
	     + unstableStarField(i + vec2(1.0, 0.0)) * f.x * (1.0 - f.y)
	     + unstableStarField(i + vec2(0.0, 1.0)) * f.y * (1.0 - f.x)
	     + unstableStarField(i + vec2(1.0, 1.0)) * f.x * f.y;
}

vec3 drawStars(vec3 rayDir) {
#if defined WORLD_OVERWORLD && defined SHADOW
	// Trick to make stars rotate alongside the sun and moon
	rayDir = mat3(shadowModelView) * rayDir * (sunAngle < 0.5 ? 1.0 : -1.0);
#endif

	// Project ray direction onto the plane
	vec2 coord  = rayDir.xy * rcp(abs(rayDir.z) + length(rayDir.xy)) + 41.21 * sign(rayDir.z);
	     coord *= 600.0 - 400.0 * STARS_SCALE;

	return stableStarField(coord) * (1.0 - timeNoon);
}

//----------------------------------------------------------------------------//

vec3 cloudsAerialPerspective(vec3 cloudsScattering, vec3 cloudData, vec3 rayDir, vec3 clearSky, float apparentDistance) {
	vec3 rayOrigin = vec3(0.0, planetRadius + CLOUDS_SCALE * (eyeAltitude - SEA_LEVEL), 0.0);
	vec3 rayEnd    = rayOrigin + apparentDistance * rayDir;

	vec3 transmittance;
	if (rayOrigin.y < length(rayEnd)) {
		vec3 trans0 = getAtmosphereTransmittance(rayOrigin, rayDir);
		vec3 trans1 = getAtmosphereTransmittance(rayEnd,    rayDir);

		transmittance = clamp01(trans0 / trans1);
	} else {
		vec3 trans0 = getAtmosphereTransmittance(rayOrigin, -rayDir);
		vec3 trans1 = getAtmosphereTransmittance(rayEnd,    -rayDir);

		transmittance = clamp01(trans1 / trans0);
	}

	return mix((1.0 - cloudData.b) * clearSky, cloudsScattering, transmittance);
}

#endif // INCLUDE_ATMOSPHERE_SKY
