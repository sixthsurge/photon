/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/lpv/floodfill.csh:
  Perform floodfill iteration

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

layout (local_size_x = 32) in;

#if   VOXEL_VOLUME_SIZE == 64
const ivec3 workGroups = ivec3(2, 64, 64);
#elif VOXEL_VOLUME_SIZE == 96
const ivec3 workGroups = ivec3(3, 96, 96);
#elif VOXEL_VOLUME_SIZE == 128
const ivec3 workGroups = ivec3(4, 128, 128);
#elif VOXEL_VOLUME_SIZE == 256
const ivec3 workGroups = ivec3(8, 256, 256);
#elif VOXEL_VOLUME_SIZE == 512
const ivec3 workGroups = ivec3(16, 512, 512);
#endif

writeonly uniform image3D light_img_a;
writeonly uniform image3D light_img_b;

uniform sampler3D light_sampler_a;
uniform sampler3D light_sampler_b;

uniform usampler3D voxel_sampler;
uniform sampler2D light_data_sampler;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform int frameCounter;

#include "/include/lighting/lpv/floodfill.glsl"

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
