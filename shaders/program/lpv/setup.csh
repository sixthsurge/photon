/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/lpv/setup.csh:
  Store light colors and tint colors in SSBO

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

layout (local_size_x = 32) in;
const ivec3 workGroups = ivec3(1, 1, 1);

writeonly uniform image2D light_data_img;

#include "/include/lighting/lpv/light_colors.glsl"

void main() {
	int index = int(gl_LocalInvocationID.x);

	imageStore(light_data_img, ivec2(index, 0), vec4(light_color[clamp(index, 0u, 31u)], 0.0));
	imageStore(light_data_img, ivec2(index, 1), vec4(tint_color [clamp(index, 0u, 15u)], 0.0));
}

#ifndef COLORED_LIGHTS
	#error "This program should be disabled if colored lights are disabled"
#endif
