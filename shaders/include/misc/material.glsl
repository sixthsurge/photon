#if !defined INCLUDE_MISC_MATERIAL
#define INCLUDE_MISC_MATERIAL

#include "/include/aces/matrices.glsl"
#include "/include/utility/color.glsl"

const float air_n   = 1.000293; // for 0°C and 1 atm
const float water_n = 1.333;    // for 20°C

struct Material {
	vec3 albedo;
	vec3 emission;
	vec3 f0;
	vec3 f82; // hardcoded metals only
	float roughness;
	float sss_amount;
	float sheen_amount; // SSS "sheen" for tall grass
	float porosity;
	float ssr_multiplier;
	bool is_metal;
	bool is_hardcoded_metal;
};

const Material water_material = Material(vec3(0.0), vec3(0.0), vec3(0.02), vec3(0.0), 0.002, 1.0, 0.0, 0.0, 1.0, false, false);

Material material_from(vec3 albedo_srgb, uint material_mask, vec3 world_pos, inout vec2 light_levels) {
	vec3 block_pos = fract(world_pos);

	// Create material with default values

	Material material;
	material.albedo             = srgb_eotf_inv(albedo_srgb) * rec709_to_rec2020;
	material.emission           = vec3(0.0);
	material.f0                 = vec3(0.0);
	material.f82                = vec3(0.0);
	material.roughness          = 1.0;
	material.sss_amount         = 0.0;
	material.sheen_amount       = 0.0;
	material.porosity           = 0.0;
	material.ssr_multiplier     = 0.0;
	material.is_metal           = false;
	material.is_hardcoded_metal = false;

	// Hardcoded materials for specific blocks
	// Using binary split search to minimise branches per fragment (TODO: measure impact)

	vec3 hsl = rgb_to_hsl(albedo_srgb);
	vec3 albedo_sqrt = sqrt(material.albedo);

	if (material_mask < 16u) { // 0-16
		if (material_mask < 8u) { // 0-8
			if (material_mask < 4u) { // 0-4
				if (material_mask >= 2u) { // 2-4
					if (material_mask == 2u) {
						#ifdef HARDCODED_EMISSION
						// Bright full emissives
						material.emission = 1.00 * albedo_sqrt * (0.1 + 0.9 * cube(hsl.z));
						light_levels.x *= 0.8;
						#endif
					} else {
						#ifdef HARDCODED_EMISSION
						// Medium full emissives
						material.emission = 0.66 * albedo_sqrt * (0.1 + 0.9 * cube(hsl.z));
						light_levels.x *= 0.8;
						#endif
					}
				}
			} else { // 4-8
				if (material_mask < 6u) { // 4-6
					if (material_mask == 4u) {
						#ifdef HARDCODED_EMISSION
						// Dim full emissives
						material.emission = 0.2 * albedo_sqrt * (0.1 + 0.9 * pow4(hsl.z));
						light_levels.x *= 0.95;
						#endif
					} else {
						#ifdef HARDCODED_EMISSION
						// Partial emissives (brightest parts glow)
						float blue = isolate_hue(hsl, 200.0, 30.0);
						material.emission = 0.8 * albedo_sqrt * step(0.495 - 0.1 * blue, 0.2 * hsl.y + 0.5 * hsl.z);
						light_levels.x *= 0.88;
						#endif
					}
				} else { // 6-8, Torches
					#ifdef HARDCODED_EMISSION
					if (material_mask == 6u) {
						// Ground torches
						material.emission = 0.5 * sqrt(albedo_sqrt) * cube(linear_step(0.12, 0.45, block_pos.y));
					} else {
						// Wall torches
						material.emission = 0.5 * sqrt(albedo_sqrt) * cube(linear_step(0.35, 0.6, block_pos.y));
					}
					material.emission  = max(material.emission, 0.85 * albedo_sqrt * step(0.5, 0.2 * hsl.y + 0.55 * hsl.z));
					material.emission *= light_levels.x;
					light_levels.x *= 0.8;
					#endif
				}
			}
		} else { // 8-16
			if (material_mask < 12u) { // 8-12
				if (material_mask < 10u) { // 8-10
					if (material_mask == 8u) {
						#ifdef HARDCODED_EMISSION
						// Lava
						material.emission = vec3(0.8) * (0.2 + 0.8 * isolate_hue(hsl, 30.0, 15.0));
						light_levels.x *= 0.3;
						#endif
					} else {
						#ifdef HARDCODED_EMISSION
						// Redstone components
						vec3 ap1 = material.albedo * rec2020_to_ap1_unlit;
						float l = 0.5 * (min_of(ap1) + max_of(ap1));
						float redness = ap1.r * rcp(ap1.g + ap1.b);
						material.emission = 0.33 * material.albedo * step(0.45, redness * l);
						#endif
					}
				} else { // 10-12
					if (material_mask == 10u) {
						#ifdef HARDCODED_EMISSION
						// Jack o' Lantern + nether mushrooms
						material.emission = 0.80 * albedo_sqrt * step(0.73, 0.1 * hsl.y + 0.7 * hsl.z);
						light_levels.x *= 0.85;
						#endif
					} else {
						#ifdef HARDCODED_EMISSION
						// Beacon
						material.emission = step(0.2, hsl.z) * albedo_sqrt * step(max_of(abs(block_pos - 0.5)), 0.4);
						light_levels.x *= 0.9;
						#endif
					}
				}
			} else { // 12-16
				if (material_mask < 14u) { // 12-14
					if (material_mask == 12u) {
						#ifdef HARDCODED_EMISSION
						// End portal frame
						material.emission = 0.33 * material.albedo * isolate_hue(hsl, 120.0, 50.0);
						#endif
					} else {
						#ifdef HARDCODED_EMISSION
						// Sculk
						material.emission = 0.2 * material.albedo * isolate_hue(hsl, 200.0, 40.0) * smoothstep(0.5, 0.7, hsl.z) * (1.0 - linear_step(0.0, 20.0, distance(world_pos, cameraPosition)));
						#endif
					}
				} else { // 14-16
					if (material_mask == 14u) {
						#ifdef HARDCODED_EMISSION
						// Pink glow
						material.emission = vec3(0.75) * isolate_hue(hsl, 310.0, 50.0);
						#endif
					} else {
						#ifdef HARDCODED_EMISSION
						// Candles
						material.emission = vec3(0.2) * pow4(clamp01(block_pos.y * 2.0));
						light_levels.x *= 0.9;
						#endif
					}
				}
			}
		}
	} else { // 16-32
		if (material_mask < 24u) { // 16-24
			if (material_mask < 20u) { // 16-20
				if (material_mask < 18u) { // 16-18
					if (material_mask == 16u) {
						#ifdef HARDCODED_SSS
						// Small plants
						material.sss_amount = 0.5;
						material.sheen_amount = 1.0;
						#endif
					} else {
						#ifdef HARDCODED_SSS
						// Tall plants (lower half)
						material.sss_amount = 0.5;
						material.sheen_amount = 1.0;
						#endif
					}
				} else { // 18-20
					if (material_mask == 18u) {
						#ifdef HARDCODED_SSS
						// Tall plants (upper half)
						material.sss_amount = 0.5;
						material.sheen_amount = 1.0;
						#endif
					} else {
						// Leaves
						#ifdef HARDCODED_SPECULAR
						float smoothness = 0.5 * smoothstep(0.16, 0.5, hsl.z);
						material.roughness = sqr(1.0 - smoothness);
						material.f0 = vec3(0.02);
						material.sheen_amount = 0.5;
						#endif

						#ifdef HARDCODED_SSS
						material.sss_amount = 1.0;
						#endif
					}
				}
			} else { // 20-24
				if (material_mask < 22u) { // 20-22
					if (material_mask == 20u) {
						// Stained glass and slime
						#ifdef HARDCODED_SPECULAR
						material.f0 = vec3(0.04);
						material.roughness = 0.1;
						material.ssr_multiplier = 1.0;
						#endif

						#ifdef HARDCODED_SSS
						material.sss_amount = 0.5;
						#endif
					} else {
						#ifdef HARDCODED_SSS
						// Weak SSS
						material.sss_amount = 0.1;
						#endif
					}
				} else { // 22-24
					if (material_mask == 22u) {
						#ifdef HARDCODED_SSS
						// Strong SSS
						material.sss_amount = 0.6;
						#endif
					} else {
						// Snow
						#ifdef HARDCODED_SPECULAR
						float smoothness = pow5(linear_step(0.95, 1.0, hsl.z)) * 0.6;
						material.roughness = sqr(1.0 - smoothness);
						material.f0 = vec3(0.02);
						#endif

						#ifdef HARDCODED_SSS
						material.sss_amount = 0.6;
						#endif
					}
				}
			}
		} else { // 24-32
			if (material_mask < 28u) { // 24-28
				if (material_mask < 26u) { // 24-26
					if (material_mask == 24u) {
						// Grass block, stone
						#ifdef HARDCODED_SPECULAR
						float smoothness = 0.33 * smoothstep(0.2, 0.6, hsl.z);
						material.roughness = sqr(1.0 - smoothness);
						material.f0 = vec3(0.02);
						#endif
					} else {
						// Ice
						#ifdef HARDCODED_SPECULAR
						float smoothness = pow4(linear_step(0.4, 0.8, hsl.z)) * 0.6;
						material.roughness = sqr(1.0 - smoothness);
						material.f0 = vec3(0.02);
						material.ssr_multiplier = 1.0;
						#endif

						#ifdef HARDCODED_SSS
						// Strong SSS
						material.sss_amount = 0.75;
						#endif
					}
				} else { // 26-28
					if (material_mask == 26u) {
						// Sand
						#ifdef HARDCODED_SPECULAR
						float smoothness = 0.8 * linear_step(0.81, 0.96, hsl.z);
						material.roughness = sqr(1.0 - smoothness);
						material.f0 = vec3(0.02);
						#endif
					} else {
						// Red sand
						#ifdef HARDCODED_SPECULAR
						float smoothness = 0.4 * linear_step(0.61, 0.85, hsl.z);
						material.roughness = sqr(1.0 - smoothness);
						material.f0 = vec3(0.02);
						#endif
					}
				}
			} else { // 28-32
				if (material_mask < 30) { // 28-30
					if (material_mask == 28u) {
						// Oak, jungle and acacia planks, granite and diorite
						#ifdef HARDCODED_SPECULAR
						float smoothness = 0.5 * linear_step(0.4, 0.8, hsl.z);
						material.roughness = sqr(1.0 - smoothness);
						material.f0 = vec3(0.02);
						#endif
					} else {
						// Obsidian, nether brick
						#ifdef HARDCODED_SPECULAR
						float smoothness = linear_step(0.02, 0.4, hsl.z);
						material.roughness = sqr(1.0 - smoothness);
						material.f0 = vec3(0.02);
						material.ssr_multiplier = 1.0;
						#endif
					}
				} else { // 30-32
					if (material_mask == 30u) {
						// Metals
						#ifdef HARDCODED_SPECULAR
						float smoothness = sqrt(linear_step(0.1, 0.9, hsl.z));
						material.roughness = max(sqr(1.0 - smoothness), 0.04);
						material.f0 = material.albedo;
						material.is_metal = true;
						material.ssr_multiplier = 1.0;
						#endif
					} else if (material_mask == 31) {
						// Shiny dielectrics
						#ifdef HARDCODED_SPECULAR
						float smoothness = sqrt(linear_step(0.1, 0.9, hsl.z));
						material.roughness = max(sqr(1.0 - smoothness), 0.04);
						material.f0 = vec3(0.25);
						material.ssr_multiplier = 1.0;
						#endif
					}
				}
			}
		}
	}

	material.emission += float(material_mask == 250); // End portal
	material.emission += float(material_mask == 251); // Nether portal

	return material;
}

#if TEXTURE_FORMAT == TEXTURE_FORMAT_LAB
void decode_specular_map(vec4 specular_map, inout Material material) {
	// f0 and f82 values for hardcoded metals from Jessie LC (https://github.com/Jessie-LC)
	const vec3[] metal_f0 = vec3[](
		vec3(0.78, 0.77, 0.74), // Iron
		vec3(1.00, 0.90, 0.61), // Gold
		vec3(1.00, 0.98, 1.00), // Aluminum
		vec3(0.77, 0.80, 0.79), // Chrome
		vec3(1.00, 0.89, 0.73), // Copper
		vec3(0.79, 0.87, 0.85), // Lead
		vec3(0.92, 0.90, 0.83), // Platinum
		vec3(1.00, 1.00, 0.91)  // Silver
	);
	const vec3[] metal_f82 = vec3[](
		vec3(0.74, 0.76, 0.76),
		vec3(1.00, 0.93, 0.73),
		vec3(0.96, 0.97, 0.98),
		vec3(0.74, 0.79, 0.78),
		vec3(1.00, 0.90, 0.80),
		vec3(0.83, 0.80, 0.83),
		vec3(0.89, 0.87, 0.81),
		vec3(1.00, 1.00, 0.95)
	);

	material.roughness = sqr(1.0 - specular_map.r);
	material.emission = max(material.emission, material.albedo * specular_map.a * float(specular_map.a != 1.0));

	if (specular_map.g < 229.5 / 255.0) {
		// Dielectrics
		material.f0 = max(material.f0, specular_map.g);

		float has_sss = step(64.5 / 255.0, specular_map.b);
		material.sss_amount = max(material.sss_amount, linear_step(64.0 / 255.0, 1.0, specular_map.b * has_sss));
		material.porosity = linear_step(0.0, 64.0 / 255.0, max0(specular_map.b - specular_map.b * has_sss));
	} else if (specular_map.g < 237.5 / 255.0) {
		// Hardcoded metals
		uint metal_id = clamp(uint(255.0 * specular_map.g) - 230u, 0u, 7u);

		material.f0 = metal_f0[metal_id];
		material.f82 = metal_f82[metal_id];
		material.is_metal = true;
		material.is_hardcoded_metal = true;
	} else {
		// Albedo metal
		material.f0 = material.albedo;
		material.is_metal = true;
	}

	material.ssr_multiplier = step(0.01, (material.f0.x - material.f0.x * material.roughness * SSR_ROUGHNESS_THRESHOLD)); // based on Kneemund's method
}
#elif TEXTURE_FORMAT == TEXTURE_FORMAT_OLD
void decode_specular_map(vec4 specular_map, inout Material material) {
	material.roughness = sqr(1.0 - specular_map.r);
	material.is_metal  = specular_map.g > 0.5;
	material.f0        = material.is_metal ? material.albedo : material.f0;
	material.emission  = max(material.emission, material.albedo * specular_map.b);

	material.ssr_multiplier = step(0.01, (material.f0.x - material.f0.x * material.roughness * SSR_ROUGHNESS_THRESHOLD)); // based on Kneemund's method
}
#endif

void decode_specular_map(vec4 specular_map, inout Material material, out bool parallax_shadow) {
#if defined POM && defined POM_SHADOW
		// Specular map alpha >= 0.5 => parallax shadow
		parallax_shadow = specular_map.a >= 0.5;
		specular_map.a = fract(specular_map.a * 2.0);
#endif

		decode_specular_map(specular_map, material);
}

#endif // INCLUDE_MISC_MATERIAL
