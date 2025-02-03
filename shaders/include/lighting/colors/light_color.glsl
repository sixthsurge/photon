#if !defined INCLUDE_LIGHTING_COLORS_LIGHT_COLOR
#define INCLUDE_LIGHTING_COLORS_LIGHT_COLOR

#include "/include/sky/atmosphere.glsl"
#include "/include/utility/color.glsl"

uniform float moon_phase_brightness;

// Magic brightness adjustment so that auto exposure isn't needed
float get_sun_exposure() {
	const float base_scale = 7.0 * SUN_I;

	float blue_hour = linear_step(0.05, 1.0, exp(-190.0 * sqr(sun_dir.y + 0.09604)));

	float daytime_mul = 1.0 + 0.5 * (time_sunset + time_sunrise) + 40.0 * blue_hour;

	return base_scale * daytime_mul;
}

vec3 get_sun_tint() {
	float blue_hour = linear_step(0.05, 1.0, exp(-190.0 * sqr(sun_dir.y + 0.09604)));

	vec3 morning_evening_tint = vec3(1.05, 0.84, 0.93) * 1.2;
	     morning_evening_tint = mix(vec3(1.0), morning_evening_tint, sqr(pulse(sun_dir.y, 0.17, 0.40)));

	vec3 blue_hour_tint = vec3(0.95, 0.80, 1.0);
	     blue_hour_tint = mix(vec3(1.0), blue_hour_tint, blue_hour);

	// User tint

	const vec3 tint_morning = from_srgb(vec3(SUN_MR, SUN_MG, SUN_MB));
	const vec3 tint_noon    = from_srgb(vec3(SUN_NR, SUN_NG, SUN_NB));
	const vec3 tint_evening = from_srgb(vec3(SUN_ER, SUN_EG, SUN_EB));

	vec3 user_tint = mix(tint_noon, tint_morning, time_sunrise);
	     user_tint = mix(user_tint, tint_evening, time_sunset);

	return morning_evening_tint * blue_hour_tint * user_tint;
}

float get_moon_exposure() {
	const float base_scale = 0.66 * MOON_I;

	return base_scale * moon_phase_brightness;
}

vec3 get_moon_tint() {
	const vec3 base_tint = from_srgb(vec3(MOON_R, MOON_G, MOON_B));

	return base_tint;
}

vec3 get_light_color() {
	vec3 light_color  = sunlight_color * atmosphere_transmittance(light_dir.y, planet_radius);
	     light_color  = atmosphere_post_processing(light_color);
	     light_color *= mix(get_sun_exposure() * get_sun_tint(), get_moon_exposure() * get_moon_tint(), step(0.5, sunAngle));
	     light_color *= clamp01(rcp(0.02) * light_dir.y); // fade away during day/night transition
		 light_color *= 1.0 - 0.25 * pulse(abs(light_dir.y), 0.15, 0.11);

	return light_color;
}

float get_skylight_boost() {
	float night_skylight_boost = 4.0 * (1.0 - smoothstep(-0.16, 0.0, sun_dir.y))
	                           - 3.0 * linear_step(0.1, 1.0, exp(-2.42 * sqr(sun_dir.y + 0.81)));

	return 1.0 + max0(night_skylight_boost);
}

#endif // INCLUDE_LIGHTING_COLORS_LIGHT_COLOR
