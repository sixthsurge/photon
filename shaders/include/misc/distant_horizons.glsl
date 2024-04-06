#if !defined INCLUDE_MISC_DISTANT_HORIZONS
#define INCLUDE_MISC_DISTANT_HORIZONS

/*
 * Utility include for Distant Horizons support
 */

#ifdef DISTANT_HORIZONS
uniform sampler2D dhDepthTex;
uniform sampler2D dhDepthTex1;

// -------------------------
//   combined depth buffer 
// -------------------------

uniform float combined_near;
uniform float combined_far;

uniform sampler2D colortex15;
#define combined_depth_buffer colortex15

uniform vec4 combined_projection_matrix_0;
uniform vec4 combined_projection_matrix_1;
uniform vec4 combined_projection_matrix_2;
uniform vec4 combined_projection_matrix_3;
#define combined_projection_matrix mat4(combined_projection_matrix_0, combined_projection_matrix_1, combined_projection_matrix_2, combined_projection_matrix_3)

uniform vec4 combined_projection_matrix_inverse_0;
uniform vec4 combined_projection_matrix_inverse_1;
uniform vec4 combined_projection_matrix_inverse_2;
uniform vec4 combined_projection_matrix_inverse_3;
#define combined_projection_matrix_inverse mat4(combined_projection_matrix_inverse_0, combined_projection_matrix_inverse_1, combined_projection_matrix_inverse_2, combined_projection_matrix_inverse_3)

#include "/include/utility/space_conversion.glsl"

bool is_distant_horizons_terrain(float depth, float depth_dh) {
    return depth >= 1.0 && depth_dh < 1.0;
}
#else
#define combined_near                      near
#define combined_far                       far
#define combined_projection_matrix         gbufferProjection
#define combined_projection_matrix_inverse gbufferProjectionInverse
#define combined_depth_buffer              depthtex1
#endif

#endif // INCLUDE_MISC_DISTANT_HORIZONS
