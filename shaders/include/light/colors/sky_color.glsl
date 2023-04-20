#if !defined INCLUDE_LIGHT_COLORS_SKY_COLOR
#define INCLUDE_LIGHT_COLORS_SKY_COLOR

#include "/include/light/colors/weather_color.glsl"

// Magic-number sky color based on measured values from the atmosphere LUT
vec3 get_sky_color() {
	float late_sunset = linear_step(0.05, 1.0, exp(-200.0 * sqr(sun_dir.y - 0.06514)));
	float blue_hour   = linear_step(0.05, 1.0, exp(-220.0 * sqr(sun_dir.y + 0.04964)));

	vec3 sky_color  = vec3(0.41, 0.50, 0.73) * time_sunrise;
	     sky_color += vec3(0.69, 0.87, 1.67) * time_noon;
	     sky_color += vec3(0.48, 0.55, 0.75) * time_sunset;

	sky_color = mix(sky_color, vec3(0.26, 0.28, 0.33), late_sunset);
	sky_color = mix(sky_color, vec3(0.44, 0.45, 0.70), blue_hour);
	sky_color = mix(vec3(0.0), sky_color, linear_step(-0.07, 0.0, sun_dir.y));
	sky_color = mix(sky_color, 0.8 * get_weather_color() * tau, rainStrength);

	return sky_color;
}

float get_skylight_boost() {
	float early_morning = linear_step(0.05, 1.0, exp(-80.0 * sqr(sun_dir.y - 0.6)));
	float night_skylight_boost = 4.0 * (1.0 - smoothstep(-0.16, 0.0, sun_dir.y))
	                           - 3.0 * linear_step(0.1, 1.0, exp(-2.42 * sqr(sun_dir.y + 0.81)));

	return 1.0 + 0.33 * early_morning + max0(night_skylight_boost);
}


#endif // INCLUDE_LIGHT_COLORS_SKY_COLOR
