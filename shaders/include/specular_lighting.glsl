#if !defined SPECULAR_LIGHTING_INCLUDED
#define SPECULAR_LIGHTING_INCLUDED

#include "raytracer.glsl"
#include "sky.glsl"
#include "sky_projection.glsl"
#include "utility/bicubic.glsl"
#include "utility/sampling.glsl"
#include "utility/space_conversion.glsl"

// ----------------------
//   Specular Highlight
// ----------------------

// GGX spherical area light approximation from Horizon: Zero Dawn
// https://www.guerrilla-games.com/read/decima-engine-advances-in-lighting-and-aa
float get_noh_squared(
	float nol,
	float nov,
	float lov,
	float light_radius
) {
	float radius_cos = cos(light_radius);
	float radius_tan = tan(light_radius);

	// Early out if R falls within the disc​
	float rol = 2.0 * nol * nov - lov;
	if (rol >= radius_cos) return 1.0;

	float r_over_length_t = radius_cos * radius_tan * inversesqrt(1.0 - rol * rol);
	float not_r = r_over_length_t * (nov - rol * nol);
	float vot_r = r_over_length_t * (2.0 * nov * nov - 1.0 - rol * lov);

	// Calculate dot(cross(N, L), V). This could already be calculated and available.​
	float triple = sqrt(clamp01(1.0 - nol * nol - nov * nov - lov * lov + 2.0 * nol * nov * lov));

	// Do one Newton iteration to improve the bent light Direction​
	float nob_r = r_over_length_t * triple, vob_r = r_over_length_t * (2.0 * triple * nov);
	float nol_vt_r = nol * radius_cos + nov + not_r, lov_vt_r = lov * radius_cos + 1.0 + vot_r;
	float p = nob_r * lov_vt_r, q = nol_vt_r * lov_vt_r, s = vob_r * nol_vt_r;
	float x_num = q * (-0.5 * p + 0.25 * vob_r * nol_vt_r);
	float x_denom = p * p + s * ((s - 2.0 * p)) + nol_vt_r * ((nol * radius_cos + nov) * lov_vt_r * lov_vt_r
		+ q * (-0.5 * (lov_vt_r + lov * radius_cos) - 0.5));
	float two_x_1 = 2.0 * x_num / (x_denom * x_denom + x_num * x_num);
	float sin_theta = two_x_1 * x_denom;
	float cos_theta = 1.0 - two_x_1 * x_num;
	not_r = cos_theta * not_r + sin_theta * nob_r; // use new T to update not_r​
	vot_r = cos_theta * vot_r + sin_theta * vob_r; // use new T to update vot_r​

	// Calculate (N.H)^2 based on the bent light direction​
	float new_nol = nol * radius_cos + not_r;
	float new_lov = lov * radius_cos + vot_r;
	float noh = nov + new_nol;
	float hoh = 2.0 * new_lov + 2.0;

	return clamp01(noh * noh / hoh);
}

vec3 get_specular_highlight(
	Material material,
	float nol,
	float nov,
	float noh,
	float lov,
	float loh
) {
	const float specular_max_value = 4.0; // Maximum value imposed on specular highlight to prevent it from overloading bloom

#if   defined WORLD_OVERWORLD
	float light_radius = (sunAngle < 0.5) ? sun_angular_radius : moon_angular_radius;
#endif

	vec3 fresnel;
	if (material.is_hardcoded_metal) {
		fresnel = fresnel_lazanyi_2019(loh, material.f0, material.f82);
	} else if (material.is_metal) {
		fresnel = fresnel_schlick(loh, material.albedo);
	} else {
		fresnel = fresnel_dielectric(loh, material.f0.x);
	}

	if (nol <= eps) return vec3(0.0);
	if (all(lessThan(fresnel, vec3(1e-2)))) return vec3(0.0);

	vec3 albedo_tint = mix(vec3(1.0), material.albedo, float(material.is_hardcoded_metal));

	float noh_squared = get_noh_squared(nol, nov, lov, light_radius);
	float alpha_squared = material.roughness * material.roughness;

	float d = distribution_ggx(noh_squared, alpha_squared);
	float v = v2_smith_ggx(max(nol, 1e-2), max(nov, 1e-2), alpha_squared);

	return min((nol * d * v) * fresnel * albedo_tint, vec3(specular_max_value));
}

// ------------------------
//   Specular Reflections
// ------------------------

#ifdef PROGRAM_COMPOSITE1
// from https://jcgt.org/published/0007/04/01/paper.pdf: "Sampling the GGX distribution of visible normals"
vec3 sample_ggx_vndf(vec3 viewer_dir, vec2 alpha, vec2 hash) {
	// Section 3.2: transforming the view direction to the hemisphere configuration
	viewer_dir = normalize(vec3(alpha * viewer_dir.xy, viewer_dir.z));

	// Section 4.1: orthonormal basis (with special case if cross product is zero)
	float len_sq = length_squared(viewer_dir.xy);
	vec3 T1 = (len_sq > 0) ? vec3(-viewer_dir.y, viewer_dir.x, 0) * inversesqrt(len_sq) : vec3(1.0, 0.0, 0.0);
	vec3 T2 = cross(viewer_dir, T1);

	// Section 4.2: parameterization of the projected area
	float r = sqrt(hash.x);
	float phi = 2.0 * pi * hash.y;
	float t1 = r * cos(phi);
	float t2 = r * sin(phi);
	float s = 0.5 + 0.5 * viewer_dir.z;

	t2 = (1.0 - s) * sqrt(1.0 - t1 * t1) + s * t2;

	// Section 4.3: reprojection onto hemisphere
	vec3 normal = t1 * T1 + t2 * T2 + sqrt(max0(1.0 - t1 * t1 - t2 * t2)) * viewer_dir;

	// Section 3.4: transforming the normal back to the ellipsoid configuration
	normal = normalize(vec3(alpha * normal.xy, max0(normal.z)));

	return normal;
}

vec3 get_sky_reflection(vec3 ray_dir, float skylight) {
#if defined WORLD_OVERWORLD
	return bicubic_filter(colortex4, project_sky(ray_dir)).rgb * pow12(skylight);
#endif
}

vec3 trace_specular_ray(
	vec3 screen_pos,
	vec3 view_pos,
	vec3 ray_dir,
	float dither,
	float skylight,
	uint intersection_step_count,
	uint refinement_step_count,
	int mip_level
) {
	vec3 view_dir = mat3(gbufferModelView) * ray_dir;

	vec3 hit_pos;
	bool hit = raymarch_depth_buffer(
		depthtex0,
		screen_pos,
		view_pos,
		view_dir,
		dither,
		intersection_step_count,
		refinement_step_count,
		hit_pos
	);

	vec3 sky_reflection = get_sky_reflection(ray_dir, skylight);

	if (hit) {
		float border_attenuation_factor = mix(0.01, eps, pow4(clamp01(1.0 - gbufferModelViewInverse[2].y)));
		float border_attenuation = (hit_pos.x * hit_pos.y - hit_pos.x) * (hit_pos.x * hit_pos.y - hit_pos.y);
		      border_attenuation = dampen(linear_step(0.0, border_attenuation_factor, border_attenuation));

		hit_pos = reproject(hit_pos);
		if (clamp01(hit_pos) != hit_pos) return sky_reflection;

		vec3 reflection = textureLod(colortex5, hit_pos.xy, mip_level).rgb;

		return mix(sky_reflection, reflection, border_attenuation);
	} else {
		return sky_reflection;
	}
}

vec3 get_specular_reflections(
	Material material,
	mat3 tbn_matrix,
	vec3 screen_pos,
	vec3 view_pos,
	vec3 normal,
	vec3 world_dir,
	vec3 tangent_dir,
	float skylight
) {
	vec3 albedo_tint = material.is_hardcoded_metal ? material.albedo : vec3(1.0);

	float alpha_squared = sqr(material.roughness);

	float dither = r1(frameCounter, texelFetch(noisetex, ivec2(gl_FragCoord.xy) & 511, 0).b);

/*
#if defined SSR_ROUGHNESS_SUPPORT
	vec2 hash = R2(
		SSR_RAY_COUNT * frameCounter,
		vec2(
			texelFetch(noisetex, ivec2(gl_FragCoord.xy)                     & 511, 0).b,
			texelFetch(noisetex, ivec2(gl_FragCoord.xy + vec2(239.0, 23.0)) & 511, 0).b
		)
	);

	if (material.roughness > 5e-2) { // Rough reflection
	 	float mip_level = sqrt(4.0 * dampen(material.roughness));

		vec3 reflection = vec3(0.0);

		for (int i = 0; i < SSR_RAY_COUNT; ++i) {
			vec3 microfacet_normal = tbn_matrix * sample_ggx_vndf(viewer_dir_tangent, vec2(material.roughness), hash);
			vec3 ray_dir = reflect(-viewer_dir, microfacet_normal);

			float NoL = dot(normal, ray_dir);
			if (NoL < eps) continue;

			vec3 radiance = trace_specular_ray(screen_pos, view_pos, ray_dir, dither, mip_level, skylight_falloff);

			NoL       = max(1e-2, NoL);
			float NoV = max(1e-2, dot(normal, viewer_dir));
			float MoV = clamp01(dot(microfacet_normal, viewer_dir));

			vec3 fresnel = material.is_metal ? fresnel_schlick(MoV, material.f0) : vec3(fresnel_dielectric(MoV, material.n));
			float v1 = v_1_smith_ggx(NoV, alpha_sq);
			float v2 = v_2_smith_ggx(NoL, NoV, alpha_sq);

			reflection += radiance * fresnel * (2.0 * NoL * v2 / v1);

			hash = R2Next(hash);
		}

		reflection *= albedo_tint * rcp(float(SSR_RAY_COUNT));
		if (any(isnan(reflection))) reflection = vec3(0.0); // don't reflect NaNs
		return reflection;
	}
#endif
*/

	// Mirror-like reflections

	vec3 ray_dir = reflect(world_dir, normal);

	float nol = dot(normal, ray_dir);
	float nov = clamp01(dot(normal, -world_dir));

	if (nol < eps) return vec3(0.0);

	vec3 fresnel;
	if (material.is_hardcoded_metal) {
		fresnel = fresnel_lazanyi_2019(nov, material.f0, material.f82);
	} else if (material.is_metal) {
		fresnel = fresnel_schlick(nov, material.albedo);
	} else {
		fresnel = fresnel_dielectric(nov, material.f0.x);
	}

	vec3 reflection  = trace_specular_ray(screen_pos, view_pos, ray_dir, dither, skylight, SSR_INTERSECTION_STEPS_SMOOTH, SSR_REFINEMENT_STEPS, 0);
	     reflection *= albedo_tint * fresnel;

	if (any(isnan(reflection))) reflection = vec3(0.0); // don't reflect NaNs

	return reflection;
}
#endif // PROGRAM_COMPOSITE1

#endif // SPECULAR_LIGHTING_INCLUDED
