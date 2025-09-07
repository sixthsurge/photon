#if !defined INCLUDE_LIGHTING_RSM
#define INCLUDE_LIGHTING_RSM

#include "/include/lighting/shadows/distortion.glsl"
#include "/include/utility/encoding.glsl"
#include "/include/utility/rotation.glsl"

vec3 calculate_rsm(vec3 position_scene, vec3 world_normal, float skylight, vec2 noise) {
#if !(defined WORLD_OVERWORLD) || !defined SHADOW || !defined SHADOW_COLOR
    return vec3(0.0);
#else
    const int shadow_map_res = int(float(shadowMapResolution) * MC_SHADOW_QUALITY);
    const float rcp_samples = 1.0 / float(RSM_SAMPLES);
    const float sq_radius = RSM_RADIUS * RSM_RADIUS;

    vec3 shadow_view_pos = transform(shadowModelView, position_scene);
    vec3 shadow_clip_pos = project_ortho(shadowProjection, shadow_view_pos);

    vec3 projection_scale = vec3(shadowProjection[0].x, shadowProjection[1].y, shadowProjection[2].z);
    vec3 projection_inv_scale = vec3(shadowProjectionInverse[0].x, shadowProjectionInverse[1].y, shadowProjectionInverse[2].z);

    vec3 shadow_normal = mat3(shadowModelView) * world_normal;

    const float golden_angle = 2.39996322972865332;
    mat2 golden_rotate = get_rotation_matrix(golden_angle);
    vec2 offset_radius = RSM_RADIUS * projection_scale.xy;
    float angle = 3.141592653589793 * (noise.x * 2.0 + 2.0 * noise.y);
    vec2 dir = vec2(cos(angle), sin(angle)) * offset_radius;

    vec3 sum = vec3(0.0);
    for (uint i = 0u; i < RSM_SAMPLES; ++i) {
        float sample_t = (float(i) + noise.y) * rcp_samples;

        vec2 sample_clip_xy = shadow_clip_pos.xy + dir * sample_t;
        vec2 uv = sample_clip_xy;
             uv /= get_distortion_factor(uv);
             uv  = uv * 0.5 + 0.5;

        if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) { dir *= golden_rotate; continue; }

        ivec2 texel = ivec2(uv * float(shadow_map_res));

        float depth = texelFetch(shadowtex0, texel, 0).x;
        float sample_clip_z = (depth - 0.5) * (2.0 / SHADOW_DEPTH_SCALE);

        vec3 delta_clip = vec3(sample_clip_xy, sample_clip_z) - shadow_clip_pos;
        vec3 delta_sv = projection_inv_scale * delta_clip;

        float d2 = dot(delta_sv, delta_sv);
        if (d2 > sq_radius) { dir *= golden_rotate; continue; }

        vec3 l = delta_sv * inversesqrt(max(d2, eps));

        float diffuse = dot(shadow_normal, l);
        if (diffuse < eps) { dir *= golden_rotate; continue; }

    vec4 rsm1 = texelFetch(shadowcolor1, texel, 0);
    vec3 rsm_albedo = texelFetch(shadowcolor0, texel, 0).rgb * 4.0;

    if (rsm1.w > 0.5) { dir *= golden_rotate; continue; }
        vec3 sample_normal_sv = mat3(shadowModelView) * decode_unit_vector(rsm1.xy);

        float bounce = dot(sample_normal_sv, -l);
        if (bounce < eps) { dir *= golden_rotate; continue; }

        float falloff = sample_t / (d2 + eps);
        float sky_w = 1.0 - clamp(2.0 * sqr(rsm1.z - skylight), 0.0, 1.0);

        sum += diffuse * bounce * falloff * sky_w * rsm_albedo;

        dir *= golden_rotate;
    }

    return clamp(sum * sq_radius * rcp_samples * RSM_BRIGHTNESS * 3.141592653589793, 0.0, 1e6);
#endif
}

#endif // INCLUDE_LIGHTING_RSM
