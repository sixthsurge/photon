/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/c14_color_grading:
  Apply bloom, color grading and tone mapping then convert to rec. 709

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

out vec2 uv;

#if GRADE_WHITE_BALANCE != 6500
flat out mat3 white_balance_matrix;
#endif

#include "/include/post_processing/aces/utility.glsl"
#include "/include/utility/color.glsl"

void main() {
    uv = gl_MultiTexCoord0.xy;

#if GRADE_WHITE_BALANCE != 6500
    vec3 src_xyz = blackbody(float(GRADE_WHITE_BALANCE)) * rec2020_to_xyz;
    vec3 dst_xyz = blackbody(6500.0) * rec2020_to_xyz;
    white_balance_matrix = get_chromatic_adaptation_matrix(src_xyz, dst_xyz);
#endif

    gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 0.0, 1.0);
}
