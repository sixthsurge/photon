/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/c1_blend_layers
  Combine:
   - Solid layer
   - Translucent layer
   - Fog 
   - Clouds in front of translucents
   - LoD water 
   - Rainbow

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

layout (location = 0) out vec3 fragment_color;

/* RENDERTARGETS: 0 */

#ifdef BLOOMY_FOG
layout (location = 1) out float bloomy_fog;

/* RENDERTARGETS: 0,3 */
#endif

in vec2 uv;

flat in vec3 ambient_color;
flat in vec3 light_color;

#ifdef WORLD_OVERWORLD 
#include "/include/fog/overworld/parameters.glsl"
flat in OverworldFogParameters fog_params;
#endif

// ------------
//   Uniforms
// ------------

uniform sampler2D noisetex;

uniform sampler2D colortex0;  // scene color
uniform sampler2D colortex3;  // refraction data
uniform sampler2D colortex4;  // sky map
uniform sampler2D colortex5;  // scene history
uniform sampler2D colortex6;  // volumetric fog scattering
uniform sampler2D colortex7;  // volumetric fog transmittance
uniform sampler2D colortex11; // clouds history
uniform sampler2D colortex12; // clouds data
uniform sampler2D colortex13; // rendered translucent layer

#ifdef SHADOW 
#ifdef AIR_FOG_COLORED_LIGHT_SHAFTS
uniform sampler2D shadowcolor0;
uniform sampler2D shadowtex0;
#endif
uniform sampler2D shadowtex1;
#endif

#ifdef DH 
uniform sampler2D colortex1;  // distant water gbuffer 
#endif

#ifdef VOXY 
uniform sampler2D colortex16; // distant water gbuffer 0
#endif

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;

uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform float near;
uniform float far;

uniform float frameTimeCounter;
uniform float sunAngle;
uniform float rainStrength;
uniform float wetness;

uniform int worldTime;
uniform int moonPhase;
uniform int frameCounter;

uniform int isEyeInWater;
uniform float eyeAltitude;
uniform float blindness;
uniform float nightVision;
uniform float darknessFactor;

uniform vec3 light_dir;
uniform vec3 sun_dir;
uniform vec3 moon_dir;

uniform vec2 view_res;
uniform vec2 view_pixel_size;
uniform vec2 taa_offset;

uniform float eye_skylight;

uniform float biome_cave;
uniform float biome_may_rain;
uniform float biome_may_snow;

uniform float time_sunrise;
uniform float time_noon;
uniform float time_sunset;
uniform float time_midnight;

// ------------
//   Includes
// ------------

#define SSRT_LOD
#define TEMPORAL_REPROJECTION

#include "/include/fog/simple_fog.glsl"
#include "/include/misc/lod_mod_support.glsl"
#include "/include/misc/lightning_flash.glsl"
#include "/include/misc/material_masks.glsl"
#include "/include/utility/color.glsl"
#include "/include/utility/encoding.glsl"
#include "/include/utility/fast_math.glsl"
#include "/include/utility/space_conversion.glsl"

#ifdef WORLD_OVERWORLD
#include "/include/fog/overworld/analytic.glsl"
#include "/include/sky/clouds/sampling.glsl"

#ifdef LOD_MOD_ACTIVE
uniform sampler2D colortex8;
uniform mat4 shadowModelViewInverse;

#include "/include/lighting/cloud_shadows.glsl"
#endif
#endif

#ifdef LOD_MOD_ACTIVE
#include "/include/misc/distant_water.glsl"
#endif

vec3 blend_layers_with_fog(
	vec3 background_color,
	vec4 translucent_color,
	vec3 front_position_world,
	vec3 back_position_world,
	bool is_translucent,
	bool is_sky,
	bool front_is_hand,
	bool back_is_hand
) {
	if (back_is_hand) return background_color;

	// Apply analytic fog behind translucents

#if defined WORLD_OVERWORLD 
	if (is_translucent) {
		mat2x3 analytic_fog = air_fog_analytic(
			front_position_world, 
			back_position_world, 
			is_sky,
			eye_skylight,
			1.0
		);

		background_color = background_color * analytic_fog[1] + analytic_fog[0];
	}
#endif

	return background_color * (1.0 - translucent_color.a) + translucent_color.rgb;
}

// https://iquilezles.org/www/articles/texture/texture.htm
vec4 smooth_filter(sampler2D sampler, vec2 coord) {
	vec2 res = vec2(textureSize(sampler, 0));

	coord = coord * res + 0.5;

	vec2 i, f = modf(coord, i);
	f = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	coord = i + f;

	coord = (coord - 0.5) / res;
	return texture(sampler, coord);
}

void main() {
	ivec2 texel = ivec2(gl_FragCoord.xy);

	// Sample textures

	float front_depth      = texelFetch(depthtex0, texel, 0).x;
	float back_depth       = texelFetch(depthtex1, texel, 0).x;

	vec4 refraction_data   = texelFetch(colortex3, texel, 0);
	vec4 translucent_color = texelFetch(colortex13, texel, 0);
	
#if defined VL || defined LPV_VL
	vec3 fog_transmittance = smooth_filter(colortex6, uv).rgb;
	vec3 fog_scattering    = smooth_filter(colortex7, uv).rgb;
#endif

	// Distant Horizons support

#ifdef LOD_MOD_ACTIVE
    float front_depth_lod   = texelFetch(lod_depth_tex, texel, 0).x;
	float back_depth_lod    = texelFetch(lod_depth_tex_solid, texel, 0).x;

    bool front_is_lod_terrain = is_lod_terrain(front_depth, front_depth_lod);
    bool back_is_lod_terrain = is_lod_terrain(back_depth, back_depth_lod);

	bool is_translucent_lod = front_depth_lod != back_depth_lod;
#else
	#define front_depth_lod      front_depth
	#define back_depth_lod       back_depth
	#define front_is_lod_terrain false
	#define back_is_lod_terrain  false
	#define is_translucent_lod   false
#endif

	bool is_translucent = front_depth != back_depth;
	bool is_sky = back_depth == 1.0 && back_depth_lod == 1.0;

	// Space conversions

	bool front_is_hand;
	bool back_is_hand;
	fix_hand_depth(front_depth, front_is_hand);
	fix_hand_depth(back_depth, back_is_hand);

	vec3 front_position_screen = vec3(uv, front_is_lod_terrain ? front_depth_lod : front_depth);
	vec3 front_position_view   = screen_to_view_space(front_position_screen, true, front_is_lod_terrain);
	vec3 front_position_scene  = view_to_scene_space(front_position_view);
	vec3 front_position_world  = front_position_scene + cameraPosition;

	vec3 back_position_screen  = vec3(uv, back_is_lod_terrain ? back_depth_lod : back_depth);
	vec3 back_position_view    = screen_to_view_space(back_position_screen, true, back_is_lod_terrain);
	vec3 back_position_world   = view_to_scene_space(back_position_view) + cameraPosition;

	vec3 direction_world; float view_distance;
	length_normalize(front_position_scene - gbufferModelViewInverse[3].xyz, direction_world, view_distance);

	// Refraction 

	vec2 refracted_uv = uv;
	float layer_dist = abs(view_distance - length(back_position_view));

#if REFRACTION != REFRACTION_OFF
	if (is_translucent && refraction_data != vec4(0.0)) {
		vec2 normal_tangent = vec2(
			unsplit_2x8(refraction_data.xy) * 2.0 - 1.0,
			unsplit_2x8(refraction_data.zw) * 2.0 - 1.0
		);

		refracted_uv = uv + normal_tangent.xy * rcp(max(view_distance, 1.0)) * min(layer_dist, 8.0) * (0.1 * REFRACTION_INTENSITY);

		// Make sure the refracted fragment is behind the fragment position
		float depth_refracted = texture(depthtex1, refracted_uv).x;
		refracted_uv = mix(refracted_uv, uv, float(depth_refracted < front_depth));
	}
#endif

	fragment_color = texture(colortex0, refracted_uv * taau_render_scale).rgb;
	vec3 original_color = fragment_color;

	// Draw LoD water

#if defined LOD_MOD_ACTIVE
	if (front_depth_lod != back_depth_lod) {
		// if there is a layer of LoD water behind the translucent layer, these 
		// will store the position of that layer
		vec3 lod_position_screen = front_position_screen;
		vec3 lod_position_view   = front_position_view;
		vec3 lod_position_world  = front_position_world;

		// detect whether translucent LoD terrain may be behind the translucent layer
		float z_mc = screen_to_view_space_depth(gbufferProjectionInverse, front_depth);
		float z_lod = screen_to_view_space_depth(lod_projection_matrix_inverse, front_depth_lod);

		const float error_margin = 1.0;
		bool lod_behind_translucent = z_lod > z_mc + error_margin && back_depth == 1.0;

		if (front_is_lod_terrain || lod_behind_translucent) {
			if (lod_behind_translucent) {
				lod_position_screen = vec3(uv, front_depth_lod);
				lod_position_view = screen_to_view_space(lod_projection_matrix_inverse, lod_position_screen, true);
				lod_position_world = view_to_scene_space(lod_position_view) + cameraPosition;
			}

			// Unpack gbuffer data

	#ifdef VOXY
			vec4 gbuffer_data = texelFetch(colortex16, texel, 0);
			bool is_water = min_of(gbuffer_data) > eps;
	#else
			vec4 gbuffer_data = texelFetch(colortex1, texel, 0);
	#endif

			mat4x2 data = mat4x2(
				unpack_unorm_2x8(gbuffer_data.x),
				unpack_unorm_2x8(gbuffer_data.y),
				unpack_unorm_2x8(gbuffer_data.z),
				unpack_unorm_2x8(gbuffer_data.w)
			);

			vec3 tint          = vec3(data[0], data[1].x);
			vec3 flat_normal   = decode_unit_vector(data[2]);
			vec2 light_levels  = data[3];

	#ifdef DISTANT_HORIZONS
			uint material_mask = uint(255.0 * data[1].y);
			bool is_water = material_mask == MATERIAL_WATER;
	#else 
			float water_alpha = data[1].y;
	#endif

			if (is_water) { // Water
				vec4 water_color = draw_distant_water(
					lod_position_screen,
					lod_position_view,
					lod_position_world,
					direction_world,
					flat_normal,
					tint,
					light_levels,
					length_knowing_direction(cameraPosition - lod_position_world, direction_world),
					length_knowing_direction(lod_position_world - back_position_world, direction_world)
				);

	#ifdef VOXY
				// Account for darkening by alpha of water surface
				//water_color *= 8.0;
	#endif

				fragment_color = fragment_color * (1.0 - water_color.a) + water_color.rgb;
			}

			back_position_world = lod_behind_translucent
				? lod_position_world
				: back_position_world;
		}
	}
#endif

	// Blend layers

	fragment_color = blend_layers_with_fog(
		fragment_color,
		translucent_color,
		front_position_world,
		back_position_world,
		is_translucent,
		is_sky,
		front_is_hand,
		back_is_hand
	);

	// Border fog 

#ifdef BORDER_FOG
	fragment_color = mix(
		original_color,
		fragment_color, 
		border_fog(front_position_scene, direction_world)
	);
#endif

	// Blend clouds in front of translucents

#if defined WORLD_OVERWORLD
	float clouds_apparent_distance;
	vec4 clouds_and_aurora = read_clouds_and_aurora(refracted_uv, clouds_apparent_distance);

	if (is_translucent || is_translucent_lod) {
		if (clouds_apparent_distance < view_distance) {
			fragment_color = fragment_color * clouds_and_aurora.w + clouds_and_aurora.xyz;
		}
	}
#endif

	// Blend fog

#if defined VL || defined LPV_VL
	// Volumetric fog

	fragment_color = fragment_color * fog_transmittance + fog_scattering;

	#ifdef BLOOMY_FOG
	bloomy_fog = clamp01(dot(fog_transmittance, vec3(luminance_weights_rec2020)));
	bloomy_fog = isEyeInWater == 1.0 ? sqrt(bloomy_fog) : bloomy_fog;
	#endif
#endif

#if !defined VL 
	// Analytic fog

	if (isEyeInWater == 1) {
		// Underwater fog
		float LoV = dot(direction_world, light_dir);

		mat2x3 analytic_fog = water_fog_simple(
			light_color,
			ambient_color,
			water_absorption_coeff,
			vec2(0.0, eye_skylight),
			view_distance,
			LoV,
			15.0 * eye_skylight
		);

		fragment_color *= analytic_fog[1];
		fragment_color += analytic_fog[0];

	#ifdef BLOOMY_FOG
		bloomy_fog = sqrt(clamp01(dot(analytic_fog[1], vec3(0.33))));
	#endif
	} else {
	#if defined WORLD_OVERWORLD
		// Overworld fog

		mat2x3 analytic_fog = air_fog_analytic(
			cameraPosition,
			front_position_world,
			is_sky,
			eye_skylight,
			1.0
		);

		fragment_color *= analytic_fog[1];
		fragment_color += analytic_fog[0];

		#ifdef BLOOMY_FOG
		bloomy_fog = clamp01(dot(fog_transmittance, vec3(luminance_weights_rec2020)));
		bloomy_fog = isEyeInWater == 1.0 ? sqrt(bloomy_fog) : bloomy_fog;
		#endif
	#else 
		#ifdef BLOOMY_FOG
		bloomy_fog = 1.0;
		#endif
	#endif
	}
#endif

#ifdef BLOOMY_FOG
	#if   defined WORLD_NETHER
	bloomy_fog = spherical_fog(view_distance, nether_fog_start, nether_bloomy_fog_density) * 0.33 + 0.67;
	#elif defined WORLD_END
	bloomy_fog = bloomy_fog * 0.5 + 0.5;
	#endif
#endif
}
