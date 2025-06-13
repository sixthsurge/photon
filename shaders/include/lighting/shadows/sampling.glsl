#if !defined INCLUDE_LIGHTING_SHADOWS
#define INCLUDE_LIGHTING_SHADOWS

#if defined WORLD_OVERWORLD || defined WORLD_END

#include "/include/lighting/shadows/distortion.glsl"
#include "/include/utility/color.glsl"
#include "/include/utility/dithering.glsl"
#include "/include/utility/random.glsl"
#include "/include/utility/rotation.glsl"

#define SHADOW_PCF_STEPS_MIN           6 // [4 6 8 12 16 18 20 22 24 26 28 30 32]
#define SHADOW_PCF_STEPS_MAX          12 // [4 6 8 12 16 18 20 22 24 26 28 30 32]
#define SHADOW_PCF_STEPS_SCALE       1.0 // [0.0 0.2 0.4 0.6 0.8 1.0 1.2 1.4 1.6 1.8 2.0]
#define SHADOW_BLOCKER_SEARCH_RADIUS 0.5 // [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]

const int shadow_map_res = int(float(shadowMapResolution) * MC_SHADOW_QUALITY);
const float shadow_map_pixel_size = rcp(float(shadow_map_res));

// This kernel is progressive: any sample count will return an even spread of points
const vec2[32] blue_noise_disk = vec2[](
	vec2( 0.478712,  0.875764),
	vec2(-0.337956, -0.793959),
	vec2(-0.955259, -0.028164),
	vec2( 0.864527,  0.325689),
	vec2( 0.209342, -0.395657),
	vec2(-0.106779,  0.672585),
	vec2( 0.156213,  0.235113),
	vec2(-0.413644, -0.082856),
	vec2(-0.415667,  0.323909),
	vec2( 0.141896, -0.939980),
	vec2( 0.954932, -0.182516),
	vec2(-0.766184,  0.410799),
	vec2(-0.434912, -0.458845),
	vec2( 0.415242, -0.078724),
	vec2( 0.728335, -0.491777),
	vec2(-0.058086, -0.066401),
	vec2( 0.202990,  0.686837),
	vec2(-0.808362, -0.556402),
	vec2( 0.507386, -0.640839),
	vec2(-0.723494, -0.229240),
	vec2( 0.489740,  0.317826),
	vec2(-0.622663,  0.765301),
	vec2(-0.010640,  0.929347),
	vec2( 0.663146,  0.647618),
	vec2(-0.096674, -0.413835),
	vec2( 0.525945, -0.321063),
	vec2(-0.122533,  0.366019),
	vec2( 0.195235, -0.687983),
	vec2(-0.563203,  0.098748),
	vec2( 0.418563,  0.561335),
	vec2(-0.378595,  0.800367),
	vec2( 0.826922,  0.001024)
);

// Fake, lightmap-based shadows for outside of the shadow range or when shadows are disabled
float lightmap_shadows(float skylight, float NoL) {
	return smoothstep(13.5 / 15.0, 14.5 / 15.0, skylight);
}

#ifdef SHADOW
vec2 blocker_search(vec3 scene_pos, float dither, bool has_sss) {
	uint step_count = has_sss ? SSS_STEPS : 3;

	vec3 shadow_view_pos = transform(shadowModelView, scene_pos);
	vec3 shadow_clip_pos = project_ortho(shadowProjection, shadow_view_pos);
	float ref_z = shadow_clip_pos.z * (SHADOW_DEPTH_SCALE * 0.5) + 0.5;

	float radius = SHADOW_BLOCKER_SEARCH_RADIUS * shadowProjection[0].x * (0.5 + 0.5 * linear_step(0.2, 0.4, light_dir.y));
	mat2 rotate_and_scale = get_rotation_matrix(tau * dither) * radius;

	float depth_sum = 0.0;
	float weight_sum = 0.0;
	float depth_sum_sss = 0.0;

	for (uint i = 0; i < step_count; ++i) {
		vec2 uv  = shadow_clip_pos.xy + rotate_and_scale * blue_noise_disk[i];
		     uv /= get_distortion_factor(uv);
		     uv  = uv * 0.5 + 0.5;

		float depth  = texelFetch(shadowtex0, ivec2(uv * shadow_map_res), 0).x;
		float weight = step(depth, ref_z);

		depth_sum    += weight * depth;
		weight_sum   += weight;
		depth_sum_sss += max0(ref_z - depth);
	}

	float blocker_depth = weight_sum == 0.0 ? 0.0 : depth_sum / weight_sum;
	float sss_depth = -shadowProjectionInverse[2].z * depth_sum_sss * rcp(SHADOW_DEPTH_SCALE * float(step_count));

	return vec2(blocker_depth, sss_depth);
}

vec3 shadow_basic(vec3 shadow_screen_pos) {
	float shadow = texture(shadowtex1, shadow_screen_pos);

#ifdef SHADOW_COLOR
	ivec2 texel = ivec2(shadow_screen_pos.xy * shadow_map_res);

	float depth  = texelFetch(shadowtex0, texel, 0).x;
	vec3  color  = texelFetch(shadowcolor0, texel, 0).rgb * 4.0;
	float weight = step(depth, shadow_screen_pos.z) * step(eps, max_of(color));

	color = color * weight + (1.0 - weight);

	return shadow * color;
#else
	return vec3(shadow);
#endif
}

vec3 shadow_pcf(
	vec3 shadow_screen_pos,
	vec3 shadow_clip_pos,
#ifdef SHADOW_COLOR 
	vec3 shadow_screen_pos_translucent, 
	vec3 shadow_clip_pos_translucent, 
#endif
	float penumbra_size,
	float dither
) {
	// penumbra_size > max_filter_radius: blur
	// penumbra_size < min_filter_radius: anti-alias (blur then sharpen)
	float distortion_factor = get_distortion_factor(shadow_clip_pos.xy);
	float min_filter_radius = 2.0 * shadow_map_pixel_size * distortion_factor;

	float filter_radius = max(penumbra_size, min_filter_radius);
	float filter_scale = sqr(filter_radius / min_filter_radius);

	uint step_count = uint(SHADOW_PCF_STEPS_MIN + SHADOW_PCF_STEPS_SCALE * filter_scale);
	     step_count = min(step_count, SHADOW_PCF_STEPS_MAX);

	mat2 rotate_and_scale = get_rotation_matrix(tau * dither) * filter_radius;

	float shadow = 0.0;

	vec3 color_sum = vec3(0.0);
	float weight_sum = 0.0;

	// perform first 4 iterations and filter shadow color
	for (uint i = 0; i < 4; ++i) {
		vec2 offset = rotate_and_scale * blue_noise_disk[i];

		vec2 uv  = shadow_clip_pos.xy + offset;
		     uv /= get_distortion_factor(uv);
		     uv  = uv * 0.5 + 0.5;

		shadow += texture(shadowtex1, vec3(uv, shadow_screen_pos.z));

#ifdef SHADOW_COLOR
		// sample shadow color
		uv  = shadow_clip_pos_translucent.xy + offset;
		uv /= get_distortion_factor(uv);
		uv  = uv * 0.5 + 0.5;

		ivec2 texel = ivec2(uv * shadow_map_res);

		float depth = texelFetch(shadowtex0, texel, 0).x;

		vec3 color = texelFetch(shadowcolor0, texel, 0).rgb;
		     color = mix(vec3(1.0), 4.0 * color, step(depth, shadow_screen_pos_translucent.z));

		float weight = step(eps, max_of(color));

		color_sum += color * weight;
		weight_sum += weight;
#endif
	}

	vec3 color = weight_sum > 0.0 ? color_sum * rcp(weight_sum) : vec3(1.0);

	// exit early if outside shadow
	if (shadow > 4.0 - eps) return color;
	else if (shadow < eps) return vec3(0.0);

	// perform remaining iterations
	for (uint i = 4; i < step_count; ++i) {
		vec2 offset = rotate_and_scale * blue_noise_disk[i];

		vec2 uv  = shadow_clip_pos.xy + offset;
		     uv /= get_distortion_factor(uv);
		     uv  = uv * 0.5 + 0.5;

		shadow += texture(shadowtex1, vec3(uv, shadow_screen_pos.z));
	}

	float rcp_steps = rcp(float(step_count));

	// sharpening for small penumbra sizes
	float sharpening_threshold = 0.4 * max0((min_filter_radius - penumbra_size) / min_filter_radius);
	shadow = linear_step(sharpening_threshold, 1.0 - sharpening_threshold, shadow * rcp_steps);

	return shadow * color;
}

vec3 calculate_shadows(
	vec3 scene_pos,
	vec3 flat_normal,
	float skylight,
	float cloud_shadows,
	inout float sss_amount,
	out float distance_fade,
	out float sss_depth
) {
	sss_depth = 0.0;
	distance_fade = 0.0;

	float NoL = dot(flat_normal, light_dir);
	if (NoL < 1e-3 && sss_amount < 1e-3) return vec3(0.0);

	vec3 bias = get_shadow_bias(scene_pos, flat_normal, NoL, skylight);

	// Light leaking prevention from Complementary Reimagined, used with permission
	vec3 edge_factor = 0.1 - 0.2 * fract(scene_pos + cameraPosition + flat_normal * 0.01);
	edge_factor -= edge_factor * skylight;

#ifdef PIXELATED_SHADOWS
	// Snap position to the nearest block texel
	const float pixel_scale = float(PIXELATED_SHADOWS_RESOLUTION);
	scene_pos = scene_pos + cameraPosition;
	scene_pos = floor(scene_pos * pixel_scale + 0.01) * rcp(pixel_scale) + (0.5 / pixel_scale);
	scene_pos = scene_pos - cameraPosition;
#endif

	vec3 shadow_view_pos = transform(shadowModelView, scene_pos + bias + edge_factor);
	vec3 shadow_clip_pos = project_ortho(shadowProjection, shadow_view_pos);
	vec3 shadow_screen_pos = distort_shadow_space(shadow_clip_pos) * 0.5 + 0.5;

	distance_fade = pow32(
		max(
			max_of(abs(shadow_screen_pos.xy * 2.0 - 1.0)),
			mix(
				1.0, 0.55, 
				linear_step(0.33, 0.8, light_dir.y)
			) * length_squared(scene_pos.xz) * rcp(shadowDistance * shadowDistance)
		)
	);

	float distant_shadow = lightmap_shadows(skylight, NoL);
	if (distance_fade >= 1.0) return vec3(distant_shadow);

	float dither = interleaved_gradient_noise(gl_FragCoord.xy, frameCounter);

#ifdef SHADOW_VPS
	vec2 blocker_search_result = blocker_search(scene_pos, dither, sss_amount > eps);

	// SSS depth computed together with blocker depth
	sss_depth = mix(blocker_search_result.y, sss_depth, distance_fade);

	if (NoL < 1e-3) return vec3(0.0); // now we can exit early for SSS blocks
	if (blocker_search_result.x < eps) return vec3((1.0 - distance_fade) + distance_fade * distant_shadow); // blocker search empty handed => no occluders

	float penumbra_size  = 16.0 * SHADOW_PENUMBRA_SCALE * (shadow_screen_pos.z - blocker_search_result.x) / blocker_search_result.x;
	      penumbra_size *= 5.0 - 4.0 * cloud_shadows; // Increase penumbra radius inside cloud shadows, nice overcast look
	      penumbra_size  = min(penumbra_size, SHADOW_BLOCKER_SEARCH_RADIUS);
	      penumbra_size *= shadowProjection[0].x;
#else
	float penumbra_size = sqrt(0.5) * shadow_map_pixel_size * SHADOW_PENUMBRA_SCALE;

	// Increase blur radius to approximate subsurface scattering
	penumbra_size *= 1.0 + 7.0 * sss_amount;
#endif

#ifdef SHADOW_COLOR
	// Calculate position without light leaking fix applied, for colored shadow
	// Applying light leaking fix to translucent shadows causes artifacts on water caustics
	vec3 shadow_view_pos_translucent = transform(shadowModelView, scene_pos + bias);
	vec3 shadow_clip_pos_translucent = project_ortho(shadowProjection, shadow_view_pos_translucent);
	vec3 shadow_screen_pos_translucent = distort_shadow_space(shadow_clip_pos_translucent) * 0.5 + 0.5;
#endif

#ifdef SHADOW_PCF
	vec3 shadow = shadow_pcf(
		shadow_screen_pos, 
		shadow_clip_pos, 
	#ifdef SHADOW_COLOR 
		shadow_screen_pos_translucent,
		shadow_clip_pos_translucent,
	#endif
		penumbra_size, 
		dither
	);
#else
	vec3 shadow = shadow_basic(shadow_screen_pos);
#endif

	return mix(shadow, vec3(distant_shadow), clamp01(distance_fade));
}
#else
vec3 calculate_shadows(
	vec3 scene_pos,
	vec3 flat_normal,
	float skylight,
	float cloud_shadows,
	float sss_amount,
	out float distance_fade,
	out float sss_depth
) {
	distance_fade = 0.0;
	sss_depth = 0.0;
	return vec3(cloud_shadows);
}
#endif

#endif

#endif // INCLUDE_LIGHTING_SHADOWS
