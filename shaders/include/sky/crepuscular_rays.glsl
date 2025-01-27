#if !defined INCLUDE_SKY_CREPUSCULAR_RAYS
#define INCLUDE_SKY_CREPUSCULAR_RAYS

#include "/include/lighting/cloud_shadows.glsl"

vec4 draw_crepuscular_rays(
	sampler2D cloud_shadow_map,
	vec3 ray_direction_world, 
	float dither
) {
	if (ray_direction_world.y < 0.0) {
		return vec4(0.0, 0.0, 0.0, 1.0);
	}
	const uint step_count = 16u;
	const float max_ray_length = 4096.0;

	const float clouds_cumulus_radius    = planet_radius + CLOUDS_CUMULUS_ALTITUDE;
	const float clouds_cumulus_thickness = CLOUDS_CUMULUS_ALTITUDE * CLOUDS_CUMULUS_THICKNESS;
	vec3 ray_origin_air = vec3(vec2(0.0), eyeAltitude - SEA_LEVEL).xzy * CLOUDS_SCALE + vec3(0.0, planet_radius, 0.0);
	float ray_length = intersect_sphere(ray_origin_air, ray_direction_world, clouds_cumulus_radius + 0.25 * clouds_cumulus_thickness).y / CLOUDS_SCALE;
	ray_length = min(ray_length, max_ray_length);
	float step_length = ray_length * rcp(float(step_count));

	vec3 ray_origin_shadow = shadowModelView[3].xyz;
	vec3 ray_direction_shadow = mat3(shadowModelView) * ray_direction_world;
	vec3 ray_step_shadow = ray_direction_shadow * step_length;
	float sunset_factor = pulse(light_dir.y, -0.01, 0.1);

	float density_scale = 5.0 + 40.0 * daily_weather_variation.fogginess;
	vec3 extinction_coeff = density_scale * (air_rayleigh_coefficient + 1.0 * air_mie_coefficient);
	vec3 scattering_coeff = extinction_coeff;
	vec3 step_optical_depth = extinction_coeff * step_length;
	vec3 step_transmittance = exp(-step_optical_depth);
	vec3 step_transmitted_fraction = (1.0 - step_transmittance) / max(step_optical_depth, eps);

	vec3 scattering = vec3(0.0);
	vec3 transmittance = vec3(1.0);

	vec3 light_color  = sunlight_color * atmosphere_transmittance(light_dir.y, planet_radius);
	light_color = atmosphere_post_processing(light_color);
	light_color *= sunAngle > 0.5 ? moon_color : sun_color;

	for (uint i = 0u; i < step_count; ++i) {
		vec3 ray_position_shadow = ray_origin_shadow + ray_step_shadow * (float(i) + dither);
		vec2 cloud_shadow_uv = shadow_view_to_cloud_shadow_space(ray_position_shadow);

		float cloud_shadow = texelFetch(cloud_shadow_map, ivec2(cloud_shadow_uv * vec2(cloud_shadow_res)), 0).x;
		//float cloud_shadow = texture(cloud_shadow_map, cloud_shadow_uv).x;
		      cloud_shadow = linear_step(0.8, 1.0, cloud_shadow);

		vec3 visible_scattering = step_transmitted_fraction * transmittance;

		scattering += visible_scattering * step_length * light_color * scattering_coeff * cloud_shadow;

		transmittance *= step_transmittance;
	}

	float LoV = dot(ray_direction_world, light_dir);

	float forwards_a = sunset_factor * klein_nishina_phase(LoV, 2600.0); // this gives a nice glow very close to the sun
	float forwards_b = henyey_greenstein_phase(LoV, 0.5); 

	float phase = 0.8 * max(forwards_a, forwards_b) // forwards lobe (max'ing them is completely nonsensical but it looks nice)
		+ 0.2 * henyey_greenstein_phase(LoV, -0.2); // backwards lobe

	scattering *= 2.0 * phase;
	float horizon_fade = clamp01(40.0 * ray_direction_world.y);
	scattering *= horizon_fade;
	transmittance = mix(vec3(1.0), transmittance, horizon_fade);

	return vec4(scattering, dot(transmittance, vec3(rcp(3.0))));
}

#endif // INCLUDE_SKY_CREPUSCULAR_RAYS
