#if !defined INCLUDE_LIGHT_COLORS_WEATHER_COLOR
#define INCLUDE_LIGHT_COLORS_WEATHER_COLOR

#include "/include/sky/atmosphere.glsl"

vec3 get_rain_color() {
	return mix(0.033, 0.66, smoothstep(-0.1, 0.5, sun_dir.y)) * sunlight_color * vec3(0.49, 0.65, 1.00);
}

vec3 get_snow_color() {
	return mix(0.060, 1.60, smoothstep(-0.1, 0.5, sun_dir.y)) * sunlight_color * vec3(0.49, 0.65, 1.00);
}

vec3 get_weather_color() {
	return mix(get_rain_color(), get_snow_color(), biome_may_snow);
}

#endif // INCLUDE_LIGHT_COLORS_WEATHER_COLOR
