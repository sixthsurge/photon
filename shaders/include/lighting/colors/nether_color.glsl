#if !defined INCLUDE_LIGHTING_COLORS_NETHER_COLOR
#define INCLUDE_LIGHTING_COLORS_NETHER_COLOR

#include "/include/utility/color.glsl"

vec3 get_light_color() {
	return vec3(0.0);
}

vec3 get_ambient_color() {
#ifdef NETHER_USE_BIOME_COLOR
	vec3 nether_color  = srgb_eotf_inv(fogColor) * rec709_to_rec2020;
	     nether_color /= max(dot(nether_color, luminance_weights_rec2020), eps);
	     nether_color  = mix(vec3(1.0), nether_color, NETHER_S);
	     nether_color *= 0.05 * NETHER_I;
#else
	vec3 nether_color  = from_srgb(vec3(NETHER_R, NETHER_G, NETHER_B)) * 0.1 * NETHER_I;
#endif

	return nether_color;
}

#endif // INCLUDE_LIGHTING_COLORS_NETHER_COLOR
