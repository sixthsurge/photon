#if !defined INCLUDE_LIGHTING_SHADOWS_DISTANCE_FADE
#define INCLUDE_LIGHTING_SHADOWS_DISTANCE_FADE

#include "/include/lighting/shadows/common.glsl"
#include "/include/lighting/shadows/distortion.glsl"

// Shadow map distance fade without sampling the shadow map, for when shadows
// were filtered in an earlier pass (see program/d4_split.glsl). Mirrors the
// position calculation at the start of get_filtered_shadows in pcss.glsl
float get_shadow_distance_fade(
    vec3 scene_pos,
    vec3 flat_normal,
    float skylight
) {
#ifndef SHADOW
    return 1.0;
#else
    float NoL = dot(flat_normal, light_dir);
    vec3 bias = get_shadow_bias(scene_pos, flat_normal, NoL, skylight);

    vec3 edge_factor
        = 0.1 - 0.2 * fract(scene_pos + cameraPosition + flat_normal * 0.01);
    edge_factor -= edge_factor * skylight;

#ifdef PIXELATED_SHADOWS
    const float pixel_scale = float(PIXELATED_SHADOWS_RESOLUTION);
    scene_pos = scene_pos + cameraPosition;
    scene_pos = floor(scene_pos * pixel_scale + 0.01) * rcp(pixel_scale)
        + (0.5 / pixel_scale);
    scene_pos = scene_pos - cameraPosition;
#endif

    vec3 shadow_view_pos
        = transform(shadowModelView, scene_pos + bias + edge_factor);
    vec3 shadow_clip_pos = project_ortho(shadowProjection, shadow_view_pos);
    vec3 shadow_screen_pos = distort_shadow_space(shadow_clip_pos) * 0.5 + 0.5;

    return get_shadow_distance_fade(scene_pos, shadow_screen_pos);
#endif
}

#endif // INCLUDE_LIGHTING_SHADOWS_DISTANCE_FADE
