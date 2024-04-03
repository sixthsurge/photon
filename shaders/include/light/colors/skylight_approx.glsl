#if !defined INCLUDE_LIGHT_COLORS_SKYLIGHT_APPROX
#define INCLUDE_LIGHT_COLORS_SKYLIGHT_APPROX

#if defined WORLD_OVERWORLD && defined PROGRAM_DEFERRED4 && !defined SH_SKYLIGHT
#include "/include/light/colors/weather_color.glsl"

vec3 skylight_approx(vec3 normal, vec3 flat_normal, vec3 shadows, float directional_lighting, float ao) {
	vec3 horizon_color = mix(sky_samples[1], sky_samples[2], dot(normal.xz, moon_dir.xz) * 0.5 + 0.5);
	     horizon_color = mix(horizon_color, mix(sky_samples[1], sky_samples[2], step(sun_dir.y, 0.5)), abs(normal.y) * (time_noon + time_midnight));

	float horizon_weight = 0.166 * (time_noon + time_midnight) + 0.03 * (time_sunrise + time_sunset);

	vec3 skylight  = mix(sky_samples[0] * 1.3, horizon_color, horizon_weight);
	     skylight  = mix(horizon_color * 0.2, skylight, clamp01(abs(normal.y)) * 0.3 + 0.7);
	     skylight *= 1.0 - 0.75 * clamp01(-normal.y);
	     skylight *= 1.0 + 0.33 * clamp01(flat_normal.y) * (1.0 - shadows.x * (1.0 - rainStrength)) * (time_noon + time_midnight);

	if (rainStrength > 1e-2) {
		vec3 rain_skylight  = get_weather_color() * sqr(directional_lighting);
			 rain_skylight *= mix(4.0, 2.0, smoothstep(-0.1, 0.5, sun_dir.y));

		 skylight  = mix(skylight, rain_skylight, rainStrength);
	}

	return skylight * (pow1d5(ao) * pi);
}
#endif

#endif // INCLUDE_LIGHT_COLORS_SKYLIGHT_APPROX
