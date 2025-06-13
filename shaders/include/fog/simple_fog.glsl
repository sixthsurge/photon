#if !defined INCLUDE_FOG_SIMPLE_FOG
#define INCLUDE_FOG_SIMPLE_FOG

#include "/include/lighting/colors/blocklight_color.glsl"
#include "/include/sky/projection.glsl"
#include "/include/utility/bicubic.glsl"
#include "/include/utility/color.glsl"
#include "/include/utility/fast_math.glsl"
#include "/include/utility/phase_functions.glsl"

const float lava_fog_start   = 0.33;
const float lava_fog_density = 1.0;
const vec3  lava_fog_color   = from_srgb(vec3(0.839, 0.373, 0.075)) * 2.0;

const float snow_fog_start   = 0.5;
const float snow_fog_density = 1.0;
const vec3  snow_fog_color   = from_srgb(vec3(0.957, 0.988, 0.988)) * 0.3;

const float cave_fog_start   = 1.0;
const float cave_fog_density = 0.0033;
const vec3  cave_fog_color   = vec3(0.033);

const float nether_fog_start   = 0.0;
const float nether_fog_density = 0.01 * NETHER_FOG_INTENSITY;

const float blindness_fog_start   = 2.0;
const float blindness_fog_density = 1.0;

const float darkness_fog_start   = 8.0;
const float darkness_fog_density = 2.0;

const float nether_bloomy_fog_density = 0.25 * nether_fog_density;

#ifdef DISTANT_HORIZONS
uniform int dhRenderDistance;
#endif

float spherical_fog(float view_dist, float fog_start_distance, float fog_density) {
	return exp2(-fog_density * max0(view_dist - fog_start_distance));
}

float border_fog(vec3 scene_pos, vec3 world_dir) {
#ifndef DISTANT_HORIZONS
	float fog = cubic_length(scene_pos.xz) / far;
	      fog = exp2(-8.0 * pow8(fog));
#else
    float fog = length(scene_pos.xz) / float(dhRenderDistance);
          fog = exp2(-2.4 * sqr(fog));
#endif

#if defined WORLD_OVERWORLD || defined WORLD_END
	      fog = mix(fog, 1.0, 0.75 * dampen(linear_step(0.0, 0.2, world_dir.y)));
#endif

	return fog;
}

vec4 common_fog(float view_dist, const bool sky) {
	vec4 fog = vec4(vec3(0.0), 1.0);

	// Lava fog
	float lava_fog = spherical_fog(view_dist, lava_fog_start, lava_fog_density * float(isEyeInWater == 2));
	fog.rgb += lava_fog_color - lava_fog_color * lava_fog;
	fog.a   *= lava_fog;

	// Powdered snow fog
	float snow_fog = spherical_fog(view_dist, snow_fog_start, snow_fog_density * float(isEyeInWater == 3));
	fog.rgb += snow_fog_color - snow_fog_color * snow_fog;
	fog.a   *= snow_fog;

	// Blindness fog
	fog *= mix(
		1.0,
		spherical_fog(view_dist, blindness_fog_start, blindness * blindness_fog_density),
		blindness 
	);

	// Darkness fog
	fog *= mix(
		1.0,
		spherical_fog(view_dist, darkness_fog_start, darknessFactor * darkness_fog_density),
		darknessFactor
	);

#if defined WORLD_OVERWORLD && defined CAVE_FOG
	// Cave fog
	float cave_fog = spherical_fog(view_dist, cave_fog_start, cave_fog_density * biome_cave * float(!sky));
	fog.rgb += cave_fog_color - cave_fog_color * cave_fog;
	fog.a   *= cave_fog;
#endif

#if defined WORLD_NETHER
	// Nether fog
	float nether_fog = spherical_fog(view_dist, nether_fog_start, nether_fog_density);
	fog.rgb += ambient_color - ambient_color * nether_fog;
	fog.a   *= nether_fog;
#endif

	return fog;
}

// Calculates the alpha component only
float common_fog_alpha(float view_dist, bool sky) {
	float fog = 1.0;

	// Lava fog
	fog *= spherical_fog(view_dist, lava_fog_start, lava_fog_density * float(isEyeInWater == 2));

	// Powdered snow fog
	fog *= spherical_fog(view_dist, snow_fog_start, snow_fog_density * float(isEyeInWater == 3));

	// Blindness fog
	fog *= spherical_fog(view_dist, blindness_fog_start, blindness * blindness_fog_density);

#if defined WORLD_OVERWORLD && defined CAVE_FOG
	// Cave fog
	fog *= spherical_fog(view_dist, cave_fog_start, cave_fog_density * biome_cave * float(!sky)); // Cave fog
#endif

#if defined WORLD_NETHER
	// Nether fog
	fog *= spherical_fog(view_dist, nether_fog_start, nether_fog_density);
#endif

	return fog;
}

// Water fog

const vec3 water_absorption_coeff = vec3(WATER_ABSORPTION_R, WATER_ABSORPTION_G, WATER_ABSORPTION_B) * rec709_to_working_color;

vec3 biome_water_coeff(vec3 biome_water_color) {
	const float density_scale = 0.15;
	const float biome_color_contribution = 0.33;

	const vec3 base_absorption_coeff = vec3(WATER_ABSORPTION_R, WATER_ABSORPTION_G, WATER_ABSORPTION_B) * rec709_to_working_color;
	const vec3 forest_absorption_coeff = -density_scale * log(vec3(0.1245, 0.1797, 0.7108));

#ifdef BIOME_WATER_COLOR
	vec3 biome_absorption_coeff = -density_scale * log(biome_water_color + eps) - forest_absorption_coeff;

	return max0(base_absorption_coeff + biome_absorption_coeff * biome_color_contribution);
#else
	return base_absorption_coeff;
#endif
}

// Simple water fog applied behind water or when volumetric fog is disabled
mat2x3 water_fog_simple(
	vec3 light_color,
	vec3 ambient_color,
	vec3 absorption_coeff,
	vec2 light_levels,
	float dist,
	float LoV,
	float sss_depth
) {
	float skylight_factor = cube(light_levels.y);

	vec3 scattering_coeff = vec3(WATER_SCATTERING);
	vec3 extinction_coeff = scattering_coeff + absorption_coeff;

	// Multiple scattering approximation from Jessie
	vec3 scattering_albedo = scattering_coeff / extinction_coeff;
	vec3 multiple_scattering_factor = 0.84 * scattering_albedo;
	vec3 multiple_scattering_energy = multiple_scattering_factor / (1.0 - multiple_scattering_factor);

	// Minimum distance so that water is always easily visible
	dist = max(dist, 2.0 - 1.0 * skylight_factor);

	vec3 light_ambient  = ambient_color * light_levels.y; 
	     light_ambient += 1.41 * blocklight_color * blocklight_scale * sqr(light_levels.x);

	vec3 transmittance = exp(-extinction_coeff * dist);

	vec3 scattering  = light_color * exp(-extinction_coeff * sss_depth) * smoothstep(0.0, 0.25, light_levels.y); // direct lighting
		 scattering *= 0.7 * henyey_greenstein_phase(LoV, 0.4) + 0.3 * isotropic_phase;                          // phase function for direct lighting
	     scattering += light_ambient * isotropic_phase;                                               // ambient lighting
	     scattering *= (1.0 - transmittance) * scattering_coeff / extinction_coeff;                  // scattering integral
		 scattering *= 1.0 + multiple_scattering_energy;                                                         // multiple scattering

	return mat2x3(scattering, transmittance);
}

#endif // INCLUDE_FOG_SIMPLE_FOG
