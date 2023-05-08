#if !defined INCLUDE_SKY_SKY
#define INCLUDE_SKY_SKY

//----------------------------------------------------------------------------//
#if   defined WORLD_OVERWORLD

#include "/include/light/colors/light_color.glsl"
#include "/include/light/colors/weather_color.glsl"
#include "/include/light/bsdf.glsl"
#include "/include/sky/atmosphere.glsl"
#include "/include/sky/projection.glsl"
#include "/include/utility/dithering.glsl"
#include "/include/utility/fast_math.glsl"
#include "/include/utility/geometry.glsl"
#include "/include/utility/random.glsl"

const float sun_luminance  = 40.0; // luminance of sun disk
const float moon_luminance = 4.0; // luminance of moon disk

vec3 draw_sun(vec3 ray_dir) {
	float nu = dot(ray_dir, sun_dir);

	// Limb darkening model from http://www.physics.hmc.edu/faculty/esin/a101/limbdarkening.pdf
	const vec3 alpha = vec3(0.429, 0.522, 0.614);
	float center_to_edge = max0(sun_angular_radius - fast_acos(nu));
	vec3 limb_darkening = pow(vec3(1.0 - sqr(1.0 - center_to_edge)), 0.5 * alpha);

	return sun_luminance * sun_color * step(0.0, center_to_edge) * limb_darkening;
}

// Stars based on https://www.shadertoy.com/view/Md2SR3

vec3 unstable_star_field(vec2 coord, float star_threshold) {
	const float min_temp = 3500.0;
	const float max_temp = 9500.0;

	vec4 noise = hash4(coord);

	float star = linear_step(star_threshold, 1.0, noise.x);
	      star = pow4(star) * STARS_INTENSITY;

	float temp = mix(min_temp, max_temp, noise.y);
	vec3 color = blackbody(temp);

	const float twinkle_speed = 2.0;
	float twinkle_amount = noise.z;
	float twinkle_offset = tau * noise.w;
	star *= 1.0 - twinkle_amount * cos(frameTimeCounter * twinkle_speed + twinkle_offset);

	return star * color;
}

// Stabilizes the star field by sampling at the four neighboring integer coordinates and
// interpolating
vec3 stable_star_field(vec2 coord, float star_threshold) {
	coord = abs(coord) + 33.3 * step(0.0, coord);
	vec2 i, f = modf(coord, i);

	f.x = cubic_smooth(f.x);
	f.y = cubic_smooth(f.y);

	return unstable_star_field(i + vec2(0.0, 0.0), star_threshold) * (1.0 - f.x) * (1.0 - f.y)
	     + unstable_star_field(i + vec2(1.0, 0.0), star_threshold) * f.x * (1.0 - f.y)
	     + unstable_star_field(i + vec2(0.0, 1.0), star_threshold) * f.y * (1.0 - f.x)
	     + unstable_star_field(i + vec2(1.0, 1.0), star_threshold) * f.x * f.y;
}

vec3 draw_stars(vec3 ray_dir) {
#ifdef SHADOW
	// Trick to make stars rotate with sun and moon
	mat3 rot = (sunAngle < 0.5)
		? mat3(shadowModelViewInverse)
		: mat3(-shadowModelViewInverse[0].xyz, shadowModelViewInverse[1].xyz, -shadowModelViewInverse[2].xyz);

	ray_dir *= rot;
#endif

	// Adjust star threshold so that brightest stars appear first
	float star_threshold = 1.0 - 0.008 * STARS_COVERAGE * smoothstep(-0.2, 0.05, -sun_dir.y);

	// Project ray direction onto the plane
	vec2 coord  = ray_dir.xy * rcp(abs(ray_dir.z) + length(ray_dir.xy)) + 41.21 * sign(ray_dir.z);
	     coord *= 600.0;

	return stable_star_field(coord, star_threshold);
}

vec4 get_clouds(vec3 ray_dir, vec3 clear_sky) {
#if   defined PROGRAM_DEFERRED0
	ivec2 texel   = ivec2(gl_FragCoord.xy);
	      texel.x = texel.x % (sky_map_res.x - 4);

	float dither = interleaved_gradient_noise(vec2(texel));

	return draw_clouds(ray_dir, clear_sky, dither);
#elif defined PROGRAM_DEFERRED3
	// Soften clouds for new pixels
	float pixel_age = texelFetch(colortex6, ivec2(gl_FragCoord.xy), 0).w;
	int ld = int(3.0 * dampen(max0(1.0 - 0.1 * pixel_age)));

	return bicubic_filter_lod(colortex7, uv * taau_render_scale, ld);
#else
	return vec4(0.0, 0.0, 0.0, 1.0);
#endif
}

vec3 draw_sky(vec3 ray_dir, vec3 atmosphere) {
	vec3 sky = vec3(0.0);

	// Sun, moon and stars

#if defined PROGRAM_DEFERRED3
	vec4 vanilla_sky = texelFetch(colortex3, ivec2(gl_FragCoord.xy), 0);
	vec3 vanilla_sky_color = from_srgb(vanilla_sky.rgb);
	uint vanilla_sky_id = uint(255.0 * vanilla_sky.a);

#ifdef STARS
	sky += draw_stars(ray_dir);
#endif

#ifdef VANILLA_SUN
	if (vanilla_sky_id == 2) {
		const vec3 brightness_scale = sunlight_color * sun_luminance;
		sky += vanilla_sky_color * brightness_scale * sun_color;
	}
#else
	sky += draw_sun(ray_dir);
#endif

	if (vanilla_sky_id == 3) {
		const vec3 brightness_scale = sunlight_color * moon_luminance;
		sky *= 0.0; // Hide stars behind moon
		sky += vanilla_sky_color * brightness_scale;
	}

#ifdef CUSTOM_SKY
	if (vanilla_sky_id == 4) {
		sky += vanilla_sky_color * CUSTOM_SKY_BRIGHTNESS;
	}
#endif
#endif

	// Sky gradient

	sky *= atmosphere_transmittance(ray_dir.y, planet_radius) * (1.0 - rainStrength);
	sky += atmosphere;

	// Rain
	vec3 rain_sky = get_weather_color() * (1.0 - exp2(-0.8 / clamp01(ray_dir.y)));
	sky = mix(sky, rain_sky, rainStrength * mix(1.0, 0.9, time_sunrise + time_sunset));

	// Clouds

#ifndef BLOCKY_CLOUDS
	vec4 clouds = get_clouds(ray_dir, sky);
	sky *= clouds.a;   // transmittance
	sky += clouds.rgb; // scattering
#endif

	// Fade lower part of sky into cave fog color when underground so that the sky isn't visible
	// beyond the render distance
	float underground_sky_fade = biome_cave * smoothstep(-0.1, 0.1, 0.4 - ray_dir.y);
	sky = mix(sky, vec3(0.0), underground_sky_fade);

	return sky;
}

vec3 draw_sky(vec3 ray_dir) {
	vec3 atmosphere = atmosphere_scattering(ray_dir, sun_color, sun_dir, moon_color, moon_dir);
	return draw_sky(ray_dir, atmosphere);
}

//----------------------------------------------------------------------------//
#elif defined WORLD_NETHER

vec3 draw_sky(vec3 ray_dir) {
	return ambient_color;
}

//----------------------------------------------------------------------------//
#elif defined WORLD_END

#endif

#endif // INCLUDE_SKY_SKY
