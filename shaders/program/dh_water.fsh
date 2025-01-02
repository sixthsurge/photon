/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/dh_water:
  Translucent Distant Horizons terrain

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

layout (location = 0) out vec4 fragment_color;
layout (location = 1) out vec4 gbuffer_data; // albedo, block ID, flat normal, light levels

/* RENDERTARGETS: 0,1 */

in vec2 light_levels;
in vec3 scene_pos;
in vec3 normal;
in vec4 tint;

flat in uint is_water;
flat in vec3 light_color;
flat in vec3 ambient_color;

#if defined PROGRAM_GBUFFERS_WATER
in vec2 atlas_tile_coord;
in vec3 tangent_pos;
flat in vec2 atlas_tile_offset;
flat in vec2 atlas_tile_scale;
#endif

// ------------
//   Uniforms
// ------------

uniform sampler2D noisetex;

uniform sampler2D colortex4; // Sky map, lighting colors
uniform sampler2D colortex5; // Previous frame image (for reflections)
uniform sampler2D colortex7; // Previous frame fog scattering (for reflections)

#ifdef CLOUD_SHADOWS
uniform sampler2D colortex8; // Cloud shadow map
#endif

uniform sampler2D depthtex0;

#ifdef COLORED_LIGHTS
uniform sampler3D light_sampler_a;
uniform sampler3D light_sampler_b;
#endif

#ifdef SHADOW
#ifdef WORLD_OVERWORLD
uniform sampler2D shadowtex0;
uniform sampler2DShadow shadowtex1;
#endif

#ifdef WORLD_END
uniform sampler2D shadowtex0;
uniform sampler2DShadow shadowtex1;
#endif
#endif

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
uniform float eyeAltitude;

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

#if defined PROGRAM_GBUFFERS_ENTITIES_TRANSLUCENT
uniform vec4 entityColor;
#endif

// ------------
//   Includes
// ------------

#define TEMPORAL_REPROJECTION

#ifdef SHADOW_COLOR
	#undef SHADOW_COLOR
#endif

#ifdef SH_SKYLIGHT
	#undef SH_SKYLIGHT
#endif

#if defined PROGRAM_GBUFFERS_TEXTURED || defined PROGRAM_GBUFFERS_PARTICLES_TRANSLUCENT
	#define NO_NORMAL
#endif

#ifdef DIRECTIONAL_LIGHTMAPS
#include "/include/lighting/directional_lightmaps.glsl"
#endif

#include "/include/fog/simple_fog.glsl"
#include "/include/lighting/diffuse_lighting.glsl"
#include "/include/lighting/shadows.glsl"
#include "/include/lighting/specular_lighting.glsl"
#include "/include/misc/distant_horizons.glsl"
#include "/include/misc/material.glsl"
#include "/include/misc/water_normal.glsl"
#include "/include/utility/color.glsl"
#include "/include/utility/encoding.glsl"
#include "/include/utility/fast_math.glsl"
#include "/include/utility/space_conversion.glsl"

#ifdef CLOUD_SHADOWS
#include "/include/lighting/cloud_shadows.glsl"
#endif

vec4 water_absorption_approx(vec4 color, float sss_depth, float layer_dist, float LoV, float NoV) {
	vec3 biome_water_color = 2.0 * srgb_eotf_inv(tint.rgb) * rec709_to_working_color;
	vec3 absorption_coeff = biome_water_coeff(biome_water_color);
	float dist = layer_dist * float(isEyeInWater != 1 || NoV >= 0.0);

	mat2x3 water_fog = water_fog_simple(
		light_color,
		ambient_color,
		absorption_coeff,
		light_levels,
		dist,
		-LoV,
		sss_depth
	);

	float brightness_control = 1.0 - exp(-0.33 * layer_dist);
		  brightness_control = (1.0 - light_levels.y) + brightness_control * light_levels.y;

	return vec4(
		color.rgb + water_fog[0] * (1.0 + 6.0 * sqr(water_fog[1])) * brightness_control,
		1.0 - water_fog[1].x
	);
}

void main() {
    // Clip close-by DH terrain
    if (length(scene_pos) < 0.8 * far) {
        discard;
        return;
    }

	vec2 coord = gl_FragCoord.xy * view_pixel_size * rcp(taau_render_scale);

	// Clip to TAAU viewport

#if defined TAA && defined TAAU
	if (clamp01(coord) != coord) discard;
#endif

	// Space conversions

	float back_depth_mc = texelFetch(depthtex0, ivec2(gl_FragCoord.xy), 0).x;
	float back_depth_dh = texelFetch(dhDepthTex1, ivec2(gl_FragCoord.xy), 0).x;
	bool back_is_dh_terrain = is_distant_horizons_terrain(back_depth_mc, back_depth_dh);

	// Prevent water behind terrain from rendering on top of it
	float dh_depth_linear = screen_to_view_space_depth(dhProjectionInverse, gl_FragCoord.z);
	float mc_depth_linear = screen_to_view_space_depth(gbufferProjectionInverse, back_depth_mc);

	if (mc_depth_linear < dh_depth_linear && back_depth_mc != 1.0) { discard; return; }

	vec3 world_pos = scene_pos + cameraPosition;
	vec3 world_dir = normalize(scene_pos - gbufferModelViewInverse[3].xyz);

	vec3 view_back_pos = back_is_dh_terrain
		? screen_to_view_space(vec3(coord, back_depth_dh), true, true)
		: screen_to_view_space(vec3(coord, back_depth_mc), true, false);
	vec3 scene_back_pos = view_to_scene_space(view_back_pos);

	float layer_dist = length(scene_pos - scene_back_pos); // distance to solid layer along view ray

	// Get material and normal

	Material material; vec4 base_color;

	if (is_water == 1) {
		material = water_material;

		base_color = vec4(0.0);
	} else {
		base_color = tint;
		vec2 adjusted_light_levels = light_levels;
		material = material_from(
			base_color.rgb,
			0u,
			world_pos,
			normal,
			adjusted_light_levels
		);
	}

	// Shadows

#ifndef NO_NORMAL
	float NoL = dot(normal, light_dir);
#else
	float NoL = 1.0;
#endif
	float NoV = clamp01(dot(normal, -world_dir));
	float LoV = dot(light_dir, -world_dir);
	float halfway_norm = inversesqrt(2.0 * LoV + 2.0);
	float NoH = (NoL + NoV) * halfway_norm;
	float LoH = LoV * halfway_norm + halfway_norm;

	vec3 shadows = vec3(pow8(light_levels.y));
	#define sss_depth 0.0
	#define shadow_distance_fade 0.0

#ifdef CLOUD_SHADOWS
	float cloud_shadows = get_cloud_shadows(colortex8, scene_pos);
	shadows *= cloud_shadows;
#endif

	fragment_color.rgb = get_diffuse_lighting(
		material,
		scene_pos,
		normal,
		normal,
		shadows,
		light_levels,
		1.0,
		sss_depth,
#ifdef CLOUD_SHADOWS
		cloud_shadows,
#endif
		shadow_distance_fade,
		NoL,
		NoV,
		NoH,
		LoV
	);

	// Blending

	if (is_water == 1) {
		// Water absorption

		fragment_color = water_absorption_approx(
            fragment_color,
            0.0,
            layer_dist,
            LoV,
            dot(normal, world_dir)
        );

        // Reverse water shadow 
		fragment_color.rgb *= exp(5.0 * water_absorption_coeff);
	} else {
		fragment_color.a = base_color.a;
	}

	fragment_color = vec4(fragment_color.rgb / max(fragment_color.a, eps), fragment_color.a);

	// Apply fog

	vec4 fog = common_fog(length(scene_pos), false);
	fragment_color.rgb = fragment_color.rgb * fog.a + fog.rgb;

	fragment_color.a *= border_fog(scene_pos, world_dir);

	// Encode gbuffer data

	gbuffer_data.x  = pack_unorm_2x8(tint.rg);
	gbuffer_data.y  = pack_unorm_2x8(tint.b, clamp01(((is_water == 1) ? rcp(255.0) : 0.0)));
	gbuffer_data.z  = pack_unorm_2x8(encode_unit_vector(normal));
	gbuffer_data.w  = pack_unorm_2x8(dither_8bit(light_levels, 0.5));
}

