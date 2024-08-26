#if !defined INCLUDE_LIGHTING_COLORS_END_COLOR
#define INCLUDE_LIGHTING_COLORS_END_COLOR

#include "/include/utility/color.glsl"

vec3 get_light_color() {
	return from_srgb(vec3(END_LIGHT_R, END_LIGHT_G, END_LIGHT_B)) * END_LIGHT_I;
}

vec3 get_ambient_color() {
	return from_srgb(vec3(END_AMBIENT_R, END_AMBIENT_G, END_AMBIENT_B)) * END_AMBIENT_I;
}

#endif
