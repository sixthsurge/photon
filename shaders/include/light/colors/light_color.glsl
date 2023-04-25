#if !defined INCLUDE_LIGHT_COLORS_LIGHT_COLOR
#define INCLUDE_LIGHT_COLORS_LIGHT_COLOR

#include "/include/sky/atmosphere.glsl"
#include "/include/utility/color.glsl"

// Magic brightness adjustment so that auto exposure isn't needed
float get_sun_exposure() {
	const float base_scale = 7.0 * SUN_I;

	float blue_hour = linear_step(0.05, 1.0, exp(-190.0 * sqr(sun_dir.y + 0.09604)));

	float daytime_mul = 1.0 + 0.5 * (time_sunset + time_sunrise) + 40.0 * blue_hour;

	return base_scale * daytime_mul;
}

vec3 get_sun_tint(float overcastness) {
	const vec3 base_tint = from_srgb(vec3(SUN_R, SUN_G, SUN_B));

	float blue_hour = linear_step(0.05, 1.0, exp(-190.0 * sqr(sun_dir.y + 0.09604)));

	vec3 morning_evening_tint = vec3(1.05, 0.84, 0.93) * 1.2;
	     morning_evening_tint = mix(vec3(1.0), morning_evening_tint, sqr(pulse(sun_dir.y, 0.17, 0.40)));

	vec3 blue_hour_tint = vec3(1.0, 0.85, 0.95);
	     blue_hour_tint = mix(vec3(1.0), blue_hour_tint, blue_hour);

	vec3 overcast_tint = vec3(0.8, 0.9, 1.0);
	     overcast_tint = mix(vec3(1.0), overcast_tint, overcastness);

	return base_tint * morning_evening_tint * blue_hour_tint * overcast_tint;
}

float get_moon_exposure() {
	const float base_scale = 0.5 * MOON_I;

	return base_scale;
}

vec3 get_moon_tint(float overcastness) {
	const vec3 base_tint = from_srgb(vec3(MOON_R, MOON_G, MOON_B));

	vec3 overcast_tint = vec3(0.8, 0.9, 1.0);
	     overcast_tint = mix(vec3(1.0), overcast_tint, overcastness);

	return base_tint * overcast_tint;
}

vec3 get_light_color(float overcastness) {
	vec3 light_color  = mix(get_sun_exposure() * get_sun_tint(overcastness), get_moon_exposure() * get_moon_tint(overcastness), step(0.5, sunAngle));
	     light_color *= sunlight_color * atmosphere_transmittance(light_dir.y, planet_radius) * vec3(0.96, 0.96, 1.0);
	     light_color *= clamp01(rcp(0.02) * light_dir.y); // fade away during day/night transition
		 light_color *= 1.0 - 0.25 * pulse(abs(light_dir.y), 0.15, 0.11);
		 light_color *= 1.0 - rainStrength;
		 light_color *= 1.0 - 0.45 * overcastness;

	return light_color;
}

#endif // INCLUDE_LIGHT_COLORS_LIGHT_COLOR
