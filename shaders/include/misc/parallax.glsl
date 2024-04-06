#if !defined INCLUDE_MISC_PARALLAX
#define INCLUDE_MISC_PARALLAX

vec2 get_uv_from_local_coord(vec2 local_coord) {
	return atlas_tile_offset + atlas_tile_scale * fract(local_coord);
}

vec2 get_local_coord_from_uv(vec2 uv) {
	return (uv - atlas_tile_offset) * rcp(atlas_tile_scale);
}

float get_height_value(vec2 local_coord, mat2 uv_gradient) {
	vec2 uv = get_uv_from_local_coord(local_coord);
	return textureGrad(normals, uv, uv_gradient[0], uv_gradient[1]).w;
}

float get_depth_value(vec2 local_coord, mat2 uv_gradient) {
	return 1.0 - get_height_value(local_coord, uv_gradient);
}

vec2 get_parallax_uv(
	vec3 tangent_dir,
	mat2 uv_gradient,
	float view_distance,
	float dither,
	out vec3 previous_ray_pos,
	out float pom_depth
) {
	const float depth_step = rcp(float(POM_SAMPLES));

	// Perform one POM step at the original position, fixes POM tiling
	// Thanks to Null for teaching me this
	float depth_value = get_depth_value(atlas_tile_coord, uv_gradient);
	if (depth_value < rcp(255.0)) {
		previous_ray_pos = vec3(atlas_tile_coord, 0.0);
		pom_depth = 0.0;
		return uv;
	}

	float parallax_fade = linear_step(0.75 * POM_DISTANCE, POM_DISTANCE, view_distance);

	vec3 ray_step = vec3(tangent_dir.xy * rcp(-tangent_dir.z) * POM_DEPTH * (1.0 - parallax_fade), 1.0) * depth_step;
	vec3 pos = vec3(atlas_tile_coord + ray_step.xy * dither, 0.0);

	while (depth_value - pos.z >= rcp(255.0)) {
		previous_ray_pos = vec3(pos);
		depth_value = get_depth_value(pos.xy, uv_gradient);
		pos += ray_step;
	}

	pom_depth = depth_value;

	return get_uv_from_local_coord(pos.xy);
}

bool get_parallax_shadow(vec3 pos, mat2 uv_gradient, float view_distance, float dither) {
	float parallax_fade = linear_step(0.75 * POM_DISTANCE, POM_DISTANCE, view_distance);

	vec3 tangent_dir = light_dir * tbn;
	vec3 ray_step = vec3(tangent_dir.xy * rcp(tangent_dir.z) * POM_DEPTH * (1.0 - parallax_fade), -1.0) * pos.z * rcp(float(POM_SHADOW_SAMPLES));

	pos.xy += ray_step.xy * dither;

	for (int i = 0; i < POM_SHADOW_SAMPLES; ++i) {
		pos += ray_step;
		if (get_depth_value(pos.xy, uv_gradient) < pos.z) return true;
	}

	return false;
}

#endif // INCLUDE_MISC_PARALLAX
