#if !defined INCLUDE_LIGHTING_COLORS_WEATHER_COLOR
#define INCLUDE_LIGHTING_COLORS_WEATHER_COLOR

#include "/include/sky/atmosphere.glsl"

uniform float biome_may_sandstorm;

vec3 get_rain_color() {
	return mix(0.033, 0.66, smoothstep(-0.1, 0.5, sun_dir.y)) * sunlight_color * vec3(0.49, 0.65, 1.00);
}

vec3 get_snow_color() {
#if defined PROGRAM_WEATHER
	return mix(0.5, 1.60, smoothstep(-0.1, 0.5, sun_dir.y)) * sunlight_color * vec3(0.49, 0.65, 1.00);
#else
	return mix(0.060, 1.60, smoothstep(-0.1, 0.5, sun_dir.y)) * sunlight_color * vec3(0.49, 0.65, 1.00);
#endif
}

vec3 get_sandstorm_color() {
	return mix(0.033, 0.66, smoothstep(-0.1, 0.5, sun_dir.y)) * sunlight_color * vec3(1.00, 0.83, 0.60);
}

vec3 get_weather_color() {
	vec3 weather_color = mix(get_rain_color(), get_snow_color(), biome_may_snow);
	     weather_color = mix(weather_color, get_sandstorm_color(), biome_may_sandstorm);

	return weather_color;
}

#endif // INCLUDE_LIGHTING_COLORS_WEATHER_COLOR
