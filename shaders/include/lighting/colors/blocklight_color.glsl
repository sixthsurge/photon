#if !defined INCLUDE_LIGHTING_COLORS_BLOCKLIGHT_COLOR
#define INCLUDE_LIGHTING_COLORS_BLOCKLIGHT_COLOR

#include "/include/utility/color.glsl"

const vec3  blocklight_color = from_srgb(vec3(BLOCKLIGHT_R, BLOCKLIGHT_G, BLOCKLIGHT_B)) * BLOCKLIGHT_I;
const float blocklight_scale = 6.0;
const float emission_scale   = 40.0 * EMISSION_STRENGTH;

#endif // INCLUDE_LIGHTING_COLORS_BLOCKLIGHT_COLOR
