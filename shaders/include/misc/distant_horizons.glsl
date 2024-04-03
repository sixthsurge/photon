#if !defined INCLUDE_MISC_DISTANT_HORIZONS
#define INCLUDE_MISC_DISTANT_HORIZONS

#ifdef DISTANT_HORIZONS
uniform sampler2D dhDepthTex;
uniform sampler2D dhDepthTex1;

#include "/include/utility/space_conversion.glsl"

bool is_distant_horizons_terrain(float depth, float depth_dh) {
    return depth >= 1.0 && depth_dh < 1.0;
}
#endif

#endif // INCLUDE_MISC_DISTANT_HORIZONS
