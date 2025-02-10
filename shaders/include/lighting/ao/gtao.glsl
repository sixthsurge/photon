#if !defined INCLUDE_LIGHTING_AO_GTAO
#define INCLUDE_LIGHTING_AO_GTAO

#include "/include/misc/distant_horizons.glsl"
#include "/include/utility/fast_math.glsl" 
#include "/include/utility/space_conversion.glsl"

#define GTAO_FALLOFF_START 0.75

float integrate_arc(vec2 h, float n, float cos_n) {
	vec2 tmp = cos_n + 2.0 * h * sin(n) - cos(2.0 * h - n);
	return 0.25 * (tmp.x + tmp.y);
}

float compute_maximum_horizon_angle(
	vec3 view_slice_dir,
	vec3 viewer_dir,
	vec3 screen_pos,
	vec3 view_pos,
	float radius,
	float dither,
    bool is_dh_terrain
) {
	float step_size = (GTAO_RADIUS * rcp(float(GTAO_HORIZON_STEPS))) * radius;

	float max_cos_theta = -1.0;

	vec2 ray_step = (view_to_screen_space(view_pos + view_slice_dir * step_size, true, is_dh_terrain) - screen_pos).xy;
	vec2 ray_pos = screen_pos.xy + ray_step * (dither + max_of(view_pixel_size) * rcp_length(ray_step));

	for (int i = 0; i < GTAO_HORIZON_STEPS; ++i, ray_pos += ray_step) {
        ivec2 texel = ivec2(clamp01(ray_pos) * view_res * taau_render_scale - 0.5);
		float depth = texelFetch(combined_depth_buffer, texel, 0).x;

		if (depth == 1.0 || depth < hand_depth || depth == screen_pos.z) continue;

		vec3 offset = screen_to_view_space(combined_projection_matrix_inverse, vec3(ray_pos, depth), true) - view_pos;

		float len_sq = length_squared(offset);
		float norm = inversesqrt(len_sq);

		float distance_falloff = linear_step(GTAO_FALLOFF_START * GTAO_RADIUS, GTAO_RADIUS, len_sq * norm * rcp(radius));

		float cos_theta = dot(viewer_dir, offset) * norm;
		      cos_theta = mix(cos_theta, -1.0, distance_falloff);

		max_cos_theta = max(cos_theta, max_cos_theta);
	}

	return fast_acos(clamp(max_cos_theta, -1.0, 1.0));
}

vec2 compute_gtao(
	vec3 screen_pos, 
	vec3 view_pos, 
	vec3 view_normal, 
	vec2 dither, 
	bool is_dh_terrain, 
	out vec3 bent_normal
) {
	float ao = 0.0;
	float ambient_sss = 0.0;
	bent_normal = vec3(0.0);

	// Construct local working space
	vec3 viewer_dir   = normalize(-view_pos);
	vec3 viewer_right = normalize(cross(vec3(0.0, 1.0, 0.0), viewer_dir));
	vec3 viewer_up    = cross(viewer_dir, viewer_right);
	mat3 local_to_view = mat3(viewer_right, viewer_up, viewer_dir);

	// Reduce AO radius very close up, makes some screen-space artifacts less obvious
	float ao_radius = max(0.25 + 0.75 * smoothstep(0.0, 81.0, length_squared(view_pos)), 0.5);

    // Increase AO radius for DH terrain (looks nice)
#ifdef DISTANT_HORIZONS
    if (is_dh_terrain) {
        ao_radius *= 3.0;
    }
#endif

	for (int i = 0; i < GTAO_SLICES; ++i) {
		float slice_angle = (i + dither.x) * (pi / float(GTAO_SLICES));

		vec3 slice_dir = vec3(cos(slice_angle), sin(slice_angle), 0.0);
		vec3 view_slice_dir = local_to_view * slice_dir;

		vec3 ortho_dir = slice_dir - dot(slice_dir, viewer_dir) * viewer_dir;
		vec3 axis = cross(slice_dir, viewer_dir);
		vec3 projected_normal = view_normal - axis * dot(view_normal, axis);

		float len_sq = dot(projected_normal, projected_normal);
		float norm = inversesqrt(len_sq);

		float sgn_gamma = sign(dot(ortho_dir, projected_normal));
		float cos_gamma = clamp01(dot(projected_normal, viewer_dir) * norm);
		float gamma = sgn_gamma * fast_acos(cos_gamma);

		vec2 max_horizon_angles;
		max_horizon_angles.x = compute_maximum_horizon_angle(-view_slice_dir, viewer_dir, screen_pos, view_pos, ao_radius, dither.y, is_dh_terrain);
		max_horizon_angles.y = compute_maximum_horizon_angle( view_slice_dir, viewer_dir, screen_pos, view_pos, ao_radius, dither.y, is_dh_terrain);

		ambient_sss += max0(max_horizon_angles.y - half_pi) * rcp_pi;

		max_horizon_angles = gamma + clamp(vec2(-1.0, 1.0) * max_horizon_angles - gamma, -half_pi, half_pi);
		ao += integrate_arc(max_horizon_angles, gamma, cos_gamma) * len_sq * norm;

		float bent_angle = dot(max_horizon_angles, vec2(0.5));
		bent_normal += viewer_dir * cos(bent_angle) + ortho_dir * sin(bent_angle);
	}

	const float albedo = 0.2; // albedo of surroundings (for multibounce approx)

	ao *= rcp(float(GTAO_SLICES));
	ambient_sss *= rcp(float(GTAO_SLICES));
	ao /= albedo * ao + (1.0 - albedo);

	bent_normal = normalize(normalize(bent_normal) - 0.5 * viewer_dir);

	return clamp01(vec2(ao, ambient_sss));
}

#endif // INCLUDE_LIGHTING_AO_GTAO
