#ifndef INCLUDE_MISC_PALETTE
#define INCLUDE_MISC_PALETTE

//----------------------------------------------------------------------------//
#if   defined WORLD_OVERWORLD

#include "/include/sky/atmosphere.glsl"
#include "/include/utility/color.glsl"

// --------------------------
//   Sunlight and moonlight
// --------------------------

// Magic brightness adjustments, pre-exposing for the light source to compensate
// for the lack of auto exposure by default
float get_sun_exposure() {
	const float base_scale = 7.0 * SUN_I;

	float blue_hour = linear_step(0.05, 1.0, exp(-190.0 * sqr(sun_dir.y + 0.09604)));

	float daytime_mul = 1.0 + 0.5 * (time_sunset + time_sunrise) + 40.0 * blue_hour;

	return base_scale * daytime_mul;
}

vec3 get_sun_tint() {
	const vec3 base_tint = from_srgb(vec3(SUN_R, SUN_G, SUN_B));

	float blue_hour = linear_step(0.05, 1.0, exp(-190.0 * sqr(sun_dir.y + 0.09604)));

	vec3 morning_evening_tint = vec3(1.05, 0.84, 0.93) * 1.2;
	     morning_evening_tint = mix(vec3(1.0), morning_evening_tint, sqr(pulse(sun_dir.y, 0.17, 0.40)));

	vec3 blue_hour_tint = vec3(1.0, 0.85, 0.95);
	     blue_hour_tint = mix(vec3(1.0), blue_hour_tint, blue_hour);

	return base_tint * morning_evening_tint * blue_hour_tint;
}

float get_moon_exposure() {
	const float base_scale = 0.66 * MOON_I;

	return base_scale;
}

vec3 get_moon_tint() {
	const vec3 base_tint = from_srgb(vec3(MOON_R, MOON_G, MOON_B));

	return base_tint;
}

vec3 get_light_color() {
	vec3 light_color  = mix(get_sun_exposure() * get_sun_tint(), get_moon_exposure() * get_moon_tint(), step(0.5, sunAngle));
	     light_color *= sunlight_color * atmosphere_transmittance(light_dir.y, planet_radius) * vec3(0.96, 0.96, 1.0);
	     light_color *= clamp01(rcp(0.02) * light_dir.y); // fade away during day/night transition
		 light_color *= 1.0 - 0.25 * pulse(abs(light_dir.y), 0.15, 0.11);
		 light_color *= 1.0 - rainStrength;

	return light_color;
}

// -------
//   Sky
// -------

vec3 get_rain_color() {
	return mix(0.033, 0.50, smoothstep(-0.1, 0.5, sun_dir.y)) * sunlight_color * vec3(0.49, 0.65, 1.00);
}

vec3 get_snow_color() {
	return mix(0.060, 1.60, smoothstep(-0.1, 0.5, sun_dir.y)) * sunlight_color * vec3(0.49, 0.65, 1.00);
}

vec3 get_weather_color() {
	return mix(get_rain_color(), get_snow_color(), biome_may_snow);
}

vec3 get_sky_color() {
	vec3 sky_color = vec3(0.41, 0.50, 0.73) * time_sunrise
	               + vec3(0.69, 0.87, 1.67) * time_noon
				   + vec3(0.48, 0.55, 0.75) * time_sunset;

	float late_sunset = linear_step(0.05, 1.0, exp(-200.0 * sqr(sun_dir.y - 0.06514)));

	float blue_hour = linear_step(0.05, 1.0, exp(-220.0 * sqr(sun_dir.y + 0.04964)));

	sky_color = mix(sky_color, vec3(0.26, 0.28, 0.33), late_sunset);
	sky_color = mix(sky_color, vec3(0.44, 0.45, 0.70), blue_hour);
	sky_color = mix(vec3(0.0), sky_color, linear_step(-0.07, 0.0, sun_dir.y));
	sky_color = mix(sky_color, 0.8 * get_weather_color() * tau, rainStrength);

	return sky_color;
}

float get_skylight_boost() {
	float night_skylight_boost = 4.0 * (1.0 - smoothstep(-0.16, 0.0, sun_dir.y))
	                           - 3.0 * linear_step(0.1, 1.0, exp(-2.42 * sqr(sun_dir.y + 0.81)));

	return 1.0 + max0(night_skylight_boost);
}

//----------------------------------------------------------------------------//
#elif defined WORLD_NETHER

float get_skylight_boost() {
	return 1.0;
}

//----------------------------------------------------------------------------//
#elif defined WORLD_END

float get_skylight_boost() {
	return 1.0;
}

#endif

#endif // INCLUDE_MISC_PALETTE
