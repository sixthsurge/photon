/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/clrwl_shadow:
  Colorwheel (Flywheel 1.0) instanced geometry - shadow vertex stage

  Applies Photon's shadow projection and distortion, matching shadow.vsh.
  No vertex animations — Flywheel instances are static within a frame.

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

out vec2 texcoord;
out vec4 glcolor;

// ------------
//   Uniforms
// ------------

uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;

// Photon's shadow distortion — must match what shadow.vsh uses so that
// clrwl_shadow samples overlap correctly with the main shadow map.
#include "/include/lighting/shadows/distortion.glsl"

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    glcolor  = gl_Color;

    // Transform to shadow clip space and apply Photon's distortion.
    vec3 pos            = transform(gl_ModelViewMatrix, gl_Vertex.xyz);
    vec3 shadow_clip    = project_ortho(gl_ProjectionMatrix, pos);
         shadow_clip    = distort_shadow_space(shadow_clip);

    gl_Position = vec4(shadow_clip, 1.0);
}
