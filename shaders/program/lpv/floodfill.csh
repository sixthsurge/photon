/*
--------------------------------------------------------------------------------

  Photon Shaders by SixthSurge

  program/lpv/floodfill.csh:
  Perform one floodfill iteration

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

layout (local_size_x = 32) in;

#if   VOXEL_VOLUME_SIZE == 64
const ivec3 workGroups = ivec3(2, 64, 64);
#elif VOXEL_VOLUME_SIZE == 128
const ivec3 workGroups = ivec3(4, 64, 128);
#elif VOXEL_VOLUME_SIZE == 256
const ivec3 workGroups = ivec3(8, 64, 256);
#endif

layout (std430, binding = 0) buffer LightData {
	vec4[32] light_color;
	vec4[16] tint_color;
} light_data;

writeonly uniform image3D light_img_a;
writeonly uniform image3D light_img_b;

uniform sampler3D light_sampler_a;
uniform sampler3D light_sampler_b;

uniform usampler3D voxel_sampler;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform int frameCounter;

#include "/include/light/lpv/floodfill.glsl"

void main() {
	if ((frameCounter & 1) == 0) {
		update_lpv(light_img_a, light_sampler_b);
	} else {
		update_lpv(light_img_b, light_sampler_a);
	}
}

#ifndef COLORED_LIGHTS
	#error "This program should be disabled if colored lights are disabled"
#endif
