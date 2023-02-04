#if !defined FOG_INCLUDED
#define FOG_INCLUDED

#include "utility/bicubic.glsl"
#include "utility/fast_math.glsl"

// This file is for analytical fog effects; for volumetric fog, see composite.fsh

const vec3 cave_fog_color = vec3(0.033);
const vec3 lava_fog_color = from_srgb(vec3(0.839, 0.373, 0.075)) * 2.0;
const vec3 snow_fog_color = from_srgb(vec3(0.957, 0.988, 0.988)) * 0.8;

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

	return fog;
}

//----------------------------------------------------------------------------//
#if defined WORLD_OVERWORLD

#include "sky_projection.glsl"

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
	fog = border_fog(scene_pos, world_dir);
	scene_color = mix(border_fog_color(world_dir, fog), scene_color, clamp01(fog + float(sky)));

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

#endif
