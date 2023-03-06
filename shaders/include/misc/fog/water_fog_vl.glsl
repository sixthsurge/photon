#ifndef INCLUDE_MISC_FOG_WATER_FOG_VL
#define INCLUDE_MISC_FOG_WATER_FOG_VL

#include "/include/utility/fast_math.glsl"

mat2x3 raymarch_water_fog(
	vec3 world_start_pos,
	vec3 world_end_pos,
	bool sky,
	float dither
) {
	const uint step_count = 16;
	const float step_length_ratio = 0.75;

	const vec2 caustics_dir_0 = vec2(cos(0.5), sin(0.5));
	const vec2 caustics_dir_1 = vec2(cos(3.0), sin(3.0));

	const vec3 absorption_coeff = vec3(WATER_ABSORPTION_R, WATER_ABSORPTION_G, WATER_ABSORPTION_B) * rec709_to_working_color;
	const vec3 scattering_coeff = vec3(WATER_SCATTERING);
	const vec3 extinction_coeff = absorption_coeff + scattering_coeff;

	vec3 world_dir = world_end_pos - world_start_pos;
	float ray_length;
	length_normalize(world_dir, world_dir, ray_length);
	if (sky) ray_length = 80.0;

	float step_length = ray_length * (1.0 - step_length_ratio) / (1.0 - pow(step_length_ratio, float(step_count)));

	// Transformations

	vec3 shadow_pos = transform(shadowModelView, world_start_pos - cameraPosition);
	     shadow_pos = project_ortho(shadowProjection, shadow_pos);

	vec3 shadow_dir = mat3(shadowModelView) * world_dir;
	     shadow_dir = diagonal(shadowProjection).xyz * shadow_dir;

	vec2 caustics_pos = (mat3(shadowModelView) * world_start_pos).xy;
	vec2 caustics_dir = (mat3(shadowModelView) * world_dir).xy;

	vec3 scattering = vec3(0.0);
	vec3 transmittance = vec3(1.0);

	for (int i = 0; i < step_count; ++i) {
		vec3 dithered_shadow_pos = shadow_pos + shadow_dir * (dither * step_length);
		vec2 dithered_caustics_pos = caustics_pos + caustics_dir * (dither * step_length);

		vec3 shadow_screen_pos = distort_shadow_space(dithered_shadow_pos) * 0.5 + 0.5;

#if defined SHADOW
	 	ivec2 shadow_texel = ivec2(shadow_screen_pos.xy * shadowMapResolution * MC_SHADOW_QUALITY);
		float depth1 = texelFetch(shadowtex1, shadow_texel, 0).x;
		float shadow = step(float(clamp01(shadow_screen_pos) == shadow_screen_pos) * shadow_screen_pos.z, depth1);
#endif

		// Caustics pattern to create underwater light shafts
		float caustics  = 0.67 * texture(noisetex, (dithered_caustics_pos + caustics_dir_0 * frameTimeCounter) * 0.01).y;
		      caustics += 0.33 * texture(noisetex, (dithered_caustics_pos + caustics_dir_1 * frameTimeCounter) * 0.02).y;
		      caustics  = linear_step(0.4, 0.5, caustics);

		// Sunlight/moonlight

		// Skylight

		// March along ray

		shadow_pos += shadow_dir * step_length;
		caustics_pos += caustics_dir * step_length;

		step_length *= step_length_ratio;
	}

	return mat2x3(scattering, transmittance);
}


#endif // INCLUDE_MISC_FOG_WATER_FOG_VL
