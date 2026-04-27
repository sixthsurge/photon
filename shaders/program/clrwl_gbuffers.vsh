/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/clrwl_gbuffers:
  Colorwheel (Flywheel 1.0) instanced geometry - vertex stage

  Colorwheel injects clrwl_computeFragment() at runtime.
  This program must NOT use Photon's existing gbuffers varyings;
  it is a standalone program called only by Colorwheel.

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

// Colorwheel-injected instance data comes in through standard gl_* attributes.
// We output the minimal set of varyings needed for the fragment stage.

out vec2 texcoord;
out vec2 lmcoord;
out vec4 glcolor;
out vec3 world_normal;

// ------------
//   Uniforms
// ------------

uniform mat4 gbufferModelViewInverse;

void main() {
    gl_Position = ftransform();

    texcoord    = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord     = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    glcolor     = gl_Color;

    // Transform normal: model-view space → world/player space
    // This matches how gbuffers_all_solid.vsh builds the TBN matrix.
    vec3 view_normal = gl_NormalMatrix * gl_Normal;
    world_normal     = mat3(gbufferModelViewInverse) * view_normal;
}
