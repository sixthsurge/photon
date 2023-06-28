/*
--------------------------------------------------------------------------------

  Photon Shaders by SixthSurge

  program/lpv/setup.csh:
  Store light colors and tint colors in SSBO

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

layout (local_size_x = 32) in;
const ivec3 workGroups = ivec3(1, 1, 1);

layout (std430, binding = 0) buffer LightData {
	vec4[32] light_color;
	vec4[16] tint_color;
} light_data;

#include "/include/light/colors/blocklight_colors.glsl"

void main() {
	int index = int(gl_LocalInvocationID.x);

	light_data.light_color[index] = vec4(light_color[index], 0.0);

	if (index >= 16) return;
	light_data.tint_color[index] = vec4(tint_color[index], 0.0);
}

#ifndef COLORED_LIGHTS
	#error "This program should be disabled if colored lights are disabled"
#endif
