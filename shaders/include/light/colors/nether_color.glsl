#if !defined INCLUDE_LIGHT_COLORS_NETHER_COLOR
#define INCLUDE_LIGHT_COLORS_NETHER_COLOR

#include "/include/utility/color.glsl"

vec3 get_nether_color() {
	vec3 nether_color  = srgb_eotf_inv(fogColor) * rec709_to_rec2020;
	     nether_color /= max(dot(nether_color, luminance_weights_rec2020), eps);
	     nether_color  = mix(vec3(1.0), nether_color, NETHER_S);
	     nether_color *= 0.04 * NETHER_I;

	return nether_color;
}

#endif // INCLUDE_LIGHT_COLORS_NETHER_COLOR
