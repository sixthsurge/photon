#if !defined INCLUDE_FOG_SIMPLE_FOG
#define INCLUDE_FOG_SIMPLE_FOG

#include "/include/sky/projection.glsl"
#include "/include/utility/bicubic.glsl"
#include "/include/utility/color.glsl"
#include "/include/utility/fast_math.glsl"
#include "/include/utility/phase_functions.glsl"

const vec3 cave_fog_color = vec3(0.033);
const vec3 lava_fog_color = from_srgb(vec3(0.839, 0.373, 0.075)) * 2.0;
const vec3 snow_fog_color = from_srgb(vec3(0.957, 0.988, 0.988)) * 0.3;

const vec3 water_absorption_coeff = vec3(WATER_ABSORPTION_R, WATER_ABSORPTION_G, WATER_ABSORPTION_B) * rec709_to_working_color;

float spherical_fog(float view_dist, float fog_start_distance, float fog_density) {
	return exp2(-fog_density * max0(view_dist - fog_start_distance));
}

float border_fog(vec3 scene_pos, vec3 world_dir) {
	float fog = cubic_length(scene_pos.xz) / far;
	      fog = exp2(-8.0 * pow8(fog));
#if defined WORLD_OVERWORLD || defined WORLD_END
	      fog = mix(fog, 1.0, 0.75 * dampen(linear_step(0.0, 0.2, world_dir.y)));
#endif

	if (isEyeInWater != 0.0) fog = 1.0;

	return fog;
}

vec3 biome_water_coeff(vec3 biome_water_color) {
	const float density_scale = 0.15;
	const float biome_color_contribution = 0.33;

	const vec3 base_absorption_coeff = vec3(WATER_ABSORPTION_R, WATER_ABSORPTION_G, WATER_ABSORPTION_B) * rec709_to_working_color;
	const vec3 forest_absorption_coeff = -density_scale * log(vec3(0.1245, 0.1797, 0.7108));

#ifdef BIOME_WATER_COLOR
	vec3 biome_absorption_coeff = -density_scale * log(biome_water_color + eps) - forest_absorption_coeff;

	return max0(water_absorption_coeff + biome_absorption_coeff * biome_color_contribution);
#else
	return base_absorption_coeff;
#endif
}

// Simple water fog applied behind water or when volumetric fog is disabled
mat2x3 water_fog_simple(
	vec3 light_color,
	vec3 ambient_color,
	vec3 absorption_coeff,
	float dist,
	float LoV,
	float skylight,
	float sss_depth
) {
	vec3 scattering_coeff = vec3(WATER_SCATTERING);
	vec3 extinction_coeff = scattering_coeff + absorption_coeff;

	// Multiple scattering approximation from Jessie
	vec3 scattering_albedo = scattering_coeff / extinction_coeff;
	vec3 multiple_scattering_factor = 0.84 * scattering_albedo;
	vec3 multiple_scattering_energy = multiple_scattering_factor / (1.0 - multiple_scattering_factor);

	// Minimum distance so that water is always easily visible
	dist = max(dist, 1.0);

	vec3 transmittance = exp(-extinction_coeff * dist);

	vec3 scattering  = light_color * exp(-extinction_coeff * sss_depth) * smoothstep(0.0, 0.25, skylight); // direct lighting
		 scattering *= 0.7 * henyey_greenstein_phase(LoV, 0.4) + 0.3 * isotropic_phase;                          // phase function for direct lighting
	     scattering += ambient_color * skylight * isotropic_phase;                                               // ambient lighting
	     scattering *= (1.0 - transmittance) * scattering_coeff / extinction_coeff;                  // scattering integral
		 scattering *= 1.0 + multiple_scattering_energy;                                                         // multiple scattering

	return mat2x3(scattering, transmittance);
}

//----------------------------------------------------------------------------//
#if defined WORLD_OVERWORLD

#include "/include/sky/atmosphere.glsl"
#include "/include/sky/projection.glsl"

vec4 get_simple_fog(
	vec3 world_dir,
	float view_dist,
	float skylight,
	bool do_normal_fog,
	bool sky
) {
	vec4 fog = vec4(vec3(0.0), 1.0);

	// Normal fog

	if (do_normal_fog && !sky) {
		vec3 horizon_dir = normalize(vec3(world_dir.xz, min(world_dir.y, -0.1)).xzy);
		vec3 horizon_color = texture(colortex4, project_sky(horizon_dir)).rgb;

		float normal_fog = spherical_fog(view_dist, 0.0, 0.001 * cube(skylight));

		fog.rgb += horizon_color - horizon_color * normal_fog;
		fog.a   *= normal_fog;
	}

	// Cave fog

#ifdef CAVE_FOG
	float cave_fog = spherical_fog(view_dist, 0.0, 0.0033 * biome_cave * float(!sky));
	fog.rgb += cave_fog_color - cave_fog_color * cave_fog;
	fog.a   *= cave_fog;
#endif

	// Lava fog

	float lava_fog = spherical_fog(view_dist, 0.33, float(isEyeInWater == 2));
	fog.rgb += lava_fog_color - lava_fog_color * lava_fog;
	fog.a   *= lava_fog;

	// Powdered snow fog

	float snow_fog = spherical_fog(view_dist, 0.5, 1.0 * float(isEyeInWater == 3));
	fog.rgb += snow_fog_color - snow_fog_color * snow_fog;
	fog.a   *= snow_fog;

	// Blindness fog

	float blindness_fog = spherical_fog(view_dist, 2.0, blindness);
	fog.rgb *= blindness_fog;
	fog.a   *= blindness_fog;

	// Darkness fog
	float darkness_fog = spherical_fog(view_dist, 2.0, 0.05 * darknessFactor) * 0.7 + 0.3;
	fog.rgb *= darkness_fog;
	fog.a   *= darkness_fog;

	return fog;
}

//----------------------------------------------------------------------------//
#elif defined WORLD_NETHER

vec4 get_simple_fog(
	vec3 world_dir,
	float view_dist,
	float skylight,
	bool do_normal_fog,
	bool sky
) {
	if (sky) view_dist = far;

	vec4 fog = vec4(vec3(0.0), 1.0);

	// Normal fog

	float nether_fog = spherical_fog(view_dist, 0.0, 0.0083 * NETHER_FOG_INTENSITY);
	fog.rgb += ambient_color - ambient_color * nether_fog;
	fog.a   *= nether_fog;

	// Lava fog

	float lava_fog = spherical_fog(view_dist, 0.33, float(isEyeInWater == 2));
	fog.rgb += lava_fog_color - lava_fog_color * lava_fog;
	fog.a   *= lava_fog;

	// Powdered snow fog

	float snow_fog = spherical_fog(view_dist, 0.5, 1.0 * float(isEyeInWater == 3));
	fog.rgb += snow_fog_color - snow_fog_color * snow_fog;
	fog.a   *= snow_fog;

	// Blindness fog

	float blindness_fog = spherical_fog(view_dist, 2.0, blindness);
	fog.rgb *= blindness_fog;
	fog.a   *= blindness_fog;

	// Darkness fog
	float darkness_fog = spherical_fog(view_dist, 2.0, 0.05 * darknessFactor) * 0.7 + 0.3;
	fog.rgb *= darkness_fog;
	fog.a   *= darkness_fog;

	return fog;
}

//----------------------------------------------------------------------------//
#elif defined WORLD_END

#endif

#endif // INCLUDE_FOG_SIMPLE_FOG
