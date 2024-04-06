#if !defined INCLUDE_LIGHT_CLOUD_SHADOWS
#define INCLUDE_LIGHT_CLOUD_SHADOWS

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
#endif // INCLUDE_LIGHT_CLOUD_SHADOWS
