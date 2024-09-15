#if !defined INCLUDE_MISC_WATER_NORMAL
#define INCLUDE_MISC_WATER_NORMAL

#include "/include/utility/space_conversion.glsl"

float gerstner_wave(vec2 coord, vec2 wave_dir, float t, float noise, float wavelength) {
	// Gerstner wave function from Belmu in #snippets, modified
	const float g = 9.8;

	float k = tau / wavelength;
	float w = sqrt(g * k);

	float x = w * t - k * (dot(wave_dir, coord) + noise);

	return sqr(sin(x) * 0.5 + 0.5);
}

float get_water_height(vec2 coord, vec2 flow_dir, bool flowing_water) {
	const uint gerstner_iterations = WATER_WAVE_ITERATIONS;
	const float wave_amplitude     = 1.0;
	const float wave_frequency     = 0.4 * WATER_WAVE_FREQUENCY;
	const float wave_speed_still   = 0.5 * WATER_WAVE_SPEED_STILL;
	const float wave_speed_flowing = 0.50 * WATER_WAVE_SPEED_FLOWING;
	const float wave_angle         = 30.0 * degree;
	const float noise_frequency    = 0.005;
	const float noise_strength     = 1.0;
	const float noise_fade         = 1.7;
	const float persistence        = 0.5 * WATER_WAVE_PERSISTENCE;
	const float lacunarity         = 2.3 * WATER_WAVE_LACUNARITY;


	float t = (flowing_water ? wave_speed_flowing : wave_speed_still) * frameTimeCounter;
	float noise = texture(noisetex, (coord + vec2(0.0, 0.25 * t)) * noise_frequency).y * noise_strength;

	float height = 0.0;
	float amplitude_sum = 0.0;

	float wave_length = 1.0;
	float amplitude = wave_amplitude;
	float frequency = wave_frequency;

	vec2 wave_dir = flowing_water ?  flow_dir : vec2(cos(wave_angle), sin(wave_angle));
	mat2 wave_rot = flowing_water ? mat2(1.0) : mat2(cos(golden_angle), sin(golden_angle), -sin(golden_angle), cos(golden_angle));

	for (uint i = 0u; i < gerstner_iterations; ++i) {
		height += gerstner_wave(coord * frequency, wave_dir, t, noise, wave_length) * amplitude;
		amplitude_sum += amplitude;

		noise *= noise_fade;
		amplitude *= persistence;
		frequency *= lacunarity;
		wave_length *= 1.25;

		wave_dir *= wave_rot;
	}

#ifdef WATER_WAVES_HEIGHT_VARIATION
	const float height_variation_frequency    = 0.001;
	const float min_height                    = 0.1;
	const float height_variation_scale        = 3.0;
	const float height_variation_offset       = -0.5;
	const float height_variation_scroll_speed = 0.1;

	float height_variation = texture(noisetex, (coord + vec2(0.0, height_variation_scroll_speed * t)) * height_variation_frequency).y;
	      height_variation = max(min_height, height_variation * height_variation_scale + height_variation_offset);
	
	height *= height_variation;
#endif

	return (height / amplitude_sum);
}

vec3 get_water_normal(vec3 world_pos, vec3 flat_normal, vec2 coord, vec2 flow_dir, float skylight, bool flowing_water) {
	const float h = 0.1;
	float wave0 = get_water_height(coord, flow_dir, flowing_water);
	float wave1 = get_water_height(coord + vec2(h, 0.0), flow_dir, flowing_water);
	float wave2 = get_water_height(coord + vec2(0.0, h), flow_dir, flowing_water);

#if defined WORLD_OVERWORLD
	float normal_influence  = flowing_water
		? 0.05
		: mix(0.01, 0.04 + 0.15 * rainStrength, dampen(skylight));
#else
	float normal_influence  = 0.04;
#endif
	      normal_influence *= smoothstep(0.0, 0.05, abs(flat_normal.y));
	      normal_influence *= smoothstep(0.0, 0.15, abs(dot(flat_normal, normalize(world_pos - cameraPosition)))); // prevent noise when looking horizontally
	      normal_influence *= WATER_WAVE_STRENGTH;


	vec3 normal     = vec3(wave1 - wave0, wave2 - wave0, h);
	     normal.xy *= normal_influence;

	return normalize(normal);
}

vec2 get_water_parallax_coord(vec3 tangent_dir, vec2 coord, vec2 flow_dir, bool flowing_water) {
	const int step_count = 4;
	const float parallax_depth = 0.2;

	vec2 ray_step = tangent_dir.xy * rcp(-tangent_dir.z) * parallax_depth * rcp(float(step_count));

	float depth_value = get_water_height(coord, flow_dir, flowing_water);
	float depth_march = 0.0;
	float depth_previous;

	while (depth_march < depth_value) {
		coord += ray_step;
		depth_previous = depth_value;
		depth_value = get_water_height(coord, flow_dir, flowing_water);
		depth_march += rcp(float(step_count));
	}

	// Interpolation step

	float depth_before = depth_previous - depth_march + rcp(float(step_count));
	float depth_after  = depth_value - depth_march;

	return mix(coord, coord - ray_step, depth_after / (depth_after - depth_before));
}

#endif // INCLUDE_MISC_WATER_NORMAL
