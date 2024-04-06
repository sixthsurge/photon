#if !defined INCLUDE_SKY_BLOCKY_CLOUDS
#define INCLUDE_SKY_BLOCKY_CLOUDS

#include "/include/sky/atmosphere.glsl"

#include "/include/utility/color.glsl"
#include "/include/utility/dithering.glsl"
#include "/include/utility/fast_math.glsl"
#include "/include/utility/phase_functions.glsl"
#include "/include/utility/random.glsl"

// Blocky volumetric clouds

const float blocky_clouds_altitude_l0 = BLOCKY_CLOUDS_ALTITUDE;
const float blocky_clouds_altitude_l1 = BLOCKY_CLOUDS_ALTITUDE_2;
const float blocky_clouds_thickness   = BLOCKY_CLOUDS_THICKNESS;

float blocky_clouds_extinction_coeff = mix(0.66, 1.0, smoothstep(0.0, 0.3, abs(sun_dir.y)));
float blocky_clouds_scattering_coeff = blocky_clouds_extinction_coeff;

float blocky_clouds_phase_single(float cos_theta) { // Single scattering phase function
	return 0.7 * klein_nishina_phase(cos_theta, 2600.0)    // forwards lobe
	     + 0.3 * henyey_greenstein_phase(cos_theta, -0.2); // backwards lobe
}

float blocky_clouds_phase_multi(float cos_theta, vec3 g) { // Multiple scattering phase function
	return 0.65 * henyey_greenstein_phase(cos_theta,  g.x)  // forwards lobe
	     + 0.10 * henyey_greenstein_phase(cos_theta,  g.y)  // forwards peak
	     + 0.25 * henyey_greenstein_phase(cos_theta, -g.z); // backwards lobe
}

float texture_soft(sampler2D sampler, vec2 coord, float softness) {
	vec2 res = vec2(textureSize(sampler, 0));

	coord = coord * res + 0.5;
	vec2 i, f = modf(coord, i);

	f = smoothstep(0.5 - softness, 0.5 + softness, f); // the closer the borders are to 0.5, the sharper the cloud edge
	coord = i * rcp(res) + rcp(res);

	vec4 samples = textureGather(sampler, coord, 3);
	vec4 weights = vec4(f.y - f.x * f.y, f.x * f.y, f.x - f.x * f.y, 1.0 - f.x - f.y + f.x * f.y);

	return dot(samples, weights);
}

float blocky_clouds_density(vec3 world_pos, float altitude_fraction, float layer_offset) {
	const float wind_angle = 30.0 * degree;
	const vec2 wind_velocity = 0.33 * vec2(cos(wind_angle), sin(wind_angle));

	const float roundness = 0.5 * BLOCKY_CLOUDS_ROUNDNESS; // Controls the roundness of the clouds
	const float sharpness = 0.5 * BLOCKY_CLOUDS_SHARPNESS;  // Controls the sharpness of the cloud edges

	// Adjust position

	world_pos.xz  = abs(world_pos.xz + 3000.0 + layer_offset);
	world_pos.xz += wind_velocity * world_age;

	// Minecraft cloud noise

	float density = texture_soft(depthtex2, world_pos.xz * 0.00018, roundness);

	// Adjust density
	density *= linear_step(0.0, roundness, altitude_fraction);
	density *= linear_step(0.0, roundness, 1.0 - altitude_fraction);
	density  = linear_step(sharpness, 1.0 - sharpness, density);

	return clamp01(density);
}

float blocky_clouds_optical_depth(
	vec3 ray_origin,
	vec3 ray_dir,
	float layer_altitude,
	float layer_offset,
	float dither,
	const uint step_count
) {
	const float step_growth = 1.2;

	float step_length = blocky_clouds_thickness / float(step_count); // m

	vec3 ray_pos = ray_origin;
	vec4 ray_step = vec4(ray_dir, 1.0) * step_length;

	float optical_depth = 0.0;

	for (uint i = 0u; i < step_count; ++i, ray_pos += ray_step.xyz) {
		ray_step *= step_growth;
		vec3 world_pos = ray_pos + ray_step.xyz * dither;
		float altitude_fraction = clamp01((world_pos.y - layer_altitude) * rcp(blocky_clouds_thickness));

		optical_depth += blocky_clouds_density(world_pos, altitude_fraction, layer_offset) * ray_step.w;
	}

	return optical_depth;
}

vec2 blocky_clouds_scattering(
	float density,
	float light_optical_depth,
	float sky_optical_depth,
	float ground_optical_depth,
	float step_transmittance,
	float cos_theta,
	float bounced_light
) {
	vec2 scattering = vec2(0.0);

	float scatter_amount = blocky_clouds_scattering_coeff;
	float extinct_amount = blocky_clouds_extinction_coeff;

	float powder = 5.0 * (1.0 - exp2(-8.0 * density));

	float scattering_integral_times_density = (1.0 - step_transmittance) / blocky_clouds_extinction_coeff;

	float phase = blocky_clouds_phase_single(cos_theta);
	vec3 phase_g = pow(vec3(0.6, 0.9, 0.3), vec3(1.0 + light_optical_depth));

	for (uint i = 0u; i < 8u; ++i) {
		scattering.x += scatter_amount * exp(-extinct_amount *  light_optical_depth) * phase;
		scattering.x += scatter_amount * exp(-extinct_amount * ground_optical_depth) * isotropic_phase * bounced_light;
		scattering.y += scatter_amount * exp(-extinct_amount *    sky_optical_depth) * isotropic_phase;

		scatter_amount *= 0.5;
		extinct_amount *= 0.5;
		phase_g *= 0.8;

		phase = blocky_clouds_phase_multi(cos_theta, phase_g);
	}

	return scattering * scattering_integral_times_density * powder;
}

vec4 raymarch_blocky_clouds(
	vec3 world_start_pos,
	vec3 world_end_pos,
	bool sky,
	float layer_altitude,
	float dither
) {
	const uint  primary_steps     = 12;
	const uint  lighting_steps    = 4;
	const float max_ray_length    = 512;
	const float min_transmittance = 0.075;

	// ---------------------
	//   Raymarching Setup
	// ---------------------

	vec3 world_dir = world_end_pos - world_start_pos;

	float length_sq = length_squared(world_dir);
	float norm = inversesqrt(length_sq);
	float ray_length = length_sq * norm;
	world_dir *= norm;

	float distance_to_lower_plane = (layer_altitude - eyeAltitude) / world_dir.y;
	float distance_to_upper_plane = (layer_altitude + blocky_clouds_thickness - eyeAltitude) / world_dir.y;
	float distance_to_volume_start, distance_to_volume_end;

	if (eyeAltitude < layer_altitude) {
		// Below volume
		distance_to_volume_start = distance_to_lower_plane;
		distance_to_volume_end   = world_dir.y < 0.0 ? -1.0 : distance_to_upper_plane;
	} else if (eyeAltitude < layer_altitude + blocky_clouds_thickness) {
		// Inside volume
		distance_to_volume_start = 0.0;
		distance_to_volume_end   = world_dir.y < 0.0 ? distance_to_lower_plane : distance_to_upper_plane;
	} else {
		// Above volume
		distance_to_volume_start = distance_to_upper_plane;
		distance_to_volume_end   = world_dir.y < 0.0 ? distance_to_lower_plane : -1.0;
	}

	if (distance_to_volume_end < 0.0) return vec4(vec3(0.0), 1.0);

	ray_length = sky ? distance_to_volume_end : ray_length;
	ray_length = clamp(ray_length - distance_to_volume_start, 0.0, max_ray_length);

	float step_length = ray_length * rcp(float(primary_steps));

	vec3 world_step = world_dir * step_length;
	vec3 world_pos  = world_start_pos + world_dir * (distance_to_volume_start + step_length * dither);

	// ------------------
	//   Lighting Setup
	// ------------------

	vec3 scattering = vec3(0.0);
	float transmittance = 1.0;

	float lighting_dither = interleaved_gradient_noise(gl_FragCoord.xy, frameCounter);

	bool moonlit = sun_dir.y < -0.06;

	vec3 light_dir = moonlit ? moon_dir : sun_dir;

	vec3 light_color  = moonlit ? moon_color : sun_color;
	     light_color *= atmosphere_transmittance(light_dir.y, planet_radius + 1e3);
		 light_color *= 1.5 - 0.5 * smoothstep(0.0, 0.15, abs(sun_dir.y));
		 light_color *= 1.0 - rainStrength;

	float cos_theta = dot(world_dir, light_dir);
	float bounced_light = 0.0;

	mat2x3 light_colors = mat2x3(light_color, ambient_color);

	float distance_sum = 0.0;
	float distance_weight_sum = 0.0;

#ifdef BLOCKY_CLOUDS_LAYER_2
	// Offset upper layer so it isn't identical to the below
	float layer_offset = abs(layer_altitude - blocky_clouds_altitude_l1) < 0.5
		? 3000.0
		: 0.0;
#else
	const float layer_offset = 0.0;
#endif

	// --------------------
	//   Raymarching Loop
	// --------------------

	for (uint i = 0u; i < primary_steps; ++i, world_pos += world_step) {
		if (transmittance < min_transmittance) break;

		float altitude_fraction = (world_pos.y - layer_altitude) * rcp(blocky_clouds_thickness);

		float density = blocky_clouds_density(world_pos, altitude_fraction, layer_offset);
		if (density < eps) continue;

		float step_optical_depth = density * blocky_clouds_extinction_coeff * step_length;
		float step_transmittance = exp(-step_optical_depth);

		float light_optical_depth  = blocky_clouds_optical_depth(world_pos, light_dir, layer_altitude, layer_offset, lighting_dither, lighting_steps);
		float ground_optical_depth = blocky_clouds_thickness * altitude_fraction;
		float sky_optical_depth    = blocky_clouds_thickness * (1.0 - altitude_fraction);

		scattering += light_colors * blocky_clouds_scattering(
			density,
			light_optical_depth,
			sky_optical_depth,
			ground_optical_depth,
			step_transmittance,
			cos_theta,
			bounced_light
		) * transmittance * mix(0.8, 1.25, cubic_smooth(altitude_fraction));

		transmittance *= step_transmittance;

		// Update distance to cloud
		float distance_to_sample = distance(cameraPosition, world_pos);
		distance_sum += distance_to_sample * density;
		distance_weight_sum += density;
	}

	// Remap the transmittance so that min_transmittance is 0
	float clouds_transmittance = linear_step(min_transmittance, 1.0, transmittance);

	// Distance fade
	float distance_fade = distance_weight_sum == 0.0
		? 1.0
		: exp(-0.002 * distance_sum / distance_weight_sum);

	scattering *= distance_fade * mix(vec3(1.0, 0.66, 0.50), vec3(1.0), distance_fade);
	transmittance = mix(1.0, transmittance, distance_fade);

	return vec4(scattering, transmittance);
}

#endif // INCLUDE_SKY_BLOCKY_CLOUDS
