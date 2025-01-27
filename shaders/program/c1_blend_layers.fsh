/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/c1_blend_layers
  Apply volumetric fog

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

// ------------
//   Uniforms
// ------------

uniform sampler2D noisetex;

uniform sampler2D colortex0;  // scene color
uniform sampler2D colortex1;  // gbuffer 0
uniform sampler2D colortex2;  // gbuffer 1
uniform sampler2D colortex3;  // refraction data
uniform sampler2D colortex4;  // sky map
uniform sampler2D colortex5;  // scene history
uniform sampler2D colortex6;  // volumetric fog scattering
uniform sampler2D colortex7;  // volumetric fog transmittance
uniform sampler2D colortex11; // clouds history
uniform sampler2D colortex12; // clouds data
uniform sampler2D colortex13; // rendered translucent layer

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;

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

#define TEMPORAL_REPROJECTION

#include "/include/fog/simple_fog.glsl"
#include "/include/misc/distant_horizons.glsl"
#include "/include/utility/color.glsl"
#include "/include/utility/encoding.glsl"
#include "/include/utility/fast_math.glsl"
#include "/include/utility/space_conversion.glsl"

#ifdef DISTANT_HORIZONS
#include "/include/misc/distant_water.glsl"
#endif

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

vec4 read_clouds(out float apparent_distance) {
#if defined WORLD_OVERWORLD
	// Soften clouds for new pixels
	float pixel_age = texelFetch(colortex12, ivec2(gl_FragCoord.xy), 0).y;
	int ld = int(3.0 * dampen(max0(1.0 - 0.1 * pixel_age)));

	apparent_distance = min_of(textureGather(colortex12, uv * taau_render_scale, 0));

	return bicubic_filter_lod(colortex11, uv * taau_render_scale, ld);
#else
	return vec4(0.0, 0.0, 0.0, 1.0);
#endif
}

// http://www.diva-portal.org/smash/get/diva2:24136/FULLTEXT01.pdf
vec3 purkinje_shift(vec3 rgb, vec2 light_levels) {
#if !(defined PURKINJE_SHIFT && defined WORLD_OVERWORLD)
	return rgb;
#else
	float purkinje_intensity  = 0.05 * PURKINJE_SHIFT_INTENSITY;
	      purkinje_intensity  = purkinje_intensity - purkinje_intensity * smoothstep(-0.12, -0.06, sun_dir.y) * light_levels.y; // No purkinje shift in daylight
	      purkinje_intensity *= clamp01(1.0 - light_levels.x); // Reduce purkinje intensity in blocklight
	      purkinje_intensity *= clamp01(0.3 + 0.7 * cube(max(light_levels.y, eye_skylight))); // Reduce purkinje intensity underground

	if (purkinje_intensity < eps) return rgb;

	const vec3 purkinje_tint = vec3(0.5, 0.7, 1.0) * rec709_to_rec2020;
	const vec3 rod_response = vec3(7.15e-5, 4.81e-1, 3.28e-1) * rec709_to_rec2020;

	vec3 xyz = rgb * rec2020_to_xyz;

	vec3 scotopic_luminance = xyz * (1.33 * (1.0 + (xyz.y + xyz.z) / xyz.x) - 1.68);

	float purkinje = dot(rod_response, scotopic_luminance * xyz_to_rec2020);

	rgb = mix(rgb, purkinje * purkinje_tint, exp2(-rcp(purkinje_intensity) * purkinje));

	return max0(rgb);
#endif
}

void main() {
	ivec2 texel = ivec2(gl_FragCoord.xy);

	// Sample textures

	float front_depth      = texelFetch(depthtex0, texel, 0).x;
	float back_depth       = texelFetch(depthtex1, texel, 0).x;

	vec4 refraction_data   = texelFetch(colortex3, texel, 0);
	vec4 translucent_color = texelFetch(colortex13, texel, 0);
	
#ifdef VL
	vec3 fog_transmittance = smooth_filter(colortex6, uv).rgb;
	vec3 fog_scattering    = smooth_filter(colortex7, uv).rgb;
#endif

	// Distant Horizons support

#ifdef DISTANT_HORIZONS
    float front_depth_dh   = texelFetch(dhDepthTex, texel, 0).x;
    float back_depth_dh    = texelFetch(dhDepthTex1, texel, 0).x;

    bool front_is_dh_terrain = is_distant_horizons_terrain(front_depth, front_depth_dh);
    bool back_is_dh_terrain = is_distant_horizons_terrain(back_depth, back_depth_dh);
#else
	#define front_depth_dh      front_depth
	#define back_depth_dh       back_depth
	#define front_is_dh_terrain false
	#define back_is_dh_terrain  false
#endif

	// Space conversions

	front_depth += 0.38 * float(front_depth < hand_depth); // Hand lighting fix from Capt Tatsu

	vec3 front_position_screen = vec3(uv, front_is_dh_terrain ? front_depth_dh : front_depth);
	vec3 front_position_view   = screen_to_view_space(front_position_screen, true, front_is_dh_terrain);
	vec3 front_position_scene  = view_to_scene_space(front_position_view);
	vec3 front_position_world  = front_position_scene + cameraPosition;

	vec3 back_position_screen  = vec3(uv, back_is_dh_terrain ? back_depth_dh : back_depth);
	vec3 back_position_view    = screen_to_view_space(back_position_screen, true, back_is_dh_terrain);

	vec3 direction_world; float view_distance;
	length_normalize(front_position_scene - gbufferModelViewInverse[3].xyz, direction_world, view_distance);

	// Refraction 

	vec2 refracted_uv = uv;
	float layer_dist = abs(view_distance - length(back_position_view));

#if REFRACTION != REFRACTION_OFF
	if (front_depth != back_depth && refraction_data != vec4(0.0)) {
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

	// Blend layers and draw DH water

#ifdef DISTANT_HORIZONS
	bool is_dh_translucent = front_depth_dh != back_depth_dh;

	float z_mc = screen_to_view_space_depth(gbufferProjectionInverse, front_depth);
	float z_dh = screen_to_view_space_depth(dhProjectionInverse, front_depth_dh);

	const float error_margin = 1.0;
	bool dh_translucent_behind_mc_translucent = z_dh > z_mc + error_margin && front_depth != back_depth;

	if (!dh_translucent_behind_mc_translucent) {
		fragment_color = fragment_color * (1.0 - translucent_color.a) + translucent_color.rgb;
	}

	if (is_dh_translucent && (front_is_dh_terrain || dh_translucent_behind_mc_translucent)) {
		// Unpack gbuffer data

		vec4 gbuffer_data = texelFetch(colortex1, texel, 0);

		mat4x2 data = mat4x2(
			unpack_unorm_2x8(gbuffer_data.x),
			unpack_unorm_2x8(gbuffer_data.y),
			unpack_unorm_2x8(gbuffer_data.z),
			unpack_unorm_2x8(gbuffer_data.w)
		);

		vec3 tint          = vec3(data[0], data[1].x);
		uint material_mask = uint(255.0 * data[1].y);
		vec3 flat_normal   = decode_unit_vector(data[2]);
		vec2 light_levels  = data[3];

		vec3 position_screen, position_view, position_world;
		if (dh_translucent_behind_mc_translucent) {
			position_screen = vec3(uv, front_depth_dh);
			position_view = screen_to_view_space(dhProjectionInverse, position_screen, true);
			position_world = view_to_scene_space(position_view) + cameraPosition;
		} else {
			position_screen = front_position_screen;
			position_view = front_position_view;
			position_world = front_position_world;
		}

		if (material_mask == 1) { // Water
			draw_distant_water(
				fragment_color,
				position_screen,
				position_view,
				position_world,
				direction_world,
				flat_normal,
				tint,
				light_levels,
				view_distance,
				layer_dist
			);
		}
	}

	if (dh_translucent_behind_mc_translucent) {
		fragment_color = fragment_color * (1.0 - translucent_color.a) + translucent_color.rgb;
	}
#else 
	fragment_color = fragment_color * (1.0 - translucent_color.a) + translucent_color.rgb;
#endif

	// Blend clouds in front of translucents

	bool is_translucent = front_depth != back_depth;
#ifdef DISTANT_HORIZONS
         is_translucent = is_translucent || front_depth_dh != back_depth_dh;
#endif

	if (is_translucent) {
		float clouds_dist;
		vec4 clouds = read_clouds(clouds_dist);

		if (clouds_dist < view_distance) {
			fragment_color = fragment_color * clouds.w + clouds.xyz;
		}
	}

	// Blend fog

#if (defined WORLD_OVERWORLD || defined WORLD_END) && defined VL
	// Volumetric fog

	fragment_color = fragment_color * fog_transmittance + fog_scattering;

	#ifdef BLOOMY_FOG
	bloomy_fog = clamp01(dot(fog_transmittance, vec3(luminance_weights_rec2020)));
	bloomy_fog = isEyeInWater == 1.0 ? sqrt(bloomy_fog) : bloomy_fog;
	#endif
#else
	// Simple underwater fog

	if (isEyeInWater == 1) {
		float LoV = dot(direction_world, light_dir);
		mat2x3 water_fog = water_fog_simple(
			light_color,
			ambient_color,
			water_absorption_coeff,
			vec2(0.0, eye_skylight),
			view_distance,
			LoV,
			15.0 * eye_skylight
		);

		fragment_color *= water_fog[1];
		fragment_color += water_fog[0];

	#ifdef BLOOMY_FOG
		bloomy_fog = sqrt(clamp01(dot(water_fog[1], vec3(0.33))));
	#endif
	} else {
	#ifdef BLOOMY_FOG
		bloomy_fog = 1.0;
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

