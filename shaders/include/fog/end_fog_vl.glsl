#if !defined INCLUDE_FOG_END_FOG_VL
#define INCLUDE_FOG_END_FOG_VL

#include "/include/lighting/shadows/distortion.glsl"
#include "/include/utility/color.glsl"
#include "/include/utility/fast_math.glsl"
#include "/include/utility/phase_functions.glsl"

float end_fog_density(vec3 world_pos) {
	const float falloff_start     = 64.0;
	const float falloff_half_life = 7.0;

	const float mul = -rcp(falloff_half_life);
	const float add = -mul * falloff_start;

	float density = exp2(min(world_pos.y * mul + add, 0.0));

	// fade away below the island
	density *= linear_step(0.0, 64.0, world_pos.y);

	return density;
}

vec3 end_fog_emission(vec3 world_pos) {
	const vec3 main_col = from_srgb(vec3(END_AMBIENT_R, END_AMBIENT_G, END_AMBIENT_B)) * END_AMBIENT_I;
	const vec3 alt_col  = 0.5 * vec3(0.25, 1.0, 0.5);
	const vec3 wind0    = vec3(1.0, 0.1, 0.5) * 0.01;
	const vec3 wind1    = vec3(-0.7, -0.1, -0.1) * 0.05;

	float base_noise  = texture(colortex0, 0.02 * world_pos + wind0 * frameTimeCounter).x;
	float detail_nose = texture(colortex0, 0.04 * world_pos + wind1 * frameTimeCounter).x * 0.8 - 0.4;
	float color_noise = texture(colortex0, 0.02 * world_pos + 0.2).x;

	float density = max0(linear_step(0.6, 0.9, base_noise) + detail_nose);
	float color_mix = linear_step(0.5, 0.7, color_noise);

	float view_dist   = distance(world_pos, cameraPosition);
	float fade_near   = 1.0 - exp2(-0.1 * view_dist);
	float fade_far    = exp2(-0.05 * view_dist);
	float fade_height = exp2(-0.05 * (max0(cameraPosition.y - 120.0))) * linear_step(0.0, 64.0, world_pos.y);

	return mix(main_col, alt_col, color_mix) * (density * fade_near * fade_far * fade_height);
}

mat2x3 raymarch_end_fog(
	vec3 world_start_pos,
	vec3 world_end_pos,
	bool sky,
	float dither
) {
	const uint min_step_count     = 16;
	const uint max_step_count     = 25;
	const float volume_top        = 256.0;
	const float volume_bottom     = 0.0;
	const float step_count_growth = 0.5;

	const vec3 end_color        = from_srgb(vec3(END_AMBIENT_R, END_AMBIENT_G, END_AMBIENT_B));
	const float density_scale   = 0.01;
	const vec3 absorption_coeff = exp2(-end_color) * density_scale;
	const vec3 scattering_coeff = vec3(1.0) * density_scale;
	const vec3 extinction_coeff = absorption_coeff + scattering_coeff;

	const uint multiple_scattering_iterations = 4;

	vec3 world_dir = world_end_pos - world_start_pos;
	float ray_length;
	length_normalize(world_dir, world_dir, ray_length);

	float distance_to_lower_plane = (volume_bottom - eyeAltitude) / world_dir.y;
	float distance_to_upper_plane = (volume_top    - eyeAltitude) / world_dir.y;
	float distance_to_volume_start, distance_to_volume_end;

	if (eyeAltitude < volume_bottom) {
		// Below volume
		distance_to_volume_start = distance_to_lower_plane;
		distance_to_volume_end = world_dir.y < 0.0 ? -1.0 : distance_to_upper_plane;
	} else if (eyeAltitude < volume_top) {
		// Inside volume
		distance_to_volume_start = 0.0;
		distance_to_volume_end = world_dir.y < 0.0 ? distance_to_lower_plane : distance_to_upper_plane;
	} else {
		// Above volume
		distance_to_volume_start = distance_to_upper_plane;
		distance_to_volume_end = world_dir.y < 0.0 ? distance_to_upper_plane : -1.0;
	}

	if (distance_to_volume_end < 0.0) return mat2x3(vec3(0.0), vec3(1.0));

	ray_length = sky ? distance_to_volume_end : ray_length;
	ray_length = clamp(ray_length - distance_to_volume_start, 0.0, far);

	// Adjust step count based on ray length
	uint step_count = uint(float(min_step_count) + step_count_growth * ray_length);
	     step_count = min(step_count, max_step_count);

	float step_length = ray_length * rcp(float(step_count));
	vec3 world_step = world_dir * step_length;

	// Jitter ray origin
	vec3 world_pos = world_start_pos + world_dir * (distance_to_volume_start + step_length * dither);

	// Space conversions

	vec3 shadow_pos = transform(shadowModelView, world_pos - cameraPosition);
	     shadow_pos = project_ortho(shadowProjection, shadow_pos);

	vec3 shadow_step = mat3(shadowModelView) * world_step;
	     shadow_step = diagonal(shadowProjection).xyz * shadow_step;

	// Calculations moved out of the loop

	float LoV = dot(world_dir, light_dir);

	vec3 scattering = vec3(0.0);
	vec3 transmittance = vec3(1.0);

	for (int i = 0; i < step_count; ++i, world_pos += world_step, shadow_pos += shadow_step) {
		vec3 shadow_screen_pos = distort_shadow_space(shadow_pos) * 0.5 + 0.5;

#ifdef SHADOW
	 	ivec2 shadow_texel = ivec2(shadow_screen_pos.xy * shadowMapResolution * MC_SHADOW_QUALITY);
		float depth0 = texelFetch(shadowtex0, shadow_texel, 0).x;
		float depth1 = texelFetch(shadowtex1, shadow_texel, 0).x;
		float shadow = step(float(clamp01(shadow_screen_pos) == shadow_screen_pos) * shadow_screen_pos.z, depth1);
#else
		#define shadow 1.0
#endif

		float density = end_fog_density(world_pos) * step_length;

		vec3 step_optical_depth = extinction_coeff * density;
		vec3 step_transmittance = exp(-step_optical_depth);
		vec3 step_transmitted_fraction = (1.0 - step_transmittance) / max(step_optical_depth, eps);

		vec3 visible_scattering = step_transmitted_fraction * transmittance;

		float anisotropy = 1.0;
		float scattering_amount = 1.0;
		for (uint i = 0u; i < multiple_scattering_iterations; ++i) {
			float mie_phase = 0.7 * henyey_greenstein_phase(LoV, 0.5 * anisotropy) + 0.3 * isotropic_phase;

			// Sunlight
			scattering += density * light_color * mie_phase * shadow * visible_scattering * scattering_amount;

			// Ambient light
			scattering += density * ambient_color * isotropic_phase * visible_scattering * scattering_amount;

			anisotropy *= 0.5;
			scattering_amount *= 0.5;
		}

#ifdef END_GLOW
		// Emission
		scattering += 4.0 * end_fog_emission(world_pos) * step_length * transmittance;
#endif

		transmittance *= step_transmittance;
	}

	scattering *= scattering_coeff;
	transmittance = pow(transmittance, vec3(0.75));

	return mat2x3(scattering, transmittance);
}

#endif // INCLUDE_FOG_END_FOG_VL
