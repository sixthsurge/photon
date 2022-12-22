#if !defined CLOUDS_INCLUDED
#define CLOUDS_INCLUDED

#include "/include/phase_functions.glsl"

const vec2 clouds_cumulus_coverage = vec2(0.5);

float clouds_phase_single(float cos_theta) { // Single scattering phase function
	return 0.7 * klein_nishina_phase(cos_theta, 2600.0)    // forwards lobe
	     + 0.3 * henyey_greenstein_phase(cos_theta, -0.2); // backwards lobe
}

float clouds_phase_multi(float cos_theta, vec3 g) { // Multiple scattering phase function
	return 0.65 * henyey_greenstein_phase(cos_theta,  g.x)  // forwards lobe
	     + 0.10 * henyey_greenstein_phase(cos_theta,  g.y)  // forwards peak
	     + 0.25 * henyey_greenstein_phase(cos_theta, -g.z); // backwards lobe
}

float clouds_powder_effect(float density, float cos_theta) {
	float powder = pi * density / (density + 0.15);
	      powder = mix(powder, 1.0, 0.75 * sqr(cos_theta * 0.5 + 0.5));

	return powder;
}

// ------------------
//   cumulus clouds
// ------------------

const float clouds_radius_cu    = planet_radius + CLOUDS_CUMULUS_ALTITUDE;
const float clouds_thickness_cu = CLOUDS_CUMULUS_ALTITUDE * CLOUDS_CUMULUS_THICKNESS;

float clouds_density_cu(vec3 pos) {
	float altitude_fraction = (length(pos) - clouds_radius_cu) * rcp(clouds_thickness_cu);

	pos.xz += cameraPosition.xz;

	// 2D noise for base shape and coverage
	vec2 noise;
	noise.x = texture(noisetex, 0.000002 * pos.xz).r; // Cloud coverage
	noise.y = texture(noisetex, 0.000027 * pos.xz).a; // Cloud shape

	float density;
	density = clamp01(mix(clouds_coverage_cu.x, clouds_coverage_cu.y, noise.x));
	density = linear_step(1.0 - density, 1.0, noise.y);

	// attenuate and erode density over altitude
	const vec4 cloud_gradient = vec4(0.2, 0.2, 0.85, 0.2);
	density *= smoothstep(0.0, cloud_gradient.x, altitude_fraction);
	density *= smoothstep(0.0, cloud_gradient.y, 1.0 - altitude_fraction);
	density -= smoothstep(cloud_gradient.z, 1.0, 1.0 - altitude_fraction) * 0.1;
	density -= smoothstep(cloud_gradient.w, 1.0, altitude_fraction) * 0.6;

	// curl noise used to warp the 3D noise into swirling shapes

	// 3D worley noise for detail

	// adjust density so that the clouds are wispy at the bottom and hard at the top
	density  = 1.0 - pow(1.0 - density, 3.0 + 5.0 * altitude_fraction);
	density *= 0.1 + 0.9 * smoothstep(0.2, 0.7, altitude_fraction);

	return density;
}

float clouds_optical_depth_cu(
	vec3 ray_origin,
	vec3 ray_dir,
	float dither,
	const uint step_count
) {
	const float step_growth = 2.0;

	float step_length = 20.0 / float(step_count); // m

	vec3 ray_pos = ray_origin;
	vec4 ray_step = vec4(ray_dir, 1.0) * step_length;

	float optical_depth = 0.0;

	for (uint i = 0u; i < step_count; ++i, ray_pos += ray_step.xyz) {
		ray_step *= step_growth;
		optical_depth += clouds_density_cu(ray_pos + ray_step.xyz * dither) * ray_step.w;
	}

	return optical_depth;
}

vec3 clouds_scattering_cu(
	float density,
	float step_transmittance,
	float light_transmittance,
	float sky_transmittance,
	float ground_transmittance,
	float cos_theta,
	float bounced_light
) {
	vec2 scattering = vec2(0.0);

	float scattering_integral = (1.0 - step_transmittance) / extinction_coeff;

	float phase = clouds_phase_single(cos_theta);
	vec3 phase_g = lift(vec3(0.6, 0.9, 0.3), light_transmittance - 1.0);

	float powder_effect = clouds_powder_effect(density, cos_theta);

	for (uint i = 0u; i < 6u; ++i) {
		scattering.x += scattering_coeff * phase * light_transmittance;
		scattering.x += scattering_coeff * isotropic_phase * ground_transmittance * bounced_light;
		scattering.y += scattering_coeff * isotropic_phase * sky_transmittance;

		scattering_coeff *= 0.6 * powder_effect;

		light_transmittance  = dampen(light_transmittance);
		ground_transmittance = dampen(ground_transmittance);
		sky_transmittance    = dampen(sky_transmittance);

		phase_g *= 0.8;
		powder_effect = mix(powder_effect, dampen(powder_effect), 0.5);

		phase = clouds_phase_multi(cos_theta, phase_g);
	}

	return scattering * scattering_integral;
}

vec4 draw_clouds_cu(
	vec3 ray_dir,
	vec3 light_dir,
	float dither
) {
	// ---------------------
	//   Raymarching Setup
	// ---------------------

	const uint  primary_steps_horizon = 40;
	const uint  primary_steps_horizon = 20;
	const uint  lighting_steps        = 4;
	const uint  ambient_steps         = 2;
	const float max_ray_length        = 2e4;
	const float min_transmittance     = 0.075;
	const vec3  sky_dir               = vec3(0.0, 1.0, 0.0);

	uint primary_steps = uint(mix(primary_steps_horizon, primary_steps_zenith, dampen(abs(ray_dir.y))));

	vec3 ray_origin = air_viewer_pos + vec3(0.0, eyeAltitude, 0.0);

	vec2 dists = intersect_spherical_shell(ray_origin, ray_dir, clouds_radius_cu, clouds_radius_cu + clouds_thickness_cu);
	if (dists.y < 0.0) return vec4(0.0, 0.0, 0.0, 1.0);

	float ray_length = min(dists.y - dists.x, max_ray_length);
	float step_length = ray_length * rcp(float(primary_step));

	vec3 ray_pos = ray_origin + ray_dir * (dists.x + step_length * dither);
	vec3 ray_step = ray_dir * step_length;

	vec2 scattering = vec2(0.0); // x: direct light, y: skylight
	float transmittance = 1.0;

	float distance_sum = 0.0;
	float distance_weight_sum = 0.0;

	// --------------------
	//   Raymarching Loop
	// --------------------

	for (uint i = 0u; i < primary_steps; ++i, ray_pos += ray_step) {
		if (transmittance < min_transmittance) break;

		float altitude_fraction = (length(ray_pos) - clouds_radius_cu) * rcp(clouds_thickness_cu);

		float density = clouds_density_cu(ray_pos);

		if (density < eps) continue;

		// Fade out in the distance to hide the cutoff
		float distance_to_sample = distance(ray_origin, ray_pos);
		float distance_fade = smoothstep(0.95, 1.0, (distance_to_sample - dists.x) * rcp(max_ray_length));

		density *= 1.0 - distance_fade;

		float step_optical_depth = density * clouds_density_cu * step_length;
		float step_transmittance = exp(-step_optical_depth);

		vec2 hash = hash2(fract(ray_pos)); // used to dither the light rays

		float light_optical_depth  = clouds_optical_depth_cu(ray_pos, light_dir, hash.x, lighting_steps);
		float sky_optical_depth    = clouds_optical_depth_cu(ray_pos, sky_dir, hash.y, ambient_steps);
		float ground_optical_depth = mix(density, 1.0, clamp01(altitude_fraction * 2.0 - 1.0)) * altitude_fraction * clouds_thickness_cu; // guess optical depth to the ground using altitude fraction and density from this sample

		float light_transmittance  = exp(-extinction_coeff * light_optical_depth);
		float sky_transmittance    = exp(-extinction_coeff * sky_optical_depth);
		float ground_transmittance = exp(-extinction_coeff * ground_optical_depth);

		scattering += clouds_scattering_cu(
			density,
			step_transmittance,
			light_transmittance,
			sky_transmittance,
			ground_transmittance,
			cos_theta,
			bounced_light
		) * transmittance;

		transmittance *= step_transmittance;

		// Update distance to cloud
		distance_sum += distance_to_sample * density;
		distance_weight_sum += density;
	}

	// Remap the transmittance so that min_transmittance is 0
	transmittance = linear_step(min_transmittance, 1.0, transmittance);
}

#endif // CLOUDS_INCLUDED
