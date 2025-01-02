#if !defined INCLUDE_LIGHTING_CLOUD_SHADOWS
#define INCLUDE_LIGHTING_CLOUD_SHADOWS

#include "/include/utility/bicubic.glsl"

const ivec2 cloud_shadow_res = ivec2(256);

#ifdef DISTANT_HORIZONS
#define cloud_shadow_extent float(dhRenderDistance)
#else
#define cloud_shadow_extent far
#endif

vec2 project_cloud_shadow_map(vec3 scene_pos) {
	vec2 cloud_shadow_pos  = transform(shadowModelView, scene_pos).xy / cloud_shadow_extent;
	     cloud_shadow_pos /= 1.0 + length(cloud_shadow_pos);
		 cloud_shadow_pos  = cloud_shadow_pos * 0.5 + 0.5;

	return cloud_shadow_pos;
}

vec3 unproject_cloud_shadow_map(vec2 cloud_shadow_pos) {
	cloud_shadow_pos  = cloud_shadow_pos * 2.0 - 1.0;
	cloud_shadow_pos /= 1.0 - length(cloud_shadow_pos);

	vec3 shadow_view_pos = vec3(cloud_shadow_pos * cloud_shadow_extent, 1.0);

	return transform(shadowModelViewInverse, shadow_view_pos);
}

float get_cloud_shadows(sampler2D cloud_shadow_map, vec3 scene_pos) {
#ifndef CLOUD_SHADOWS
	return 1.0;
#else
	vec2 cloud_shadow_pos = project_cloud_shadow_map(scene_pos) * vec2(cloud_shadow_res) / vec2(textureSize(cloud_shadow_map, 0));

	if (clamp01(cloud_shadow_pos) != cloud_shadow_pos) return 1.0;

	// fade out cloud shadows when:
	//  - the fragment is above the cloud layer
	//  - the sun is near the horizon
	float altitude_fraction = (scene_pos.y + eyeAltitude - SEA_LEVEL) * (CLOUDS_SCALE / CLOUDS_CUMULUS_THICKNESS) - CLOUDS_CUMULUS_ALTITUDE;
	float cloud_shadow_fade = smoothstep(0.1, 0.2, light_dir.y);

	float cloud_shadow = bicubic_filter(cloud_shadow_map, cloud_shadow_pos).x;
	      cloud_shadow = cloud_shadow * cloud_shadow_fade + (1.0 - cloud_shadow_fade);

	return cloud_shadow * CLOUD_SHADOWS_INTENSITY + (1.0 - CLOUD_SHADOWS_INTENSITY);
#endif
}

#if defined PROGRAM_PREPARE && defined CLOUD_SHADOWS
#include "/include/sky/clouds/altocumulus.glsl"
#include "/include/sky/clouds/cumulus.glsl"
#include "/include/sky/clouds/cumulus_congestus.glsl"
#include "/include/sky/clouds/cirrus.glsl"

float render_cloud_shadow_map(vec2 uv) {
	// Transform position from scene-space to clouds-space
	vec3 ray_origin = unproject_cloud_shadow_map(uv);
	     ray_origin = vec3(ray_origin.xz, ray_origin.y + eyeAltitude - SEA_LEVEL).xzy * CLOUDS_SCALE + vec3(0.0, planet_radius, 0.0);

	vec3 pos; float t, density, extinction_coeff;
	float shadow = 1.0;

#ifdef CLOUDS_CUMULUS
	float dynamic_thickness  = mix(
		0.5, 
		1.0, 
		smoothstep(0.4, 0.6, daily_weather_variation.clouds_cumulus_coverage.y)
	);
	vec2 detail_weights = mix(vec2(0.33, 0.40), vec2(0.25, 0.20), sqr(daily_weather_variation.clouds_stratus_amount)) * CLOUDS_CUMULUS_DETAIL_STRENGTH;
	vec2 edge_sharpening = mix(vec2(3.0, 8.0), vec2(1.0, 2.0), daily_weather_variation.clouds_stratus_amount);

	extinction_coeff = 0.25 * mix(0.05, 0.1, smoothstep(0.0, 0.3, abs(sun_dir.y))) * (1.0 - 0.33 * rainStrength) * CLOUDS_CUMULUS_DENSITY;
	t = intersect_sphere(ray_origin, light_dir,	clouds_cumulus_radius + 0.25 * clouds_cumulus_thickness).y;
	pos = ray_origin + light_dir * t;
	density = clouds_cumulus_density(pos, detail_weights, edge_sharpening, dynamic_thickness);
	shadow *= exp(-0.50 * extinction_coeff * clouds_cumulus_thickness * rcp(abs(light_dir.y) + eps) * density);
#endif

#ifdef CLOUDS_ALTOCUMULUS
	extinction_coeff = mix(0.05, 0.1, day_factor) * CLOUDS_ALTOCUMULUS_DENSITY * (1.0 - 0.33 * rainStrength);
	t = intersect_sphere(ray_origin, light_dir,	clouds_altocumulus_radius + 0.5 * clouds_altocumulus_thickness).y;
	pos = ray_origin + light_dir * t;
	density = clouds_altocumulus_density(pos);
	shadow *= exp(-0.50 * extinction_coeff * clouds_altocumulus_thickness * rcp(abs(light_dir.y) + eps) * density);
#endif

#ifdef CLOUDS_CIRRUS
	t = intersect_sphere(ray_origin, light_dir,	clouds_cirrus_radius).y;
	pos = ray_origin + light_dir * t;
	density = clouds_cirrus_density(pos.xz, 0.5);
	shadow *= exp(-0.25 * clouds_cirrus_extinction_coeff * clouds_cirrus_thickness * rcp(abs(light_dir.y) + eps) * density) * 0.5 + 0.5;
#endif

	return shadow;
}
#endif
#endif // INCLUDE_LIGHTING_CLOUD_SHADOWS
