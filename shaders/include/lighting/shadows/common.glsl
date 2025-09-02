#if !defined INCLUDE_LIGHTING_SHADOWS_COMMON
#define INCLUDE_LIGHTING_SHADOWS_COMMON

// Fade from close shadows (shadow maps) to distant shadows (lightmap or SSRT)
float get_shadow_distance_fade(vec3 scene_pos, vec3 shadow_screen_pos) {
	float effective_shadow_distance = min(shadowDistance, far);
	return linear_step(
		0.1,
		1.0,
		pow32(
			max(
				max_of(abs(shadow_screen_pos.xy * 2.0 - 1.0)),
				length_squared(scene_pos.xz) * rcp(sqr(effective_shadow_distance)) 
			)
		)
	);
}

// Fake, lightmap-based shadows for outside of the shadow range or when shadows are disabled
float get_lightmap_shadows(float skylight) {
	return smoothstep(13.5 / 15.0, 14.5 / 15.0, skylight);
}

// Prevents light leaking in caves by cancelling out sunlight in very low skylight
float get_lightmap_light_leak_prevention(float skylight) {
	return smoothstep(0.0 / 15.0, 2.0 / 15.0, skylight);
}

#endif
