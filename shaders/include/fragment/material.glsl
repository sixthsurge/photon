#if !defined INCLUDE_FRAGMENT_MATERIAL
#define INCLUDE_FRAGMENT_MATERIAL

#include "/include/utility/color.glsl"

struct Material {
	vec3 albedo;
	vec3 f0;
	vec3 emission;
	float roughness;
	float n;
	float sssAmount;
	float porosity;
	bool isMetal;
	bool isHardcodedMetal;
};

const float airN   = 1.000293; // for 0°C and 1 atm
const float waterN = 1.333;    // for 20°C

float f0ToIor(float f0) {
	float sqrtF0 = sqrt(f0) * 0.99999;
	return (1.0 + sqrtF0) / (1.0 - sqrtF0);
}
vec3 f0ToIor(vec3 f0) {
	vec3 sqrtF0 = sqrt(f0) * 0.999999;
	return (1.0 + sqrtF0) / (1.0 - sqrtF0);
}

float getHardcodedEmission(vec3 albedo, uint blockId) {
#if defined PROGRAM_DEFERRED_LIGHTING
	vec3 hsl = rgbToHsl(albedo);

	switch (blockId) {
	case BLOCK_EMISSIVE_DIM:
	case ENTITY_EMISSIVE:
		return 0.33 * (0.1 + 0.9 * hsl.z);

	case BLOCK_EMISSIVE_MEDIUM:
		return 0.66 * (0.1 + 0.9 * hsl.z);

	case BLOCK_EMISSIVE_BRIGHT:
		return 1.00 * (0.1 + 0.9 * hsl.z);

	case BLOCK_EMISSIVE_STREAKED: // dim + lower threshold
		return 0.10 * smoothstep(0.25, 0.4, 0.3 * hsl.y + 0.7 * dampen(hsl.z));

	case BLOCK_TORCH:
		return step(0.5, 0.2 * pulseHue(hsl.x, 30.0, 40.0) + 0.32 * hsl.y + 0.6 * hsl.z);

	case BLOCK_REDSTONE_COMPONENT:
		float redness = albedo.r * rcp(albedo.g + albedo.b);
		return 0.33 * step(0.45, redness * hsl.z);

	case BLOCK_REDSTONE_LAMP:
		return 0.66 * step(0.1, hsl.z);

	case BLOCK_JACK_O_LANTERN:
		return 0.40 * step(0.5, 0.3 * hsl.y + 0.7 * hsl.z);

	case BLOCK_BREWING_STAND:
		return 0.66 * pulseHue(hsl.x, 60.0, 80.0);

	case BLOCK_SOUL_LIGHT:
		return 0.33 * step(0.5, 0.5 * pulseHue(hsl.x, 180.0, 50.0) + 0.5 * hsl.z);

	case ENTITY_LIGHTNING_BOLT:
		return 1.0;

	case ENTITY_DROWNED:
		return 0.3 * step(0.5, hsl.z);

	case ENTITY_STRAY:
		return 0.3 * step(0.85, hsl.z);

	case ENTITY_END_CRYSTAL:
		return step(hsl.z, 0.7);

	default:
		return 0.0;
	}
#else
	return 0.0;
#endif
}

float getHardcodedSss(uint blockId) {
#if defined PROGRAM_DEFERRED_LIGHTING
	switch (blockId) {
	case BLOCK_SMALL_PLANT:
		return 0.5;

	case BLOCK_TALL_PLANT_LOWER:
		return 0.5;

	case BLOCK_TALL_PLANT_UPPER:
		return 0.5;

	case BLOCK_LEAVES:
		return 1.0;

	case BLOCK_WEAK_SSS:
#ifdef ENTITY_SSS
	case ENTITY_WEAK_SSS:
#endif
		return 0.2;

	case BLOCK_MEDIUM_SSS:
#ifdef ENTITY_SSS
	case ENTITY_STRONG_SSS:
#endif
		return 0.6;

	case BLOCK_STRONG_SSS:
		return 1.0;

	default:
		return 0.0;
	}
#else
	return 0.0;
#endif
}

Material getMaterial(vec3 albedo, uint blockId) {
	float defaultF0 = 0.04;
	float defaultN  = (1.0 + sqrt(defaultF0)) / (1.0 - sqrt(defaultF0));

	Material material = Material(
		albedo,          // albedo
		vec3(defaultF0), // f0
		vec3(0.0),       // emission
		0.8,             // roughness
		defaultN,        // n
		0.0,             // sssAmount
		0.0,             // porosity
		false,           // isMetal
		false            // isHardcodedMetal
	);

#ifdef HARDCODED_EMISSION
	material.emission = getHardcodedEmission(albedo, blockId) * albedo;
#endif

#ifdef HARDCODED_SSS
	material.sssAmount = getHardcodedSss(blockId);
#endif

	return material;
}

#endif // INCLUDE_FRAGMENT_MATERIAL#if !defined INCLUDE_FRAGMENT_MATERIAL
