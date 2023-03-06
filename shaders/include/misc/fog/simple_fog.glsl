#ifndef INCLUDE_MISC_FOG_SIMPLE
#define INCLUDE_MISC_FOG_SIMPLE

#include "/include/utility/bicubic.glsl"
#include "/include/utility/fast_math.glsl"

const vec3 cave_fog_color = vec3(0.033);
const vec3 lava_fog_color = from_srgb(vec3(0.839, 0.373, 0.075)) * 2.0;
const vec3 snow_fog_color = from_srgb(vec3(0.957, 0.988, 0.988)) * 0.8;

const vec3 water_absorption_coeff = vec3(WATER_ABSORPTION_R, WATER_ABSORPTION_G, WATER_ABSORPTION_B) * rec709_to_working_color;
const vec3 water_scattering_coeff = vec3(WATER_SCATTERING);
const vec3 water_extinction_coeff = water_absorption_coeff + water_scattering_coeff;

float spherical_fog(float view_distance, float fog_start_distance, float fogDensity) {
	return exp2(-fogDensity * max0(view_distance - fog_start_distance));
}

float border_fog(vec3 scene_pos, vec3 world_dir) {
#if defined WORLD_OVERWORLD
	float density = 1.0 - 0.2 * smoothstep(0.0, 0.25, world_dir.y);
#else
	float density = 1.0;
#endif

	float fog = length(scene_pos.xz) / far;
	      fog = exp2(-8.0 * pow12(fog * density));

	if (isEyeInWater != 0.0) fog = 1.0;

	return fog;
}

mat2x3 water_fog_simple(
	vec3 light_color,
	vec3 ambient_color,
	float dist,
	float LoV,
	float skylight,
	float sss_depth
) {
	// Multiple scattering approximation from Jessie
	const vec3 scattering_albedo = water_scattering_coeff / water_extinction_coeff;
	const vec3 multiple_scattering_factor = 0.84 * scattering_albedo;
	const vec3 multiple_scattering_energy = multiple_scattering_factor / (1.0 - multiple_scattering_factor);

	// Minimum distance so that water is always easily visible
	dist = max(dist, 2.5);

	vec3 transmittance = exp(-water_extinction_coeff * dist);

	vec3 scattering  = light_color * exp(-water_extinction_coeff * sss_depth) * smoothstep(0.0, 0.25, skylight); // direct lighting
		 scattering *= 0.7 * henyey_greenstein_phase(LoV, 0.4) + 0.3 * isotropic_phase;                          // phase function for direct lighting
	     scattering += ambient_color * skylight * isotropic_phase;                                               // ambient lighting
	     scattering *= (1.0 - transmittance) * water_scattering_coeff / water_extinction_coeff;                  // scattering integral
		 scattering *= 1.0 + multiple_scattering_energy;                                                         // multiple scattering

	return mat2x3(scattering, transmittance);
}

//----------------------------------------------------------------------------//
#if defined WORLD_OVERWORLD

#include "/include/sky/projection.glsl"

vec3 border_fog_color(vec3 world_dir, float fog) {
	float sunset_factor = linear_step(0.1, 1.0, exp(-75.0 * sqr(sun_dir.y + 0.0496)));

	vec3 fog_color = bicubic_filter(colortex4, project_sky(world_dir)).rgb;
	vec3 fog_color_sunset = texture(colortex4, project_sky(normalize(vec3(world_dir.xz, min(world_dir.y, -0.1)).xzy))).rgb;

	fog_color = mix(fog_color, fog_color_sunset, sqr(sunset_factor));
	fog_color = mix(fog_color, cave_fog_color, biome_cave);

	return fog_color;
}

void apply_fog(inout vec3 scene_color, vec3 scene_pos, vec3 world_dir, bool sky) {
	float fog;
	float view_distance = length(scene_pos - gbufferModelView[3].xyz);

	// Border fog
#ifdef BORDER_FOG
	fog = border_fog(scene_pos, world_dir);
	scene_color = mix(border_fog_color(world_dir, fog), scene_color, clamp01(fog + float(sky)));
#endif

	// Cave fog

#ifdef CAVE_FOG
	fog = spherical_fog(view_distance, 0.0, 0.0033 * biome_cave * float(!sky));
	scene_color = mix(cave_fog_color, scene_color, fog);
#endif

	// Blindness fog

	fog = spherical_fog(view_distance, 2.0, blindness);
	scene_color *= fog;

	// Lava fog

	fog = spherical_fog(view_distance, 0.33, 3.0 * float(isEyeInWater == 2));
	scene_color = mix(lava_fog_color, scene_color, fog);

	// Powdered snow fog

	fog = spherical_fog(view_distance, 0.5, 5.0 * float(isEyeInWater == 3));
	scene_color = mix(snow_fog_color, scene_color, fog);
}

//----------------------------------------------------------------------------//
#elif defined WORLD_NETHER

void apply_fog(inout vec3 scene_color) {

}

//----------------------------------------------------------------------------//
#elif defined WORLD_END

void apply_fog(inout vec3 scene_color) {

}

#endif

#endif // INCLUDE_MISC_FOG_SIMPLE
