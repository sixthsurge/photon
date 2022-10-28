#if !defined MATERIAL_INCLUDED
#define MATERIAL_INCLUDED

struct Material {
	vec3 albedo;
	vec3 emission;
	vec3 f0;
	vec3 f82; // hardcoded metals only
	float roughness;
	float refractiveIndex;
	float sssAmount;
	float porosity;
	bool isMetal;
	bool isHardcodedMetal;
};

#if TEXTURE_FORMAT == TEXTURE_FORMAT_LAB
void decodeSpecularTexture() {
	// f0 and f82 values for hardcoded metals from Jessie LC (https://github.com/Jessie-LC)
	const vec3[] metalF0 = vec3[](
		vec3(0.78, 0.77, 0.74), // Iron
		vec3(1.00, 0.90, 0.61), // Gold
		vec3(1.00, 0.98, 1.00), // Aluminum
		vec3(0.77, 0.80, 0.79), // Chrome
		vec3(1.00, 0.89, 0.73), // Copper
		vec3(0.79, 0.87, 0.85), // Lead
		vec3(0.92, 0.90, 0.83), // Platinum
		vec3(1.00, 1.00, 0.91)  // Silver
	);
	const vec3[] metalF82 = vec3[](
		vec3(0.74, 0.76, 0.76),
		vec3(1.00, 0.93, 0.73),
		vec3(0.96, 0.97, 0.98),
		vec3(0.74, 0.79, 0.78),
		vec3(1.00, 0.90, 0.80),
		vec3(0.83, 0.80, 0.83),
		vec3(0.89, 0.87, 0.81),
		vec3(1.00, 1.00, 0.95)
	);
}
#endif

Material getMaterial(vec3 albedoSrgb, uint blockId, inout vec2 lmCoord) {
	vec3 hsl = rgbToHsl(albedoSrgb);

	// Create material with default values

	Material material;
	material.albedo           = srgbToLinear(albedoSrgb) * rec709_to_rec2020;
	material.emission         = vec3(0.0);
	material.f0               = vec3(0.04);
	material.f82              = vec3(0.0);
	material.roughness        = 1.0;
	material.refractiveIndex  = (1.0 + sqrt(0.04)) / (1.0 - sqrt(0.04));
	material.sssAmount        = 0.0;
	material.porosity         = 0.0;
	material.isMetal          = false;
	material.isHardcodedMetal = false;

	// Hardcoded materials for specific blocks
	// Using binary split search to minimise branches per fragment (TODO: measure impact)

	if (blockId < 16u) { // 0-16
		if (blockId < 8u) { // 0-8
			if (blockId < 4u) { // 0-4
				if (blockId < 2u) { // 0-2
					if (blockId == 1u) {

					}
				} else { // 2-4
					if (blockId == 2u) {

					} else {
						material.sssAmount = 0.5;
					}
				}
			} else { // 4-8
				if (blockId < 6u) { // 4-6
					if (blockId == 4u) {
						material.sssAmount = 1.0;
					} else {

					}
				} else { // 6-8
					if (blockId == 6u) {

					} else {

					}
				}
			}
		} else { // 8-16
			if (blockId < 12u) { // 8-12
				if (blockId < 10u) { // 8-10
					if (blockId == 8u) {

					} else {

					}
				} else { // 10-12
					if (blockId == 10u) {

					} else {

					}
				}
			} else { // 12-16
				if (blockId < 14u) { // 12-14
					if (blockId == 12u) {

					} else {

					}
				} else { // 14-16
					if (blockId == 14u) {

					} else {

					}
				}
			}
		}
	} else { // 16-32
		if (blockId < 24u) { // 16-24
			if (blockId < 20u) { // 16-20
				if (blockId < 18u) { // 16-18
					if (blockId == 16u) {

					} else {

					}
				} else { // 18-20
					if (blockId == 18u) {

					} else {

					}
				}
			} else { // 20-24
				if (blockId < 24u) { // 20-22
					if (blockId == 20u) {

					} else {

					}
				} else { // 22-24
					if (blockId == 22u) {

					} else {

					}
				}
			}
		} else { // 24-32
			if (blockId < 28u) { // 24-28
				if (blockId < 26u) { // 24-26
					if (blockId == 24u) {

					} else {

					}
				} else { // 26-28
					if (blockId == 26u) {

					} else {

					}
				}
			} else { // 28-32
				if (blockId < 30) { // 28-30
					if (blockId == 28u) {

					} else {

					}
				} else { // 30-32
					if (blockId == 30u) {

					} else {

					}
				}
			}
		}
	}

	return material;
}

#endif // MATERIAL_INCLUDED
