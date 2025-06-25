#if !defined INCLUDE_WEATHER_RAINBOW
#define INCLUDE_WEATHER_RAINBOW

#include "/include/weather/core.glsl"

float get_rainbow_amount(Weather weather) {
	return max(wetness, 0.5 * linear_step(0.6, 1.0, weather.humidity)) * float(1.0 - rainStrength);
}

#endif // INCLUDE_WEATHER_RAINBOW

