/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/c0_vl:
  Calculate volumetric fog

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

layout (location = 0) out vec3 fog_transmittance;
layout (location = 1) out vec3 fog_scattering;

/* RENDERTARGETS: 6,7 */

in vec2 uv;

flat in vec3 ambient_color;
flat in vec3 light_color;

#if defined WORLD_OVERWORLD
#include "/include/fog/overworld/parameters.glsl"
flat in OverworldFogParameters fog_params;
#endif

// ------------
//   Uniforms
// ------------

uniform sampler2D noisetex;

uniform sampler3D colortex0; // 3D worley noise
uniform sampler2D colortex1; // gbuffer data
uniform sampler2D colortex3; // translucent color
uniform sampler2D colortex4; // sky map
uniform sampler2D colortex8; // cloud shadow map

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

#ifndef WORLD_NETHER
#ifdef SHADOW
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
#ifdef SHADOW_COLOR
uniform sampler2D shadowcolor0;
#endif
#endif
#endif

#ifdef DISTANT_HORIZONS
uniform sampler2D dhDepthTex;
#endif

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;

#ifdef DISTANT_HORIZONS
uniform int dhRenderDistance;
#endif

uniform vec3 cameraPosition;

uniform float near;
uniform float far;

uniform float blindness;
uniform float darknessFactor;
uniform float eyeAltitude;
uniform float rainStrength;
uniform float wetness;

uniform float sunAngle;
uniform float frameTimeCounter;

uniform int isEyeInWater;
uniform int worldTime;
uniform int frameCounter;

uniform float world_age;

uniform vec3 light_dir;
uniform vec3 sun_dir;
uniform vec3 moon_dir;

uniform vec2 view_res;
uniform vec2 view_pixel_size;
uniform vec2 taa_offset;

uniform float eye_skylight;
uniform float desert_sandstorm;

uniform float time_sunrise;
uniform float time_noon;
uniform float time_sunset;
uniform float time_midnight;

// ------------
//   Includes
// ------------

#if defined WORLD_OVERWORLD
#include "/include/fog/overworld/raymarched.glsl"
#endif

#if defined WORLD_END
#include "/include/fog/end_fog_vl.glsl"
#endif

#include "/include/fog/water_fog_vl.glsl"

#include "/include/utility/encoding.glsl"
#include "/include/utility/random.glsl"
#include "/include/utility/space_conversion.glsl"

#if defined LPV_VL && defined COLORED_LIGHTS 
uniform sampler3D light_sampler_a;
uniform sampler3D light_sampler_b;

#include "/include/fog/lpv_fog.glsl"
#endif

void main() {
	ivec2 fog_texel  = ivec2(gl_FragCoord.xy);
	ivec2 view_texel = ivec2(gl_FragCoord.xy * taau_render_scale * rcp(VL_RENDER_SCALE));

	float depth0        = texelFetch(depthtex0, view_texel, 0).x;
	float depth1        = texelFetch(depthtex1, view_texel, 0).x;
	vec4 gbuffer_data_0 = texelFetch(colortex1, view_texel, 0);

#ifdef DISTANT_HORIZONS
    mat4 projection_matrix, projection_matrix_inverse;
    bool is_dh_terrain;
	float dh_depth = texelFetch(dhDepthTex, view_texel, 0).x;

    if (depth0 == 1.0) {
        is_dh_terrain = true;
        depth0 = dh_depth;
        depth1 = dh_depth;
        projection_matrix = dhProjection;
        projection_matrix_inverse = dhProjectionInverse;
    } else {
        is_dh_terrain = false;
        projection_matrix = gbufferProjection;
        projection_matrix_inverse = gbufferProjectionInverse;
    }
#else
    #define is_dh_terrain             false
    #define projection_matrix         gbufferProjection
    #define projection_matrix_inverse gbufferProjectionInverse
#endif

	float skylight = unpack_unorm_2x8(gbuffer_data_0.w).y;

	vec3 view_pos  = screen_to_view_space(projection_matrix_inverse, vec3(uv, depth0), true);
	vec3 scene_pos = view_to_scene_space(view_pos);
	vec3 world_pos = scene_pos + cameraPosition;

	vec3 view_back_pos  = screen_to_view_space(vec3(uv, depth1), true);
	vec3 scene_back_pos = view_to_scene_space(view_back_pos);
	vec3 world_back_pos = scene_back_pos + cameraPosition;

	float dither = texelFetch(noisetex, fog_texel & 511, 0).b;
	      dither = r1(frameCounter, dither);

	vec3 world_start_pos = gbufferModelViewInverse[3].xyz + cameraPosition;
	vec3 world_end_pos   = world_pos;

	// Volumetric lighting

#if defined VL
	switch (isEyeInWater) {
		case 0:
			#if defined WORLD_OVERWORLD
			mat2x3 fog = raymarch_air_fog(world_start_pos, world_end_pos, depth0 == 1.0, skylight, dither);
			#elif defined WORLD_NETHER
			mat2x3 fog = mat2x3(vec3(0.0), vec3(1.0));
			#elif defined WORLD_END
			mat2x3 fog = raymarch_end_fog(world_start_pos, world_end_pos, depth0 == 1.0, dither);
			#endif

			fog_scattering    = fog[0];
			fog_transmittance = fog[1];

			break;

		case 1:
			mat2x3 water_fog = raymarch_water_fog(world_start_pos, world_end_pos, depth0 == 1.0, dither);

			fog_scattering    = water_fog[0];
			fog_transmittance = water_fog[1];

			break;

		default:
			fog_scattering    = vec3(0.0);
			fog_transmittance = vec3(1.0);

			break;

		// Prevent potential game crash due to empty switch statement
		case -1:
			break;
	}
#else 
	fog_scattering = vec3(0.0);
	fog_transmittance = vec3(1.0);
#endif

#if defined LPV_VL && defined COLORED_LIGHTS 
	fog_scattering += get_lpv_fog_scattering(
		world_start_pos,
		world_end_pos,
		dither
	);
#endif
}
