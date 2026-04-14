#include "/include/global.glsl"

in vec3 cage_normal;
in vec3 world_pos;
flat in vec3 tint;

uniform int frameCounter, frameTime;
uniform float viewWidth, viewHeight;

uniform vec3 cameraPosition;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform mat4 shadowProjection, shadowProjectionInverse;
uniform mat4 shadowModelView, shadowModelViewInverse;

uniform sampler2D depthtex0;

layout(location = 0) out vec3 shadowcolor0_out;

#include "/include/lighting/shadows/distortion.glsl"
#include "/include/utility/color.glsl"
#include "/photonics/photonics.glsl"

void main() {
    #if defined WORLD_NETHER
    discard;
    #endif

    RayJob ray = RayJob(
        world_pos - world_offset - 0.01f * cage_normal, // Ray origin
        mat3(shadowModelViewInverse) * vec3(0f, 0f, -1f), // Ray direction
        vec3(0f), vec3(0f), vec3(0f), false
    );

    ray_constraint = ivec3(ray.origin);
    trace_ray(ray);

    if (!ray.result_hit) discard;

    vec4 base_color = vec4(ray.result_color, 1f);

    shadowcolor0_out = mix(vec3(1.0), base_color.rgb * tint, base_color.a);
    shadowcolor0_out = 0.25 * srgb_eotf_inv(shadowcolor0_out) * rec709_to_rec2020;
    shadowcolor0_out *= step(base_color.a, 1.0 - rcp(255.0));
}