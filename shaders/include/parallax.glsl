#if !defined PARALLAX_INCLUDED
#define PARALLAX_INCLUDED

#ifdef POM
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

	float parallax_fade = linear_step(0.75 * POM_DISTANCE, POM_DISTANCE, view_distance);

	vec3 ray_step = vec3(tangent_dir.xy * rcp(-tangent_dir.z) * POM_DEPTH * (1.0 - parallax_fade), 1.0) * depth_step;
	vec3 pos = vec3(atlas_tile_coord + ray_step.xy * dither, 0.0);

	float depth_value = 1.0;

	while (depth_value - pos.z >= rcp(255.0)) {
		previous_ray_pos = vec3(pos);
		depth_value = get_depth_value(pos.xy, uv_gradient);
		pos += ray_step;
	}

	pom_depth = depth_value;

	return get_uv_from_local_coord(pos.xy);
}

bool get_parallax_shadow(vec3 pos, mat2 uv_gradient, float view_distance, float dither) {
	vec3 tangent_dir = light_dir * tbn;
	vec3 ray_step = vec3(tangent_dir.xy * rcp(tangent_dir.z) * POM_DEPTH, -1.0) * pos.z * rcp(float(POM_SHADOW_SAMPLES));

	pos.xy += ray_step.xy * dither;

	for (int i = 0; i < POM_SHADOW_SAMPLES; ++i) {
		pos += ray_step;
		if (get_depth_value(pos.xy, uv_gradient) < pos.z) return true;
	}

	return false;
}

// POM slope normals from Arc Shader by Null
// https://github.com/Null-MC/Arc-Shader
vec3 get_parallax_slope_normal(vec3 tangent_dir, vec2 parallax_uv, float pom_depth, mat2 uv_gradient) {
	vec2 atlas_pixel_size = rcp(vec2(atlasSize));
	float atlas_aspect_ratio = float(atlasSize.x) / float(atlasSize.y);

	vec2 tex_snapped = floor(parallax_uv * atlasSize) * atlas_pixel_size;
	vec2 tex_offset = parallax_uv - (tex_snapped + 0.5 * atlas_pixel_size);

	vec2 step_sign = sign(tex_offset);
	vec2 view_sign = sign(tangent_dir.xy);

	bool dir = abs(parallax_uv.x * atlas_aspect_ratio) < abs(tex_offset.y);
	vec2 tex_x, tex_y;

	if (dir) {
		tex_x = vec2(-view_sign.x, 0.0);
		tex_y = vec2(0.0, step_sign.y);
	} else {
		tex_x = vec2(step_sign.x, 0.0);
		tex_y = vec2(0.0, -view_sign.y);
	}

	vec2 t_x = get_local_coord_from_uv(parallax_uv + tex_x * atlas_pixel_size);
	     t_x = get_uv_from_local_coord(t_x);

	vec2 t_y = get_local_coord_from_uv(parallax_uv + tex_y * atlas_pixel_size);
	     t_y = get_uv_from_local_coord(t_x);

	float height_x = textureGrad(normals, t_x, uv_gradient[0], uv_gradient[1]).a;
	float height_y = textureGrad(normals, t_y, uv_gradient[0], uv_gradient[1]).a;

	if (dir) {
		if (!(pom_depth > height_y && view_sign.y != step_sign.y)) {
			if (pom_depth > height_x) return vec3(-view_sign.x, 0.0, 0.0);

			if (abs(tangent_dir.y) > abs(tangent_dir.x))
				return vec3(0.0, -view_sign.y, 0.0);
			else
				return vec3(-view_sign.x, 0.0, 0.0);
		}

		return vec3(0.0, -view_sign.y, 0.0);
	} else {
		if (!(pom_depth > height_x && view_sign.x != step_sign.x)) {
			if (pom_depth > height_y) return vec3(0.0, -view_sign.y, 0.0);

			if (abs(tangent_dir.y) > abs(tangent_dir.x))
				return vec3(0.0, -view_sign.y, 0.0);
			else
				return vec3(-view_sign.x, 0.0, 0.0);
		}

		return vec3(-view_sign.x, 0.0, 0.0);
	}
}
#endif

#endif // PARALLAX_INCLUDED
