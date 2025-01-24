#if !defined INCLUDE_LIGHTING_DIRECTIONAL_LIGHTMAPS
#define INCLUDE_LIGHTING_DIRECTIONAL_LIGHTMAPS

// Based on Ninjamike's implementation in shaderLABS #snippets

vec2 get_directional_lightmaps(vec3 position_scene, vec3 normal) {
	vec2 lightmap_mul = vec2(1.0);

	vec2 lightmap_gradient; vec3 lightmap_dir;
	mat2x3 pos_gradient = mat2x3(dFdx(position_scene), dFdy(position_scene));

	// Blocklight

	lightmap_gradient = vec2(dFdx(light_levels.x), dFdy(light_levels.x));
	lightmap_dir = pos_gradient * lightmap_gradient;

	if (length_squared(lightmap_gradient) > 1e-12) {
		lightmap_mul.x = (clamp01(dot(normalize(lightmap_dir), normal) + 0.8) * DIRECTIONAL_LIGHTMAPS_INTENSITY + (1.0 - DIRECTIONAL_LIGHTMAPS_INTENSITY)) * inversesqrt(sqrt(light_levels.x) + eps);
	}

	// Skylight

	lightmap_gradient = vec2(dFdx(light_levels.y), dFdy(light_levels.y));
	lightmap_dir = pos_gradient * lightmap_gradient;

	if (length_squared(lightmap_gradient) > 1e-12) {
		lightmap_mul.y = (clamp01(dot(normalize(lightmap_dir), normal) + 0.8) * DIRECTIONAL_LIGHTMAPS_INTENSITY + (1.0 - DIRECTIONAL_LIGHTMAPS_INTENSITY)) * inversesqrt(sqrt(light_levels.y) + eps);
	}

	return lightmap_mul;
}

#endif // INCLUDE_LIGHTING_DIRECTIONAL_LIGHTMAPS
