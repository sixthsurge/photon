#version 400 compatibility

/*
--------------------------------------------------------------------------------

  Photon Shaders by SixthSurge

  world0/deferred1.fsh:
  Render clouds at 1/16th resolution

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

/* DRAWBUFFERS:8 */
layout (location = 0) out vec4 clouds;

in vec2 uv;

/*
const int colortex8Format = RGBA16F;
*/

flat in vec3 base_light_color;
flat in vec3 sky_color;
flat in vec3 sun_color;
flat in vec3 moon_color;

uniform sampler2D depthtex1;

uniform sampler2D noisetex;

uniform sampler3D shadowcolor1; // Atmospheric scattering LUT

uniform sampler3D depthtex0; // 3D worley noise
uniform sampler3D depthtex2; // 3D curl noise

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;

uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform float near;
uniform float far;

uniform int worldTime;
uniform float sunAngle;

uniform int frameCounter;
uniform float frameTimeCounter;

uniform int isEyeInWater;
uniform float eyeAltitude;

uniform vec3 sun_dir;
uniform vec3 moon_dir;

uniform vec2 view_res;
uniform vec2 view_pixel_size;
uniform vec2 taa_offset;

uniform float biome_cave;

uniform vec3 clouds_light_dir;

uniform vec2 clouds_coverage_cu;
uniform vec2 clouds_coverage_ac;
uniform vec2 clouds_coverage_cc;
uniform vec2 clouds_coverage_ci;

#define ATMOSPHERE_SCATTERING_LUT shadowcolor1

#include "/include/utility/random.glsl"
#include "/include/utility/space_conversion.glsl"

#include "/include/atmosphere.glsl"
#include "/include/clouds.glsl"

float depth_max_4x4(sampler2D depth_sampler) {
	vec2 sample_pos = uv * rcp(CLOUDS_RENDER_SCALE);

	vec4 depth_samples_0 = textureGather(depth_sampler, sample_pos + vec2( 2.0 * view_pixel_size.x,  2.0 * view_pixel_size.y));
	vec4 depth_samples_1 = textureGather(depth_sampler, sample_pos + vec2(-2.0 * view_pixel_size.x,  2.0 * view_pixel_size.y));
	vec4 depth_samples_2 = textureGather(depth_sampler, sample_pos + vec2( 2.0 * view_pixel_size.x, -2.0 * view_pixel_size.y));
	vec4 depth_samples_3 = textureGather(depth_sampler, sample_pos + vec2(-2.0 * view_pixel_size.x, -2.0 * view_pixel_size.y));

	return max(
		max(max_of(depth_samples_0), max_of(depth_samples_1)),
		max(max_of(depth_samples_2), max_of(depth_samples_3))
	);
}

void main() {
	ivec2 texel = ivec2(gl_FragCoord.xy);

	vec3 view_pos = screen_to_view_space(vec3(uv, 1.0), true);
	vec3 ray_dir = mat3(gbufferModelViewInverse) * normalize(view_pos);

	vec3 clear_sky = atmosphere_scattering(ray_dir, sun_dir) * sun_color
	               + atmosphere_scattering(ray_dir, moon_dir) * moon_color;

	float dither = texelFetch(noisetex, ivec2(texel & 511), 0).b;
	      dither = r1(frameCounter, dither);

	clouds = draw_clouds_cu(ray_dir, clear_sky, dither);

	if (any(isnan(clouds))) clouds = vec4(1.0, 0.0, 0.0, 1.0);
}
