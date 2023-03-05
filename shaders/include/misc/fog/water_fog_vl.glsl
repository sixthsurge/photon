#ifndef INCLUDE_MISC_FOG_WATER_FOG_VL
#define INCLUDE_MISC_FOG_WATER_FOG_VL

const vec3 water_absorption_coeff = vec3(WATER_ABSORPTION_R, WATER_ABSORPTION_G, WATER_ABSORPTION_B) * rec709_to_working_color;
const vec3 water_scattering_coeff = vec3(WATER_SCATTERING);
const vec3 water_extinction_coeff = water_absorption_coeff + water_scattering_coeff;

mat2x3 raymarch_water_fog(
	vec3 world_start_pos,
	vec3 world_end_pos,
	bool sky,
	float dither
) {
	vec3 world_dir = world_end_pos - world_start_pos;

	float length_sq = length_squared(world_dir);
	float norm = inversesqrt(length_sq);
	float ray_length = length_sq * norm;
	world_dir *= norm;

	vec3 shadow_start_pos = transform(shadowModelView, world_start_pos - cameraPosition);
	     shadow_start_pos = project_ortho(shadowProjection, shadow_start_pos);

	vec3 shadow_dir = mat3(shadowModelView) * world_dir;
	     shadow_dir = diagonal(shadowProjection).xyz * shadow_dir;

	ray_length = sky ? 80.0 : ray_length;
	ray_length = clamp(ray_length - distance_to_volume_start, 0.0, far);

	uint step_count = uint(float(air_fog_min_step_count) + air_fog_step_count_growth * ray_length);
	     step_count = min(step_count, air_fog_max_step_count);

	float step_length = ray_length * rcp(float(step_count));

	vec3 world_step = world_dir * step_length;
	vec3 world_pos  = world_start_pos + world_dir * (distance_to_volume_start + step_length * dither);

	vec3 shadow_step = shadow_dir * step_length;
	vec3 shadow_pos  = shadow_start_pos + shadow_dir * (distance_to_volume_start + step_length * dither);

	vec3 transmittance = vec3(1.0);

	for (int i = 0; i < step_count; ++i, world_pos += world_step, shadow_pos += shadow_step) {
		vec3 shadow_screen_pos = distort_shadow_space(shadow_pos) * 0.5 + 0.5;

#if defined SHADOW
		float depth1 = texelFetch(shadowtex1, shadow_texel, 0).x;
		float shadow = step(float(clamp01(shadow_screen_pos) == shadow_screen_pos) * shadow_screen_pos.z, depth1);
#endif
	}

	return mat2x3(scattering, transmittance);
}


#endif // INCLUDE_MISC_FOG_WATER_FOG_VL
