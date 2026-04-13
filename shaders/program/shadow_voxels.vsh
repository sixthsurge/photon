#include "/include/global.glsl"

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;

uniform vec3 cameraPosition;

#include "/include/lighting/shadows/distortion.glsl"

out vec3 cage_normal;
out vec3 world_pos;
flat out vec3 tint;

void main() {
    tint = gl_Color.rgb;

    #if !defined WORLD_NETHER
    vec3 pos = transform(gl_ModelViewMatrix, gl_Vertex.xyz);

    cage_normal = gl_Normal;
    world_pos = transform(shadowModelViewInverse, pos) + cameraPosition;

    vec3 shadow_clip_pos = project_ortho(gl_ProjectionMatrix, pos);
    shadow_clip_pos = distort_shadow_space(shadow_clip_pos);

    gl_Position = vec4(shadow_clip_pos, 1.0);

    #else
    // No shadows, discard vertices now
    gl_Position = vec4(-1.0);
    return;
    #endif
}