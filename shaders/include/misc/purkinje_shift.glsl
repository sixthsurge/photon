#if !defined INCLUDE_MISC_PURKINJE_SHIFT
#define INCLUDE_MISC_PURKINJE_SHIFT

// http://www.diva-portal.org/smash/get/diva2:24136/FULLTEXT01.pdf
vec3 purkinje_shift(vec3 rgb, vec2 light_levels) {
#if !(defined PURKINJE_SHIFT && defined WORLD_OVERWORLD)
	return rgb;
#else
	float purkinje_intensity  = 0.05 * PURKINJE_SHIFT_INTENSITY;
	      purkinje_intensity  = purkinje_intensity - purkinje_intensity * smoothstep(-0.12, -0.06, sun_dir.y) * light_levels.y; // No purkinje shift in daylight
	      purkinje_intensity *= clamp01(1.0 - light_levels.x); // Reduce purkinje intensity in blocklight
	      purkinje_intensity *= clamp01(0.3 + 0.7 * cube(max(light_levels.y, eye_skylight))); // Reduce purkinje intensity underground

	if (purkinje_intensity < eps) return rgb;

	const vec3 purkinje_tint = vec3(0.5, 0.7, 1.0) * rec709_to_rec2020;
	const vec3 rod_response = vec3(7.15e-5, 4.81e-1, 3.28e-1) * rec709_to_rec2020;

	vec3 xyz = rgb * rec2020_to_xyz;

	vec3 scotopic_luminance = xyz * (1.33 * (1.0 + (xyz.y + xyz.z) / xyz.x) - 1.68);

	float purkinje = dot(rod_response, scotopic_luminance * xyz_to_rec2020);

	rgb = mix(rgb, purkinje * purkinje_tint, exp2(-rcp(purkinje_intensity) * purkinje));

	return max0(rgb);
#endif
}

#endif // INCLUDE_MISC_PURKINJE_SHIFT
