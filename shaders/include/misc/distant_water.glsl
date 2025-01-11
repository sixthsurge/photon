#if !defined INCLUDE_MISC_DISTANT_WATER
#define INCLUDE_MISC_DISTANT_WATER

#include "/include/lighting/specular_lighting.glsl"
#include "/include/misc/water_normal.glsl"

void draw_distant_water(
	inout vec3 color,
	vec3 position_screen,
	vec3 position_view,
	vec3 position_world,
	vec3 direction_world,
	vec3 flat_normal,
	vec3 tint,
	vec2 light_levels,
	float view_distance,
	float layer_distance
) {
	// Common fog 

	float fog_visibility = common_fog(view_distance, false).a;

	// Water shadow

	//color.rgb *= exp(-5.0 * water_absorption_coeff * fog_visibility);

	// Water absorption approx (must match gbuffers_water)

	vec3 biome_water_color = srgb_eotf_inv(1.45 * tint.rgb) * rec709_to_working_color;
	vec3 absorption_coeff = biome_water_coeff(biome_water_color);

	mat2x3 water_fog = water_fog_simple(
		light_color,
		ambient_color,
		absorption_coeff,
		light_levels,
		layer_distance,
		dot(light_dir, direction_world),
		0.0
	);

	float brightness_control = 1.0 - exp(-0.33 * layer_distance);
		  brightness_control = (1.0 - light_levels.y) + brightness_control * light_levels.y;

	color *= water_fog[1].x;
	color += water_fog[0] * (1.0 + 6.0 * sqr(water_fog[1])) * brightness_control * fog_visibility;

	// Get water wave normal 

	// Account for 1/8 height difference between water and terrain
	vec3 water_surface_pos = position_world - vec3(0.0, rcp(8.0), 0.0);

	mat3 tbn = get_tbn_matrix(flat_normal);
	vec2 coord = -(water_surface_pos * tbn).xy;
	vec3 normal = tbn * get_water_normal(
		water_surface_pos,
		flat_normal, 
		coord, 
		vec2(0.0), 
		light_levels.y, 
		false
	);
	
	// Specular highlight

#if (defined WORLD_OVERWORLD || defined WORLD_END) 
	float NoL = dot(normal, light_dir);
	float NoV = clamp01(dot(normal, -direction_world));
	float LoV = dot(light_dir, -direction_world);
	float halfway_norm = inversesqrt(2.0 * LoV + 2.0);
	float NoH = (NoL + NoV) * halfway_norm;
	float LoH = LoV * halfway_norm + halfway_norm;

	color.rgb += get_specular_highlight(water_material, NoL, NoV, NoH, LoV, LoH) * light_color * fog_visibility;
#endif

	// Specular reflections

#if defined ENVIRONMENT_REFLECTIONS || defined SKY_REFLECTIONS
	mat3 new_tbn = get_tbn_matrix(normal);
	color.rgb += get_specular_reflections(
		water_material,
		new_tbn,
		position_screen,
		position_view,
		normal,
		flat_normal,
		direction_world,
		direction_world * new_tbn,
		light_levels.y,
		true
	) * fog_visibility;
#endif
}

#endif // INCLUDE_MISC_DISTANT_WATER
