#if !defined INCLUDE_LIGHTING_SHADOWS_SSRT_SHADOWS
#define INCLUDE_LIGHTING_SHADOWS_SSRT_SHADOWS

#include "/include/lighting/shadows/common.glsl"
#include "/include/utility/random.glsl"
#include "/include/utility/sampling.glsl"
#include "/include/utility/space_conversion.glsl"

bool raymarch_shadow(
    sampler2D depth_sampler,
    mat4 projection_matrix,
    mat4 projection_matrix_inverse,
    vec3 ray_origin_screen,
    vec3 ray_origin_view,
    vec3 ray_dir_view,
    bool has_sss,
    float dither,
    out float sss_depth
) {
    const uint step_count = uint(SHADOW_SSRT_STEPS);
    const float step_ratio = 2.0; // geometric sample distribution
    const float z_tolerance = 10.0; // assumed thickness in blocks

    vec3 ray_dir_screen = normalize(
        view_to_screen_space(
            projection_matrix,
            ray_origin_view + ray_dir_view,
            true
        ) -
        ray_origin_screen
    );

    float ray_length = min_of(
        abs(sign(ray_dir_screen) - ray_origin_screen) /
        max(abs(ray_dir_screen), eps)
    );
    ray_length =
        min(ray_length,
            max(0.1, exp(-max0(length(ray_origin_view) * 0.025 - 1.0))));

    const float initial_step_scale = step_ratio == 1.0
        ? rcp(float(step_count))
        : (step_ratio - 1.0) / (pow(step_ratio, float(step_count)) - 1.0);
    float step_length = ray_length * initial_step_scale;

    vec3 ray_pos = ray_origin_screen + length(view_pixel_size) * ray_dir_screen;

    bool hit = false;
    bool hit_after_sss = false;
    bool sss_raymarch = has_sss;
    vec3 exit_pos = ray_origin_view;

    for (int i = 0; i < step_count; ++i) {
        step_length *= step_ratio;
        vec3 ray_step = ray_dir_screen * step_length;
        vec3 dithered_pos = ray_pos + dither * ray_step;
        ray_pos += ray_step;

#ifdef LOD_MOD_ACTIVE
        if (dithered_pos.z < 0.0) {
            continue;
        }
#endif
        if (clamp01(dithered_pos) != dithered_pos) {
            break;
        }

        float depth = texelFetch(
                          depth_sampler,
                          ivec2(dithered_pos.xy * view_res * taau_render_scale),
                          0
        )
                          .x;

        float z_ray = screen_to_view_space_depth(
            projection_matrix_inverse,
            dithered_pos.z
        );
        float z_sample =
            screen_to_view_space_depth(projection_matrix_inverse, depth);

        bool inside = depth != 0.0 && depth < dithered_pos.z &&
            abs(z_tolerance - (z_ray - z_sample)) < z_tolerance;
        hit = inside || hit;

        if (sss_raymarch) {
            if (!inside) {
                exit_pos = dithered_pos;
                sss_raymarch = false;
            }
        }

        else if (!sss_raymarch) {
            hit_after_sss = inside || hit_after_sss;
            if (hit) {
                break;
            }
        }
    }

    exit_pos = screen_to_view_space(projection_matrix_inverse, exit_pos, true);
    sss_depth =
        hit_after_sss ? -1.0 : max0(distance(ray_origin_view, exit_pos) * 0.2);

    return hit;
}

float get_screen_space_shadows(
    vec2 position_screen_xy,
    vec3 position_view,
    float depth,
#ifdef LOD_MOD_ACTIVE
    float depth_lod,
#endif
    float skylight,
    bool has_sss,
    inout float sss_depth
) {
    // Dithering for ray offset
    float dither = texelFetch(noisetex, ivec2(gl_FragCoord.xy) & 511, 0).b;
    dither = r1(frameCounter, dither);

    // Slightly randomise ray direction to create soft shadows
    vec2 hash = hash2(gl_FragCoord.xy);
    vec3 ray_dir =
        normalize(view_light_dir + 0.03 * uniform_sphere_sample(hash));

#ifdef LOD_MOD_ACTIVE
    // Which depth map to raymarch depends on distance
    // Closer fragments: use combined depth texture (so MC terrain can cast)
    // Further fragments: use LoD depth texture (maximise precision)

    bool raymarch_combined_depth = length_squared(position_view) <
        sqr(far + 64.0); // heuristic of 4 chunks overlap
    bool hit;

    /*
    #ifdef MC_GL_KHR_shader_subgroup
    // Using subgroup ops, we make sure that if any fragments in a warp are
    raymarching the
    // combined depth buffer, they all do, to avoid divergent branches.
    raymarch_combined_depth = subgroupAny(raymarch_combined_depth);
    #endif
    */

    if (raymarch_combined_depth) {
        hit = raymarch_shadow(
            combined_depth_tex,
            combined_projection_matrix,
            combined_projection_matrix_inverse,
            vec3(position_screen_xy, depth),
            position_view,
            ray_dir,
            has_sss,
            dither,
            sss_depth
        );
    } else {
        hit = raymarch_shadow(
            lod_depth_tex,
            lod_projection_matrix,
            lod_projection_matrix_inverse,
            vec3(position_screen_xy, depth_lod),
            position_view,
            ray_dir,
            has_sss,
            dither,
            sss_depth
        );
    }
#else
    bool hit = raymarch_shadow(
        depthtex1,
        gbufferProjection,
        gbufferProjectionInverse,
        vec3(position_screen_xy, depth),
        position_view,
        view_light_dir,
        has_sss,
        dither,
        sss_depth
    );
#endif

    return float(!hit) * get_lightmap_light_leak_prevention(skylight);
}

#endif // INCLUDE_LIGHTING_SHADOWS_SSRT_SHADOWS
