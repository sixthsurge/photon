#if !defined INCLUDE_FOG_WATER_FOG_VL
#define INCLUDE_FOG_WATER_FOG_VL

#include "/include/lighting/shadows/distortion.glsl"
#include "/include/utility/color.glsl"
#include "/include/utility/fast_math.glsl"
#include "/include/utility/phase_functions.glsl"

const float max_ray_length = 50.0;

mat2x3 raymarch_water_fog(
	vec3 world_start_pos,
	vec3 world_end_pos,
	bool sky,
	float dither
) {
	const uint min_step_count = 16;
	const uint max_step_count = 25;
	const float step_count_growth = 0.5;

	const vec2 caustics_dir_0 = vec2(cos(0.5), sin(0.5));
	const vec2 caustics_dir_1 = vec2(cos(3.0), sin(3.0));

	const vec3 absorption_coeff = vec3(WATER_ABSORPTION_R_UNDERWATER, WATER_ABSORPTION_G_UNDERWATER, WATER_ABSORPTION_B_UNDERWATER) * rec709_to_working_color;
	const vec3 scattering_coeff = vec3(WATER_SCATTERING_UNDERWATER);
	const vec3 extinction_coeff = absorption_coeff + scattering_coeff;

	const uint multiple_scattering_iterations = 4;

	vec3 world_dir = world_end_pos - world_start_pos;
	float ray_length;
	length_normalize(world_dir, world_dir, ray_length);
	if (sky || ray_length > max_ray_length) ray_length = max_ray_length;

	// Adjust step count based on ray length
	uint step_count = uint(float(min_step_count) + step_count_growth * ray_length);
	     step_count = min(step_count, max_step_count);

	float step_length = ray_length * rcp(float(step_count));
	vec3 world_step = world_dir * step_length;

	// Jitter ray origin
	vec3 world_pos = world_start_pos + world_dir * step_length * dither;

	// Space conversions

	vec3 shadow_pos = transform(shadowModelView, world_pos - cameraPosition);
	     shadow_pos = project_ortho(shadowProjection, shadow_pos);

	vec3 shadow_step = mat3(shadowModelView) * world_step;
	     shadow_step = diagonal(shadowProjection).xyz * shadow_step;

	vec2 caustics_pos  = (mat3(shadowModelView) * mod(world_pos, 512.0)).xy;
	vec2 caustics_step = (mat3(shadowModelView) * world_step).xy;

	// Calculations moved out of the loop

	float t = frameTimeCounter * 0.25;
	float skylight = eye_skylight;

	float LoV = dot(world_dir, light_dir);

	vec3 step_transmittance = exp(-extinction_coeff * step_length);

	vec3 scattering = vec3(0.0);
	vec3 transmittance = vec3(1.0);

	for (int i = 0; i < step_count; ++i, world_pos += world_step, shadow_pos += shadow_step, caustics_pos += caustics_step) {
		vec3 shadow_screen_pos = distort_shadow_space(shadow_pos) * 0.5 + 0.5;

#if defined SHADOW && (defined WORLD_OVERWORLD || defined WORLD_END)
	 	ivec2 shadow_texel = ivec2(shadow_screen_pos.xy * shadowMapResolution * MC_SHADOW_QUALITY);
		float depth0 = texelFetch(shadowtex0, shadow_texel, 0).x;
		float depth1 = texelFetch(shadowtex1, shadow_texel, 0).x;
		float shadow = step(float(clamp01(shadow_screen_pos) == shadow_screen_pos) * shadow_screen_pos.z, depth1);

		// Calculate sunlight transmittance through the volume
		float distance_traveled = abs(depth0 - shadow_screen_pos.z) * -shadowProjectionInverse[2].z * rcp(SHADOW_DEPTH_SCALE);

		// Guess the transmittance to sky using trigonometry
		float distance_traveled_sky = distance_traveled * light_dir.y;
		      distance_traveled_sky = min(distance_traveled_sky, 15.0 - 15.0 * eye_skylight + max0(eyeAltitude - world_pos.y));
#else
		#define shadow 1.0
		#define distance_traveled 0.0
		float distance_traveled_sky = 15.0 - 15.0 * eye_skylight + max0(eyeAltitude - world_pos.y);
#endif

		vec3 light_transmittance = exp(-extinction_coeff * distance_traveled) * shadow;
		vec3 sky_transmittance   = exp(-extinction_coeff * distance_traveled_sky);

		// Caustics pattern to create underwater light shafts
		float caustics  = 0.67 * texture(noisetex, (caustics_pos + caustics_dir_0 * t) * 0.02).y;
		      caustics += 0.33 * texture(noisetex, (caustics_pos + caustics_dir_1 * t) * 0.04).y;
		      caustics  = linear_step(0.4, 0.5, caustics) + 0.15;

		float anisotropy = 1.0;
		float scattering_amount = 1.0;
		for (uint i = 0u; i < multiple_scattering_iterations; ++i) {
			float mie_phase = 0.7 * henyey_greenstein_phase(LoV, 0.5 * anisotropy) + 0.3 * isotropic_phase;

			// Sunlight/moonlight
			scattering += light_color * caustics * mie_phase * light_transmittance * transmittance * scattering_amount;

			// Skylight
			scattering += ambient_color * isotropic_phase * transmittance * scattering_amount * sky_transmittance;

			anisotropy *= 0.5;
			scattering_amount *= 0.5;
			light_transmittance = sqrt(light_transmittance);
			sky_transmittance = sqrt(sky_transmittance);
		}

		transmittance *= step_transmittance;
	}

	scattering *= (1.0 - step_transmittance) * scattering_coeff / extinction_coeff;
	transmittance = pow(transmittance, vec3(0.75));

	return mat2x3(scattering, transmittance);
}


#endif // INCLUDE_FOG_WATER_FOG_VL